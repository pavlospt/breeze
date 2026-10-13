import Foundation
import Testing
@testable import BreezeKit

@Suite("SigV4 signer")
struct SigV4SignerTests {
    let signer = SigV4Signer(
        region: "us-east-1", service: "iotdata",
        credentials: AWSCredentials(
            accessKeyID: "AKIDEXAMPLE", secretKey: "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY",
            sessionToken: "SESSIONTOKEN", expiration: .distantFuture))

    let request = SigV4Signer.Request(
        method: "POST", host: "data-ats.iot.us-east-1.amazonaws.com",
        pathSegments: ["topics", "$aws/things/dev1/shadow/update"],
        query: [("qos", "1")],
        body: Data(#"{"state":{"desired":{"powerSwitch":1}}}"#.utf8))

    /// 2015-08-30T12:36:00Z, the date used in AWS's own SigV4 examples.
    let date = Date(timeIntervalSince1970: 1_440_938_160)

    @Test func formatsAmzDate() {
        #expect(SigV4Signer.amzDate(date) == "20150830T123600Z")
    }

    @Test func doubleEncodesCanonicalPath() {
        let canonical = signer.canonicalRequest(request, amzDate: "20150830T123600Z")
        #expect(canonical.split(separator: "\n")[1] == "/topics/%2524aws%252Fthings%252Fdev1%252Fshadow%252Fupdate")
    }

    /// Expected value computed independently with Python's `hmac` from the AWS spec.
    @Test func matchesReferenceSignature() {
        #expect(signer.signature(request, date: date)
            == "de6993b0c5da60fd230032ded78f68b39ce5343267c8abb65a8b69e16a9c90f7")
    }

    @Test func signedRequestHasEncodedURLAndHeaders() throws {
        let signed = signer.sign(request, date: date)
        let url = try #require(signed.url)
        #expect(url.absoluteString
            == "https://data-ats.iot.us-east-1.amazonaws.com/topics/%24aws%2Fthings%2Fdev1%2Fshadow%2Fupdate?qos=1")
        #expect(signed.value(forHTTPHeaderField: "X-Amz-Date") == "20150830T123600Z")
        #expect(signed.value(forHTTPHeaderField: "X-Amz-Security-Token") == "SESSIONTOKEN")
        let auth = try #require(signed.value(forHTTPHeaderField: "Authorization"))
        #expect(auth.hasPrefix("AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20150830/us-east-1/iotdata/aws4_request"))
        #expect(auth.hasSuffix("Signature=de6993b0c5da60fd230032ded78f68b39ce5343267c8abb65a8b69e16a9c90f7"))
    }
}
