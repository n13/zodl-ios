//
//  Deeplink.swift
//  Zashi
//
//  Created by Lukáš Korba on 15.06.2022.
//

import Foundation
import URLRouting
import ComposableArchitecture
import ZcashLightClientKit

public struct Deeplink {
    public enum Destination: Equatable {
        case home
        case send(amount: Int, address: String, memo: String)
        case invite(URL)
    }
    
    public init() { }

    public static func isInviteURL(_ url: URL) -> Bool {
        let abs = url.absoluteString
        return abs.contains("pay.withzcash.com") && abs.contains("phrase=")
            || abs.contains("pay.testzcash.com") && abs.contains("phrase=")
    }

    public func resolveDeeplinkURL(
        _ url: URL,
        networkType: NetworkType,
        isValidZcashAddress: (String, NetworkType) throws -> Bool
    ) throws -> Destination {
        if Deeplink.isInviteURL(url) {
            return .invite(url)
        }

        let address = url.absoluteString.replacingOccurrences(of: "zcash:", with: "")
        do {
            if try isValidZcashAddress(address, networkType) {
                return .send(amount: 0, address: address, memo: "")
            }
        }
      
        let appRouter = OneOf {
            Route(.case(Destination.home)) {
                Path { "home" }
            }

            Route(.case(Destination.send(amount:address:memo:))) {
                Path { "home"; "send" }
                Query {
                    Field("amount", default: 0) { Digits() }
                    Field("address", .string, default: "")
                    Field("memo", .string, default: "")
                }
            }
        }

        switch try appRouter.match(url: url) {
        case .home:
            return .home
        case let .send(amount, address, memo):
            return .send(amount: amount, address: address, memo: memo)
        case .invite:
            return .invite(url)
        }
    }
}
