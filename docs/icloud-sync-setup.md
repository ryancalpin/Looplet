# iCloud Sync Setup (Pattern Library + Yarn Stash)

CrochetApp can optionally mirror your pattern library and yarn stash across all
your Macs (and any device signed into the same iCloud account) using **iCloud
Key-Value Store** (`NSUbiquitousKeyValueStore`). This is the lightest-weight
iCloud option — there is no CloudKit schema to manage, and the data involved
(two small JSON blobs) is tiny.

The sync code is already implemented and ships in the app. It is **inactive by
default** because activating it requires code signing with your Apple developer
team and the iCloud capability — neither of which can be configured in an
unsigned build. The steps below are the one-time manual setup to turn it on.

## Activate sync in Xcode

1. Open `CrochetApp.xcodeproj` and select the **CrochetApp** app target →
   **Signing & Capabilities**.
2. Set your **Team** and enable **Automatically manage signing**.
3. Click **+ Capability**, add **iCloud**, and check **Key-value storage**.
4. Xcode auto-creates/links the entitlement. A `CrochetApp.entitlements` file
   with the correct key (`com.apple.developer.ubiquity-kvstore-identifier` =
   `$(TeamIdentifierPrefix)$(CFBundleIdentifier)`) is already committed and wired
   into the project. **If Xcode generates a different entitlements file or value,
   let Xcode's version win** — it knows your team/container.
5. Build and run the **signed** app on two devices logged into the **same iCloud
   account**. Make a change on one (add a pattern or yarn entry) and confirm it
   appears on the other.

## How it works

- The app keeps writing its local JSON files
  (`~/Library/Application Support/CrochetApp/patterns.json` and `yarn.json`).
  **The local JSON files remain the source of truth.** The app works fully
  without iCloud — sync is purely additive.
- On every `save()` / `saveYarn()`, the app also pushes the encoded data plus a
  fresh timestamp to iCloud KVS.
- On launch and whenever iCloud reports an external change, the app pulls the
  remote payload **only if its timestamp is newer** than the local copy
  (last-writer-wins), decodes it, replaces the in-memory data, and writes it back
  to the local JSON.
- A guard flag (`isApplyingRemote`) ensures that applying a pulled change does
  **not** trigger a re-push, so devices never ping-pong updates.

## Limits & safety

- iCloud KVS limits: **1 MB total, 1 MB per key.** This app stores two small
  JSON blobs well under those limits.
- All `NSUbiquitousKeyValueStore` calls are safe to make even without the
  entitlement — they simply don't persist remotely and reads return defaults. So
  the unsigned build runs identically; nothing crashes and local persistence is
  never blocked.
