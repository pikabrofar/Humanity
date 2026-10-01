import Foundation
import Testing
@testable import LicenseKit

@Test func findsKeyInReceiptText() {
    #expect(License.findKey(in: "Your key: 6f0e4c97-b72a4e69-a11bf6c4-af6517e7 enjoy") == "6F0E4C97-B72A4E69-A11BF6C4-AF6517E7")
    #expect(License.findKey(in: "no key here 1234") == nil)
}

@Test func gumroadRepliesAreJudged() {
    let ok = #"{"success":true,"uses":1,"purchase":{"refunded":false,"chargebacked":false,"license_key":"X"}}"#
    let refunded = #"{"success":true,"purchase":{"refunded":true,"chargebacked":false}}"#
    let unknown = #"{"success":false,"message":"That license does not exist for the provided product."}"#
    #expect(License.failure(in: Data(ok.utf8)) == nil)
    #expect(License.failure(in: Data(refunded.utf8)).map { if case .rejected = $0 { true } else { false } } == true)
    #expect(License.failure(in: Data(unknown.utf8)).map { if case .rejected = $0 { true } else { false } } == true)
    // A captive portal or outage page must never count as a rejection.
    #expect(License.failure(in: Data("<html>".utf8)).map { if case .network = $0 { true } else { false } } == true)
}

@Test func formBodyEscapesProductID() {
    let body = String(decoding: License.formBody([("product_id", "ab_C==")]), as: UTF8.self)
    #expect(body == "product_id=ab_C%3D%3D")
}

@Test func wonDisputeKeepsWorking() {
    let won = #"{"success":true,"purchase":{"refunded":false,"chargebacked":false,"disputed":true,"dispute_won":true}}"#
    #expect(License.failure(in: Data(won.utf8)) == nil)
}

@Test func serverErrorsNeverRevoke() {
    let reply = #"{"success":false,"message":"Internal error"}"#
    #expect(License.failure(in: Data(reply.utf8), status: 500).map { if case .network = $0 { true } else { false } } == true)
    #expect(License.failure(in: Data(reply.utf8), status: 429).map { if case .network = $0 { true } else { false } } == true)
}
