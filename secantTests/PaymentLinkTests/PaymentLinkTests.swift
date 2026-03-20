import XCTest
import ZcashLightClientKit
import PaymentLink
import Deeplink
@testable import secant_testnet

class PaymentLinkTests: XCTestCase {

    // MARK: - URL Building

    func testBuildInviteURL_containsPhrase() {
        let client = PaymentLinkClient.liveValue
        let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        let amount = Zatoshi(1_000_000)

        let url = client.buildInviteURL(mnemonic, amount)
        let abs = url.absoluteString

        XCTAssertTrue(abs.contains("pay.withzcash.com"))
        XCTAssertTrue(abs.contains("65536"))
        XCTAssertTrue(abs.contains("payment/v1"))
        XCTAssertTrue(abs.contains("phrase="))
        XCTAssertTrue(abs.contains("amount=0.01"))
    }

    func testBuildInviteURL_amountWholeNumber() {
        let client = PaymentLinkClient.liveValue
        let url = client.buildInviteURL("test", Zatoshi(100_000_000))
        XCTAssertTrue(url.absoluteString.contains("amount=1"))
    }

    func testBuildInviteURL_amountDecimal() {
        let client = PaymentLinkClient.liveValue
        let url = client.buildInviteURL("test", Zatoshi(12_345_678))
        XCTAssertTrue(url.absoluteString.contains("amount=0.12345678"))
    }

    // MARK: - URL Parsing

    func testParseInviteURL_roundTrip() throws {
        let client = PaymentLinkClient.liveValue
        let originalMnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        let originalAmount = Zatoshi(1_000_000)

        let url = client.buildInviteURL(originalMnemonic, originalAmount)
        let parsed = try client.parseInviteURL(url, .testnet)

        XCTAssertEqual(parsed.mnemonic, originalMnemonic)
        XCTAssertEqual(parsed.amount, originalAmount)
        XCTAssertFalse(parsed.address.isEmpty)
        XCTAssertFalse(parsed.seedBytes.isEmpty)
    }

    func testParseInviteURL_invalidURL() {
        let client = PaymentLinkClient.liveValue
        let url = URL(string: "https://example.com/nope")!

        XCTAssertThrowsError(try client.parseInviteURL(url, .testnet)) { error in
            XCTAssertEqual(error as? PaymentLinkError, .missingMnemonic)
        }
    }

    func testParseInviteURL_invalidMnemonic() {
        let encoded = Data("not a valid mnemonic phrase".utf8).base64EncodedString()
        let url = URL(string: "https://pay.withzcash.com:65536/payment/v1#phrase=\(encoded)&amount=0.01")!
        let client = PaymentLinkClient.liveValue

        XCTAssertThrowsError(try client.parseInviteURL(url, .testnet))
    }

    // MARK: - Deeplink Detection

    func testIsInviteURL_valid() {
        let url = URL(string: "https://pay.withzcash.com:65536/payment/v1#phrase=abc&amount=0.01")!
        XCTAssertTrue(Deeplink.isInviteURL(url))
    }

    func testIsInviteURL_testnet() {
        let url = URL(string: "https://pay.testzcash.com:65536/payment/v1#phrase=abc&amount=0.01")!
        XCTAssertTrue(Deeplink.isInviteURL(url))
    }

    func testIsInviteURL_notInvite() {
        let url = URL(string: "zcash:///home")!
        XCTAssertFalse(Deeplink.isInviteURL(url))
    }

    // MARK: - Generate Invite (requires SDK)

    func testGenerateInvite_producesValidInviteCode() throws {
        let client = PaymentLinkClient.liveValue
        let amount = Zatoshi(1_000_000)

        let invite = try client.generateInvite(amount, .testnet)

        XCTAssertFalse(invite.mnemonic.isEmpty)
        XCTAssertEqual(invite.mnemonic.split(separator: " ").count, 24)
        XCTAssertFalse(invite.address.isEmpty)
        XCTAssertEqual(invite.amount, amount)
        XCTAssertEqual(invite.seedBytes.count, 64)
    }

    func testGenerateInvite_uniqueEachTime() throws {
        let client = PaymentLinkClient.liveValue
        let amount = Zatoshi(1_000_000)

        let invite1 = try client.generateInvite(amount, .testnet)
        let invite2 = try client.generateInvite(amount, .testnet)

        XCTAssertNotEqual(invite1.mnemonic, invite2.mnemonic)
        XCTAssertNotEqual(invite1.address, invite2.address)
    }

    // MARK: - Full Round-Trip (generate → URL → parse)

    func testFullRoundTrip() throws {
        let client = PaymentLinkClient.liveValue
        let amount = Zatoshi(1_000_000)

        let invite = try client.generateInvite(amount, .testnet)
        let url = client.buildInviteURL(invite.mnemonic, invite.amount)
        let parsed = try client.parseInviteURL(url, .testnet)

        XCTAssertEqual(parsed.mnemonic, invite.mnemonic)
        XCTAssertEqual(parsed.address, invite.address)
        XCTAssertEqual(parsed.amount, invite.amount)
    }

    // MARK: - Spending Key Derivation

    func testDeriveSpendingKey_fromParsedInvite() throws {
        let client = PaymentLinkClient.liveValue
        let amount = Zatoshi(1_000_000)

        let invite = try client.generateInvite(amount, .testnet)
        let spendingKey = try client.deriveSpendingKey(invite.seedBytes, .testnet)

        XCTAssertNotNil(spendingKey)
    }
}
