import Foundation
import ComposableArchitecture
import MnemonicSwift
import ZcashLightClientKit

extension PaymentLinkClient: DependencyKey {
    public static let liveValue = Self(
        generateInvite: { amount, networkType in
            let mnemonic = try Mnemonic.generateMnemonic(strength: 256)
            let seedBytes = try [UInt8](Mnemonic.deterministicSeedBytes(from: mnemonic))
            let spendingKey = try DerivationTool(networkType: networkType)
                .deriveUnifiedSpendingKey(seed: seedBytes, accountIndex: Zip32AccountIndex(0))
            let ufvk = try DerivationTool(networkType: networkType)
                .deriveUnifiedFullViewingKey(from: spendingKey)
            let ua = try DerivationTool(networkType: networkType)
                .deriveUnifiedAddressFrom(ufvk: ufvk.stringEncoded)
            return InviteCode(
                mnemonic: mnemonic,
                seedBytes: seedBytes,
                address: ua.stringEncoded,
                amount: amount
            )
        },
        parseInviteURL: { url, networkType in
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                throw PaymentLinkError.invalidURL
            }
            let fragment = components.fragment ?? ""
            let params = parseFragment(fragment)
            guard let encodedPhrase = params["phrase"],
                  let phraseData = Data(base64Encoded: encodedPhrase),
                  let phrase = String(data: phraseData, encoding: .utf8) else {
                throw PaymentLinkError.missingMnemonic
            }
            try Mnemonic.validate(mnemonic: phrase)

            let amountString = params["amount"] ?? "0"
            let zatoshi = zatoshiFromDecimal(amountString)

            let seedBytes = try [UInt8](Mnemonic.deterministicSeedBytes(from: phrase))
            let spendingKey = try DerivationTool(networkType: networkType)
                .deriveUnifiedSpendingKey(seed: seedBytes, accountIndex: Zip32AccountIndex(0))
            let ufvk = try DerivationTool(networkType: networkType)
                .deriveUnifiedFullViewingKey(from: spendingKey)
            let ua = try DerivationTool(networkType: networkType)
                .deriveUnifiedAddressFrom(ufvk: ufvk.stringEncoded)

            return InviteCode(
                mnemonic: phrase,
                seedBytes: seedBytes,
                address: ua.stringEncoded,
                amount: zatoshi
            )
        },
        buildInviteURL: { mnemonic, amount in
            let encoded = Data(mnemonic.utf8).base64EncodedString()
            let decimalAmount = decimalFromZatoshi(amount)
            var components = URLComponents()
            components.scheme = "https"
            components.host = "pay.withzcash.com"
            components.port = 65536
            components.path = "/payment/v1"
            components.fragment = "phrase=\(encoded)&amount=\(decimalAmount)"
            return components.url ?? URL(string: "https://pay.withzcash.com:65536/payment/v1")!
        },
        deriveSpendingKey: { seedBytes, networkType in
            try DerivationTool(networkType: networkType)
                .deriveUnifiedSpendingKey(seed: seedBytes, accountIndex: Zip32AccountIndex(0))
        }
    )
}

public enum PaymentLinkError: Error, Equatable {
    case invalidURL
    case missingMnemonic
    case invalidMnemonic
    case derivationFailed
}

private func parseFragment(_ fragment: String) -> [String: String] {
    var result: [String: String] = [:]
    for pair in fragment.split(separator: "&") {
        let kv = pair.split(separator: "=", maxSplits: 1)
        if kv.count == 2 {
            result[String(kv[0])] = String(kv[1])
        }
    }
    return result
}

private func decimalFromZatoshi(_ zatoshi: Zatoshi) -> String {
    let value = zatoshi.amount
    let whole = value / 100_000_000
    let frac = abs(value) % 100_000_000
    if frac == 0 {
        return "\(whole)"
    }
    let fracStr = String(format: "%08d", frac).replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
    return "\(whole).\(fracStr)"
}

private func zatoshiFromDecimal(_ string: String) -> Zatoshi {
    let parts = string.split(separator: ".", maxSplits: 1)
    let whole = Int64(parts[0]) ?? 0
    var frac: Int64 = 0
    if parts.count == 2 {
        let fracStr = String(parts[1]).padding(toLength: 8, withPad: "0", startingAt: 0)
        frac = Int64(String(fracStr.prefix(8))) ?? 0
    }
    return Zatoshi(whole * 100_000_000 + frac)
}
