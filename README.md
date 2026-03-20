# Zodl iOS - Zcash Payment Links

Fork of [Zashi iOS](https://github.com/Electric-Coin-Company/zashi-ios) implementing [ZIP-324: URI-Encapsulated Payments](https://zips.z.cash/zip-0324) for Zcash payment links.

## What Are Payment Links?

Payment links let you onboard anyone to Zcash by sending them a URL. No address exchange needed. The sender creates a link containing an ephemeral wallet key, funds it, and shares it. The recipient clicks the link and the funds are swept into their wallet automatically.

```
"Welcome to Zodl! Click on this link to get 0.01 ZEC:
https://pay.withzcash.com:65536/payment/v1#phrase=YWJhbmRvbi4uLg==&amount=0.01"
```

This is the same onboarding UX used by Venmo, Zelle, and Cash App - just send a message to a friend.

## How It Works

### Sending an Invite

1. Tap **Invite a Friend** on the Home screen
2. A fresh 24-word BIP39 mnemonic is generated
3. A unified address is derived from the mnemonic
4. 0.01 ZEC is sent to that address
5. An invite URL is created and shared via the iOS share sheet

### Redeeming an Invite

1. Recipient opens the invite URL
2. The app parses the mnemonic from the URL fragment
3. The ephemeral spending key is derived
4. Funds are swept (minus fee) to the recipient's wallet
5. Done - the ZEC is in their wallet

### URL Format (ZIP-324)

```
https://pay.withzcash.com:65536/payment/v1#phrase={base64_mnemonic}&amount={decimal_zec}
```

- **Port 65536** is intentionally invalid TCP - prevents browsers from making HTTP requests, keeping the secret in the fragment safe (per ZIP-324)
- **Fragment (`#`)** parameters are never sent to servers by HTTP clients
- **`phrase`** is the base64-encoded BIP39 mnemonic (the secret key to the ephemeral wallet)
- **`amount`** is the decimal ZEC amount

## Architecture

### PaymentLink Module

Standalone library at `modules/Sources/Dependencies/PaymentLink/` with no UI dependencies. Handles:

- Mnemonic generation and key derivation
- Invite URL construction and parsing
- Spending key derivation for sweeping

### Integration Points

- **Home** - "Invite a Friend" button triggers invite generation
- **Root** - `RootInvite.swift` orchestrates the send and redeem flows
- **Deeplink** - Extended to recognize invite URLs via `Deeplink.isInviteURL()`
- **RootView** - Progress overlay shown during send/redeem

### Files

```
modules/Sources/Dependencies/PaymentLink/
├── PaymentLinkClient.swift      # Interface + InviteCode model
├── PaymentLinkLiveKey.swift      # Live implementation
└── PaymentLinkTestKey.swift      # Test stubs

modules/Sources/Features/Root/
└── RootInvite.swift              # Invite send + redeem reducer

secantTests/PaymentLinkTests/
└── PaymentLinkTests.swift        # Unit tests
```

## Testing

The `PaymentLink` module has unit tests covering:

- URL generation with correct format and parameters
- URL parsing round-trip (generate -> URL -> parse -> verify)
- Invalid URL and mnemonic error handling
- Deeplink detection for invite vs non-invite URLs
- Invite code generation with unique mnemonics
- Full round-trip: generate invite -> build URL -> parse URL -> verify all fields match
- Spending key derivation from parsed invite

Use the `secant-testnet` scheme to test on Zcash testnet (TAZ).

## Building

Open `secant.xcodeproj` in Xcode and build the `secant-testnet` target for testnet or `secant-mainnet` for mainnet.

## References

- [ZIP-324: URI-Encapsulated Payments](https://zips.z.cash/zip-0324)
- [ZIP-321: Payment Request URIs](https://zips.z.cash/zip-0321)
- [Hackathon: Zcash Payment Links](https://ns.com/earn/zodl-desktop-wallet-for-mac)
