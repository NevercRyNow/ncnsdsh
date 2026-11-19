#!/usr/bin/env bash
# 本地准备内置引擎：克隆 dsh-Go 的 iOS 分支，跑它自己的 prepare / build，把产物放进 Engine/。
# CI 走的是同样的步骤（见 .github/workflows/ios.yml）。需要 macOS + Xcode + python3.11+。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REF="${1:-ios/shared-runtime-after-ohos}"
WORK="${DSH_GO_CHECKOUT:-$ROOT/.engine-src}"

if [[ ! -d "$WORK/.git" ]]; then
  git clone --depth 1 --branch "$REF" https://github.com/ccch1mneyyy/dsh-Go.git "$WORK"
fi
cd "$WORK"
./tooling/ios/prepare-engine.sh
mkdir -p build/engine
./tooling/ios/build-engine-native.sh iphoneos "$PWD/build/engine"

mkdir -p "$ROOT/Engine/Frameworks"
cp -R build/engine/*.framework "$ROOT/Engine/Frameworks/"
cp -R app/ios/Engine/NodeMobile.xcframework "$ROOT/Engine/" 2>/dev/null || true
cp app/ios/Engine/runtime.zip "$ROOT/Engine/" 2>/dev/null || true
echo "engine staged into $ROOT/Engine"
