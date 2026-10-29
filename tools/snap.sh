#!/bin/zsh
# Snapshots of the memory window and every Settings tab in light and dark, on test settings.
# Usage: tools/snap.sh            all pages
#        APP_SNAPSHOT_PAGES=window,settings tools/snap.sh
set -u
app=~/Applications/MangoCleaner.app/Contents/MacOS/MangoCleaner
shots=/tmp/MangoCleaner-shots
# A crashed run leaves saved window state, and the next launch would wait on a "reopen windows?" alert.
rm -rf ~/Library/Saved\ Application\ State/com.mangocorp.mangocleaner.savedState
rm -rf $shots
# Quit a running copy first: two menu bar items would confuse the capture.
pkill -x MangoCleaner; sleep 0.5
APP_STORE=/tmp/MangoCleaner-test APP_SNAPSHOT=$shots $app
