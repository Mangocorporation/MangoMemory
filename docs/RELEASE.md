# Releasing MangoMemory

A release runs on any Mac: signed with Developer ID, hardened runtime,
notarized by Apple, ticket stapled. `tools/release.sh` does all of it and
writes `dist/MangoMemory-<version>.zip` (dist/ is not in git).

## Once per Mac

1. **Developer ID certificate.** Only the Account Holder of team SJR7785KA2
   can create one. In Xcode: Settings › Accounts › your team › Manage
   Certificates › + › Developer ID Application. (Or developer.apple.com ›
   Certificates › +, then double-click the downloaded file.)
2. **Notarization credentials.** Make an app-specific password at
   account.apple.com › Sign-In and Security › App-Specific Passwords, then run:

   ```bash
   xcrun notarytool store-credentials MangoMemory \
     --apple-id <your Apple ID> --team-id SJR7785KA2
   ```

   It asks for the password and keeps it in your keychain.

`tools/release.sh --check` says which of the two is still missing.

## Each release

1. Raise `CFBundleShortVersionString` in `Info.plist.in`.
2. `tools/release.sh`. Notarization takes a few minutes.
3. The last line names the zip. `spctl` above it should say
   "source=Notarized Developer ID".

The helper accepts only MangoMemory signed by team SJR7785KA2, so a Developer
ID build and a development build both work with it.
