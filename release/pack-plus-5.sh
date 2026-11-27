#!/bin/zsh
# Assembles release-out/plus5/pack/SkyrimTogether-1.8.4-plus.5 from the plus.4 pack (game data, CEF, mod-set) with
# plus.5's binaries, overlay, classic servers, relay, Play/Host programs and docs. Then zips it as the Windows download,
# and makes the Mac download (the Mac app with its own scripts, mac-app/build.sh --release) next to it.
set -e
R=~/Documents/Skyrim-RE-References
OUT=$R/release-out/plus5/pack/SkyrimTogether-1.8.4-plus.5
OLD=$R/release-out/plus4/pack/SkyrimTogether-1.8.4-plus.4
PLAY=${PLAY_DIR:?set PLAY_DIR to the folder with the rebuilt PlaySkyrimTogether.exe and SkyrimTogetherHost.exe}
rm -rf $OUT; mkdir -p ${OUT:h}
cp -c -R $OLD $OUT
typeset -A bins; bins=(SkyrimTogether-1.6.1170 bin-1.6.1170 SkyrimTogether-1.7.104 bin-latest)
typeset -A classic; classic=(SkyrimTogether-1.6.1170 1.6.1170 SkyrimTogether-1.7.104 1.7.104)
for d in ${(k)bins}; do
  st=$OUT/$d/SkyrimTogetherReborn
  cp $R/release-out/plus5/${bins[$d]}/{SkyrimTogether.exe,TPProcess.exe,EarlyLoad.dll,STServer.dll,SkyrimTogetherServer.exe} $st/
  rm -rf $st/UI; cp -R $R/build-plus-steal/Code/skyrim_ui/dist/UI $st/UI
  mkdir -p $st/classic; cp $R/release-out/classic/${classic[$d]}/{SkyrimTogetherServer.exe,STServer.dll} $st/classic/
done
mkdir -p $OUT/relay
cp $R/release-out/plus5/bin-1.6.1170/SkyrimTogetherRelay.exe $OUT/relay/
cp $R/build-plus-steal/Code/relay/README.md $OUT/relay/README.md
cp $PLAY/PlaySkyrimTogether.exe "$OUT/Play Skyrim Together.exe"
cp $PLAY/SkyrimTogetherHost.exe "$OUT/Skyrim Together Host.exe"
DOCS=${0:A:h}/docs
cp $DOCS/INSTALL.md $DOCS/PLUS-FEATURES.md $OUT/
WIN=$R/release-out/plus5/SkyrimTogether-1.8.4-plus.5-Windows.zip
cd ${OUT:h}; rm -f $WIN
zip -qr -X $WIN SkyrimTogether-1.8.4-plus.5 -x '*.DS_Store'
# Mac: the app finds its bundled scripts, and its Install button fetches the Windows zip above from the release
APP=$(${0:A:h}/../mac-app/build.sh --release plus.5)
MAC=$R/release-out/plus5/mac/"Skyrim Together Plus (Mac)"
rm -rf ${MAC:h}; mkdir -p $MAC
ditto $APP $MAC/"Skyrim Together.app"; cp $DOCS/MAC-INSTALL.md $DOCS/PLUS-FEATURES.md $MAC/
rm -f $R/release-out/plus5/SkyrimTogether-1.8.4-plus.5-Mac.zip
(cd ${MAC:h} && ditto -c -k --norsrc --noextattr --keepParent ${MAC:t} $R/release-out/plus5/SkyrimTogether-1.8.4-plus.5-Mac.zip)
echo PACKED
