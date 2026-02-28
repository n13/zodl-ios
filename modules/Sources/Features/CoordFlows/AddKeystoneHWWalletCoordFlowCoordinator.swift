//
//  AddKeystoneHWWalletCoordFlowCoordinator.swift
//  Zashi
//
//  Created by Lukáš Korba on 2025-03-19.
//

import ComposableArchitecture
import Generated
import AudioServices
import ZcashLightClientKit

// Path
import AddKeystoneHWWallet
import Scan
import WalletBirthday

extension AddKeystoneHWWalletCoordFlow {
    public func coordinatorReduce() -> Reduce<AddKeystoneHWWalletCoordFlow.State, AddKeystoneHWWalletCoordFlow.Action> {
        Reduce { state, action in
            switch action {
                
                // MARK: - Scan
                
            case .path(.element(id: _, action: .scan(.foundAccounts(let account)))):
                var addKeystoneHWWalletState = AddKeystoneHWWallet.State.initial
                addKeystoneHWWalletState.zcashAccounts = account
                state.path.append(.accountHWWalletSelection(addKeystoneHWWalletState))
                audioServices.systemSoundVibrate()
                return .none
                
            case .path(.element(id: _, action: .scan(.cancelTapped))):
                let _ = state.path.popLast()
                return .none
                
                // MARK: - Account Selection

            case .path(.element(id: _, action: .accountHWWalletSelection(.unlockTapped))):
                state.path.append(.walletBirthday(WalletBirthday.State.initial))
                return .none

                // MARK: - Wallet Birthday

            case .path(.element(id: _, action: .walletBirthday(.estimateHeightTapped))):
                state.path.append(.estimateBirthdaysDate(WalletBirthday.State.initial))
                return .none

            case .path(.element(id: _, action: .walletBirthday(.restoreTapped))):
                for element in state.path {
                    if case .walletBirthday(let birthdayState) = element {
                        return sendImportToAccountElement(birthday: birthdayState.estimatedHeight, state: &state)
                    }
                }
                return .none

            case .path(.element(id: _, action: .estimateBirthdaysDate(.estimateHeightReady))):
                for element in state.path {
                    if case .estimateBirthdaysDate(let dateState) = element {
                        state.path.append(.estimatedBirthday(dateState))
                    }
                }
                return .none

            case .path(.element(id: _, action: .estimatedBirthday(.restoreTapped))):
                for element in state.path {
                    if case .estimatedBirthday(let birthdayState) = element {
                        return sendImportToAccountElement(birthday: birthdayState.estimatedHeight, state: &state)
                    }
                }
                return .none

                // MARK: - Self

            case .addKeystoneHWWallet(.readyToScanTapped):
                var scanState = Scan.State.initial
                scanState.checkers = [.keystoneScanChecker]
                scanState.instructions = L10n.Keystone.scanInfo
                scanState.forceLibraryToHide = true
                state.path.append(.scan(scanState))
                return .none

            default: return .none
            }
        }
    }

    private func sendImportToAccountElement(
        birthday: BlockHeight,
        state: inout AddKeystoneHWWalletCoordFlow.State
    ) -> Effect<AddKeystoneHWWalletCoordFlow.Action> {
        for (id, element) in zip(state.path.ids, state.path) {
            if case .accountHWWalletSelection = element {
                return .send(.path(.element(id: id, action: .accountHWWalletSelection(.importKeystoneAccount(birthday)))))
            }
        }
        return .none
    }
}
