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
    #expect(License.problem(in: Data(ok.utf8)) == nil)
    #expect(License.problem(in: Data(refunded.utf8)) != nil)
    #expect(License.problem(in: Data(unknown.utf8)) != nil)
    #expect(License.problem(in: Data("<html>".utf8)) != nil)
}

@Test func formBodyEscapesProductID() {
    let body = String(decoding: License.formBody([("product_id", "ab_C==")]), as: UTF8.self)
    #expect(body == "product_id=ab_C%3D%3D")
}
