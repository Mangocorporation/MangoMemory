#!/bin/zsh
# Runs the in-app self-test against a fresh store in /tmp. Exit code 0 when every check passed.
set -u
rm -rf ~/Library/Saved\ Application\ State/com.mangocorp.mangocleaner.savedState
store=/tmp/MangoCleaner-self.store
rm -f $store $store-shm $store-wal
APP_STORE=$store ~/Applications/MangoCleaner.app/Contents/MacOS/MangoCleaner --selftest
