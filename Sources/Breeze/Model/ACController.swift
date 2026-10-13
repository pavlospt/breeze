import BreezeKit
import Foundation
import Observation
import os

/// App-wide state: account, devices, cached per-device state, and the commands the UI sends.
/// Injected into the SwiftUI environment and shared by the window and the menu bar panel.
@MainActor
@Observable
final class ACController {
    enum Phase: Equatable {
        case signedOut
        case loading
        case ready
    }

    private(set) var phase: Phase = .signedOut
    private(set) var account: String?
    private(set) var devices: [ACDevice] = []
    /// Last known state of every device, so switching devices is instant.
    private(set) var states: [ACDevice.ID: ACState] = [:]
    private(set) var errorMessage: String?
    private(set) var isSigningIn = false

    var selectedID: ACDevice.ID? {
        didSet {
            guard selectedID != oldValue, let selectedID else { return }
            defaults.set(selectedID, forKey: DefaultsKey.selectedDevice)
            Task { await refresh(selectedID) }
        }
    }

    @ObservationIgnored private let credentialStore: any CredentialStore
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let makeService: (Credentials) -> any ACService
    @ObservationIgnored private var service: (any ACService)?
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var temperatureTask: Task<Void, Never>?
    @ObservationIgnored private var lastCommand: [ACDevice.ID: Date] = [:]
    @ObservationIgnored private let logger = Logger(subsystem: "com.ptournaris.Breeze", category: "controller")

    init(credentialStore: any CredentialStore = KeychainCredentialStore(),
         defaults: UserDefaults = .standard,
         makeService: @escaping (Credentials) -> any ACService = { TCLCloudClient(credentials: $0) }) {
        self.credentialStore = credentialStore
        self.defaults = defaults
        self.makeService = makeService
        selectedID = defaults.string(forKey: DefaultsKey.selectedDevice)

        if let credentials = credentialStore.load() {
            account = credentials.email
            service = makeService(credentials)
            phase = .loading
            Task { await reload() }
        }
    }

    // MARK: Derived state for the selected device

    var selectedDevice: ACDevice? { devices.first { $0.id == selectedID } }
    var state: ACState { selectedID.flatMap { states[$0] } ?? ACState() }
    var profile: DeviceProfile { profile(for: selectedDevice) }
    var mode: ACMode? { profile.mode(in: state) }
    var fanSpeed: FanSpeed? { profile.fanSpeed(in: state) }
    var isOn: Bool { state.isOn }
    var canAdjustTemperature: Bool { isOn && (mode?.usesTargetTemperature ?? true) && state.targetTemperature != nil }

    func profile(for device: ACDevice?) -> DeviceProfile {
        DeviceProfile.forType(device?.type ?? "", state: device.flatMap { states[$0.id] } ?? ACState())
    }

    func mode(of device: ACDevice) -> ACMode? {
        profile(for: device).mode(in: states[device.id] ?? ACState())
    }

    // MARK: Account

    func signIn(email: String, password: String) async {
        isSigningIn = true
        defer { isSigningIn = false }
        let credentials = Credentials(email: email, password: password)
        let candidate = makeService(credentials)
        do {
            let devices = try await candidate.devices()
            try credentialStore.save(credentials)
            service = candidate
            account = email
            errorMessage = nil
            apply(devices)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        credentialStore.delete()
        pollTask?.cancel()
        service = nil
        account = nil
        devices = []
        states = [:]
        errorMessage = nil
        phase = .signedOut
    }

    // MARK: Loading

    func reload() async {
        guard let service else { return }
        do {
            apply(try await service.devices())
            errorMessage = nil
        } catch {
            logger.error("Loading devices failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    private func apply(_ devices: [ACDevice]) {
        self.devices = devices
        if selectedID == nil || !devices.contains(where: { $0.id == selectedID }) {
            selectedID = devices.first?.id
        }
        Task {
            await refreshAll()
            phase = .ready
        }
        startPolling()
    }

    func refreshAll() async {
        await withTaskGroup(of: Void.self) { group in
            for device in devices {
                group.addTask { await self.refresh(device.id) }
            }
        }
    }

    func refresh(_ id: ACDevice.ID) async {
        guard let service else { return }
        let started = Date.now
        do {
            let state = try await service.state(of: id)
            // Don't let a poll that started before a command overwrite its optimistic update.
            if (lastCommand[id] ?? .distantPast) < started.addingTimeInterval(-3) {
                states[id] = state
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                let seconds = self?.defaults.integer(forKey: DefaultsKey.refreshInterval) ?? 0
                try? await Task.sleep(for: .seconds(seconds > 0 ? seconds : 30))
                await self?.refreshAll()
            }
        }
    }

    // MARK: Commands

    func send(_ command: ACCommand) {
        guard let selectedID else { return }
        send(command, to: selectedID)
    }

    private func send(_ command: ACCommand, to id: ACDevice.ID) {
        guard let service else { return }
        states[id, default: ACState()].apply(command)
        lastCommand[id] = .now
        Task {
            do {
                try await service.send(command, to: id)
                errorMessage = nil
                // Give the unit a moment to apply the change before reading it back.
                try? await Task.sleep(for: .seconds(4))
            } catch {
                errorMessage = error.localizedDescription
            }
            await refresh(id)
        }
    }

    func setPower(_ on: Bool) {
        send([ACState.Key.power: on ? 1 : 0])
    }

    func setMode(_ mode: ACMode) {
        guard let command = profile.command(for: mode, in: state) else { return }
        send(command)
    }

    /// Updates the UI immediately; the command is sent once taps or drags settle.
    func setTemperature(_ value: Int) {
        guard let id = selectedID else { return }
        let range = profile.temperatureRange
        let value = min(range.upperBound, max(range.lowerBound, value))
        states[id, default: ACState()].apply([ACState.Key.targetTemperature: value])
        lastCommand[id] = .now
        temperatureTask?.cancel()
        temperatureTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            self?.send([ACState.Key.targetTemperature: value], to: id)
        }
    }

    func adjustTemperature(by delta: Int) {
        setTemperature((state.targetTemperature ?? 24) + delta)
    }
}

enum DefaultsKey {
    static let selectedDevice = "selectedDevice"
    static let refreshInterval = "refreshInterval"
    static let showTemperatureInMenuBar = "showTemperatureInMenuBar"
}
