#!/bin/sh
# 한글 오토마타 테스트. Xcode 없이 Swift 커맨드라인만 있으면 돈다.
set -e
cd "$(dirname "$0")/.."
OUT=$(mktemp -d)
swiftc -O Shared/Hangul.swift \
          Shared/NaratgeulEngine.swift \
          Shared/KeySequence.swift \
          NaratgeulKeyboard/PracticeItems.swift \
          Tests/main.swift -o "$OUT/enginetest"
"$OUT/enginetest"
