#!/bin/zsh
# Runs the in-app self-test on test settings. Exit code 0 when every check passed.
set -u
rm -rf ~/Library/Saved\ Application\ State/com.mangocorp.mangomemory.savedState
pkill -x MangoMemory; sleep 0.5
APP_STORE=/tmp/MangoMemory-self ~/Applications/MangoMemory.app/Contents/MacOS/MangoMemory --selftest
