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

3. **Update signing key** (Sparkle, for Check for Updates). Made once with

   ```bash
   ~/Library/Developer/MangoMemory/build/artifacts/sparkle/Sparkle/bin/generate_keys
   ```

   The private key stays in your login keychain; the public key is
   `SUPublicEDKey` in `Info.plist.in`. **Back it up**
   (`generate_keys -x <file>`, kept somewhere safe and never in git): without
   it, no installed copy will ever accept an update again.

`tools/release.sh --check` says what is still missing.

## Each release

1. Raise `CFBundleShortVersionString` in `Info.plist.in`.
2. Write what changed in `docs/releases/<version>.md` (Markdown). Check for
   Updates shows it, and so does the GitHub release.
3. `tools/release.sh`. Notarization takes a few minutes. `spctl` should say
   "source=Notarized Developer ID". The script signs the zip with the update
   key and adds it to `site/appcast.xml`.
4. `tools/publish.sh`. It creates the GitHub release with the zip, waits until
   the zip downloads, and only then commits and pushes the feed. The other
   order would offer an update that does not exist yet.

Every Mac running 0.1.3 or later sees the update within a day, or at once
with gear › Check for Updates….

The helper accepts only MangoMemory signed by team SJR7785KA2, so a Developer
ID build and a development build both work with it.
