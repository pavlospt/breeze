import Testing
@testable import BreezeKit

@Suite("Device profiles")
struct DeviceProfileTests {
    func device(_ type: String) -> ACDevice {
        ACDevice(id: "1", name: "Test", type: type, isOnline: true)
    }

    @Test func splitACMapsAllFiveModes() {
        let profile = DeviceProfile.for(device("Split AC"), state: ACState())
        #expect(profile.modes == [.auto, .cool, .dry, .fan, .heat])
        #expect(profile.mode(in: ACState(properties: ["workMode": 1])) == .cool)
        #expect(profile.mode(in: ACState(properties: ["workMode": 4])) == .heat)
        #expect(profile.mode(in: ACState(properties: ["workMode": 9])) == nil)
    }

    @Test func numberedDeviceTypeUsesBaseProfile() {
        let profile = DeviceProfile.for(device("Window AC-2"), state: ACState())
        #expect(profile.modes == [.auto, .cool, .dry, .fan])
    }

    @Test(arguments: [
        (["windSpeed": 2.0, "silenceSwitch": 1, "turbo": 0], "Mute"),
        (["windSpeed": 2.0, "silenceSwitch": 0, "turbo": 0], "Low"),
        (["windSpeed": 6.0, "silenceSwitch": 0, "turbo": 0], "High"),
        (["windSpeed": 6.0, "silenceSwitch": 0, "turbo": 1], "Turbo"),
        (["windSpeed": 0.0], "Auto"),
    ])
    func splitACFanSpeedMatching(properties: [String: Double], expected: String) {
        let state = ACState(properties: properties)
        let profile = DeviceProfile.for(device("Split AC"), state: state)
        #expect(profile.fanSpeed(in: state)?.name == expected)
    }

    @Test func noFanSpeedWithoutWindSpeed() {
        let profile = DeviceProfile.for(device("Split AC"), state: ACState())
        #expect(profile.fanSpeed(in: ACState(properties: ["turbo": 0])) == nil)
    }

    @Test func portableACModesDependOnSwingSupport() {
        let basic = DeviceProfile.for(device("Portable AC"), state: ACState())
        #expect(basic.modes == [.cool, .dry, .fan])
        #expect(basic.fanSpeeds.map(\.name) == ["Low", "High"])

        let withSwing = DeviceProfile.for(device("Portable AC"), state: ACState(properties: ["swingWind": 0]))
        #expect(withSwing.modes == [.auto, .cool, .dry, .fan])
        #expect(withSwing.fanSpeeds.map(\.name) == ["Auto", "Low", "High"])
    }

    @Test func modeCommandResetsTurboOnlyWhenSupported() {
        let profile = DeviceProfile.for(device("Split AC"), state: ACState())
        #expect(profile.command(for: .heat, in: ACState()) == ["workMode": 4])
        #expect(profile.command(for: .cool, in: ACState(properties: ["turbo": 1])) == ["workMode": 1, "turbo": 0])

        let portable = DeviceProfile.for(device("Portable AC"), state: ACState())
        #expect(portable.command(for: .heat, in: ACState()) == nil)
    }

    @Test func featuresOnlyIncludeReportedProperties() {
        let state = ACState(properties: ["ECO": 1, "sleep": 0, "verticalDirection": 11])
        let profile = DeviceProfile.for(device("Split AC"), state: state)
        #expect(profile.features.map(\.name) == ["Swing", "Eco", "Sleep"])

        let swing = profile.features[0]
        #expect(!swing.isOn(in: state)) // 11 = fixed middle position
        #expect(swing.isOn(in: state.applying(swing.onCommand)))
        #expect(profile.features[1].isOn(in: state))
    }
}
