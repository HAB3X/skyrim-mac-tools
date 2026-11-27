#!/bin/zsh
# Binaries for v1.8.4-plus.5 from plus-steal: client, server, runner and relay, for game versions 1.6.1170 and latest (1.7.x).
set -e
. ~/Developer/xwin/env.sh
R=~/Documents/Skyrim-RE-References
common=(-y -p windows -a x64 -m release --toolchain=clang-cl --sdk=$WINSYSROOT --mrc=llvm-rc --release_build=y)
cd $R/build-plus-steal
for v in 1.6.1170 latest; do
  echo "== plus.5 $v ($(git rev-parse --short HEAD))"
  xmake f $common --skyrim_version=$v --build_version=v1.8.4-plus.5 >/dev/null
  xmake build SkyrimTogetherClient SkyrimImmersiveLauncher TPProcess ImmersiveElf SkyrimTogetherServer SkyrimServerRunner SkyrimTogetherRelay FakePlayers TPTests
  mkdir -p $R/release-out/plus5/bin-$v
  cp build/windows/x64/release/{SkyrimTogether.exe,TPProcess.exe,EarlyLoad.dll,STServer.dll,SkyrimTogetherServer.exe,SkyrimTogetherRelay.exe} $R/release-out/plus5/bin-$v/
done
# Leave the tree configured for this Mac's game (1.6.1179 uses the 1.6.1170 build)
xmake f $common --skyrim_version=1.6.1170 --build_version=v1.8.4-plus.5 >/dev/null
xmake build SkyrimTogetherClient SkyrimImmersiveLauncher TPProcess ImmersiveElf SkyrimTogetherServer SkyrimServerRunner SkyrimTogetherRelay FakePlayers TPTests
echo ALL DONE
