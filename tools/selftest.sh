#!/bin/zsh
# Runs the in-app self-test on test settings. Exit code 0 when every check passed.
set -u
rm -rf ~/Library/Saved\ Application\ State/com.mangocorp.mangocleaner.savedState
pkill -x MangoCleaner; sleep 0.5
APP_STORE=/tmp/MangoCleaner-self ~/Applications/MangoCleaner.app/Contents/MacOS/MangoCleaner --selftest
