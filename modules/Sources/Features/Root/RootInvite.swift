import Combine
import ComposableArchitecture
import Foundation
import ZcashLightClientKit
import Generated
import Models
import PaymentLink
import Deeplink

extension Root {
    public func inviteReduce() -> Reduce<Root.State, Root.Action> {
        Reduce { state, action in
            switch action {

            case .home(.inviteTapped):
                guard let account = state.selectedWalletAccount,
                      let zip32AccountIndex = account.zip32AccountIndex else {
                    return .none
                }
                state.inviteInProgress = true
                let network = zcashSDKEnvironment.network.networkType
                let inviteAmount = Zatoshi(1_000_000) // 0.01 ZEC

                return .run { send in
                    do {
                        let invite = try paymentLink.generateInvite(inviteAmount, network)

                        let recipient = try Recipient(invite.address, network: network)
                        let proposal = try await sdkSynchronizer.proposeTransfer(
                            account.id, recipient, inviteAmount, nil
                        )

                        let storedWallet = try walletStorage.exportWallet()
                        let seedBytes = try mnemonic.toSeed(storedWallet.seedPhrase.value())
                        let spendingKey = try derivationTool.deriveSpendingKey(seedBytes, zip32AccountIndex, network)

                        let result = try await sdkSynchronizer.createProposedTransactions(proposal, spendingKey)

                        switch result {
                        case .success:
                            let url = paymentLink.buildInviteURL(invite.mnemonic, inviteAmount)
                            await send(.inviteSendSucceeded(url))
                        case .grpcFailure:
                            let url = paymentLink.buildInviteURL(invite.mnemonic, inviteAmount)
                            await send(.inviteSendSucceeded(url))
                        case .partial, .failure:
                            await send(.inviteFailed("Transaction could not be completed."))
                        }
                    } catch {
                        await send(.inviteFailed(error.localizedDescription))
                    }
                }

            case .inviteSendSucceeded(let url):
                state.inviteInProgress = false
                let message = "Welcome to Zodl! Click on this link to receive ZEC: \(url.absoluteString)"
                state.messageShareBinding = message
                return .none

            case .inviteFailed(let error):
                state.inviteInProgress = false
                state.$toast.withLock { $0 = .topDelayed5("Invite failed: \(error)") }
                return .none

            case .destination(.deeplink(let url)):
                if Deeplink.isInviteURL(url) {
                    return .send(.redeemInvite(url))
                }
                if let _ = uriParser.checkRP(url.absoluteString, zcashSDKEnvironment.network.networkType) {
                    return .send(.destination(.updateDestination(.deeplinkWarning)))
                }
                return .none

            case .redeemInvite(let url):
                guard let account = state.selectedWalletAccount else {
                    state.$toast.withLock { $0 = .topDelayed5("Please set up your wallet first.") }
                    return .none
                }
                state.inviteRedeemInProgress = true
                let network = zcashSDKEnvironment.network.networkType

                return .run { send in
                    do {
                        let invite = try paymentLink.parseInviteURL(url, network)
                        let ephemeralSpendingKey = try paymentLink.deriveSpendingKey(invite.seedBytes, network)
                        let ufvk = try derivationTool.deriveUnifiedFullViewingKey(ephemeralSpendingKey, network)

                        let accountUUID = try await sdkSynchronizer.importAccount(
                            ufvk.stringEncoded,
                            invite.seedBytes,
                            Zip32AccountIndex(0),
                            AccountPurpose.spending,
                            "Invite",
                            nil
                        )

                        guard let ephemeralAccountID = accountUUID else {
                            await send(.redeemInviteFailed("Could not import invite account."))
                            return
                        }

                        let userAddress = try await sdkSynchronizer.getUnifiedAddress(account.id)
                        guard let address = userAddress else {
                            await send(.redeemInviteFailed("Could not get your wallet address."))
                            return
                        }

                        let fee = Zatoshi(10_000) // standard 0.0001 ZEC fee
                        let sweepAmount = Zatoshi(max(invite.amount.amount - fee.amount, 0))
                        guard sweepAmount.amount > 0 else {
                            await send(.redeemInviteFailed("Invite has no funds."))
                            return
                        }

                        let recipient = try Recipient(address.stringEncoded, network: network)
                        let proposal = try await sdkSynchronizer.proposeTransfer(
                            ephemeralAccountID, recipient, sweepAmount, nil
                        )
                        let result = try await sdkSynchronizer.createProposedTransactions(
                            proposal, ephemeralSpendingKey
                        )

                        switch result {
                        case .success:
                            await send(.redeemInviteSucceeded(sweepAmount))
                        case .grpcFailure:
                            await send(.redeemInviteSucceeded(sweepAmount))
                        case .partial, .failure:
                            await send(.redeemInviteFailed("Could not sweep invite funds."))
                        }
                    } catch {
                        await send(.redeemInviteFailed(error.localizedDescription))
                    }
                }

            case .redeemInviteSucceeded(let amount):
                state.inviteRedeemInProgress = false
                let zec = amount.decimalString()
                state.$toast.withLock { $0 = .topDelayed5("Received \(zec) ZEC from invite!") }
                return .none

            case .redeemInviteFailed(let error):
                state.inviteRedeemInProgress = false
                state.$toast.withLock { $0 = .topDelayed5("Redeem failed: \(error)") }
                return .none

            default: return .none
            }
        }
    }
}
