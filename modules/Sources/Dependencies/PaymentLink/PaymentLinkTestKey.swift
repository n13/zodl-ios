import ComposableArchitecture

extension PaymentLinkClient: TestDependencyKey {
    public static let previewValue = PaymentLinkClient.noop
    public static let testValue = PaymentLinkClient()
}

extension PaymentLinkClient {
    public static let noop = PaymentLinkClient(
        generateInvite: { _, _ in
            InviteCode(
                mnemonic: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about",
                seedBytes: [UInt8](repeating: 0, count: 64),
                address: "utest1placeholder",
                amount: .init(1_000_000)
            )
        },
        parseInviteURL: { _, _ in
            InviteCode(
                mnemonic: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about",
                seedBytes: [UInt8](repeating: 0, count: 64),
                address: "utest1placeholder",
                amount: .init(1_000_000)
            )
        },
        buildInviteURL: { _, _ in
            URL(string: "https://pay.withzcash.com:65536/payment/v1#phrase=test&amount=0.01")!
        },
        deriveSpendingKey: { _, _ in
            fatalError("not implemented for preview")
        }
    )
}
