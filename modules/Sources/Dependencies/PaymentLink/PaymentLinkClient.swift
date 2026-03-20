import Foundation
import ComposableArchitecture
import ZcashLightClientKit

extension DependencyValues {
    public var paymentLink: PaymentLinkClient {
        get { self[PaymentLinkClient.self] }
        set { self[PaymentLinkClient.self] = newValue }
    }
}

public struct InviteCode: Equatable, Sendable {
    public let mnemonic: String
    public let seedBytes: [UInt8]
    public let address: String
    public let amount: Zatoshi

    public init(mnemonic: String, seedBytes: [UInt8], address: String, amount: Zatoshi) {
        self.mnemonic = mnemonic
        self.seedBytes = seedBytes
        self.address = address
        self.amount = amount
    }
}

@DependencyClient
public struct PaymentLinkClient {
    public var generateInvite: (Zatoshi, NetworkType) throws -> InviteCode
    public var parseInviteURL: (URL, NetworkType) throws -> InviteCode
    public var buildInviteURL: (String, Zatoshi) -> URL = { _, _ in URL(string: "https://pay.withzcash.com:65536/payment/v1")! }
    public var deriveSpendingKey: ([UInt8], NetworkType) throws -> UnifiedSpendingKey
}
