#!/bin/bash

git fetch --unshallow
COUNT=$(git rev-list --count HEAD)
FILE=MiniGames-git$COUNT-$2.7z
LATEST=MiniGames-$1-latest.7z

echo " "
echo "*** Trigger build ***"
echo " "
#wget "https://github.com/Kxnrl/Store/raw/master/include/store.inc" -q -O include/store.inc
wget "https://github.com/Kxnrl/MapMusic-API/raw/master/include/mapmusic.inc" -q -O include/mapmusic.inc
wget "https://github.com/Impact123/AutoExecConfig/raw/development/autoexecconfig.inc" -q -O include/autoexecconfig.inc
wget "https://github.com/Kxnrl/GeoIP2/raw/master/geoip2.inc" -q -O include/geoip2.inc
wget "https://github.com/fys-csgo/public-include/raw/master/fys.pupd.inc" -q -O include/fys.pupd.inc
wget "https://github.com/fys-csgo/public-include/raw/master/fys.opts.inc" -q -O include/fys.opts.inc
wget "https://www.sourcemod.net/latest.php?version=$1&os=linux" -q -O sourcemod.tar.gz
tar -xzf sourcemod.tar.gz

chmod +x addons/sourcemod/scripting/spcomp

for file in include/minigames.inc
do
  sed -i "s%<commit_counts>%$COUNT%g" $file > output.txt
  rm output.txt
done

mkdir build
mkdir build/plugins
mkdir build/scripting

cp -rf include/*            addons/sourcemod/scripting/include
cp -rf minigames            addons/sourcemod/scripting
cp -rf MiniGames.sp         addons/sourcemod/scripting
cp -rf ammomanager.sp       addons/sourcemod/scripting
cp -rf bspcvar.sp           addons/sourcemod/scripting
cp -rf buttonlocker.sp      addons/sourcemod/scripting
cp -rf defaultskin.sp       addons/sourcemod/scripting
cp -rf inputkill_hotfix.sp  addons/sourcemod/scripting

addons/sourcemod/scripting/spcomp -E -v0 addons/sourcemod/scripting/MiniGames.sp -o"build/plugins/MiniGames.smx"
addons/sourcemod/scripting/spcomp -E -v0 addons/sourcemod/scripting/ammomanager.sp -o"build/plugins/ammomanager.smx"
addons/sourcemod/scripting/spcomp -E -v0 addons/sourcemod/scripting/bspcvar.sp -o"build/plugins/bspcvar.smx"
addons/sourcemod/scripting/spcomp -E -v0 addons/sourcemod/scripting/buttonlocker.sp -o"build/plugins/buttonlocker.smx"
addons/sourcemod/scripting/spcomp -E -v0 addons/sourcemod/scripting/defaultskin.sp -o"build/plugins/defaultskin.smx"
addons/sourcemod/scripting/spcomp -E -v0 addons/sourcemod/scripting/inputkill_hotfix.sp -o"build/plugins/inputkill_hotfix.smx"

if [ ! -f "build/plugins/MiniGames.smx" ]; then
    echo "Compile failed!"
    exit 1;
fi

if [ ! -f "build/plugins/ammomanager.smx" ]; then
    echo "Compile failed!"
    exit 1;
fi

if [ ! -f "build/plugins/bspcvar.smx" ]; then
    echo "Compile failed!"
    exit 1;
fi

if [ ! -f "build/plugins/buttonlocker.smx" ]; then
    echo "Compile failed!"
    exit 1;
fi

if [ ! -f "build/plugins/defaultskin.smx" ]; then
    echo "Compile failed!"
    exit 1;
fi

if [ ! -f "build/plugins/inputkill_hotfix.smx" ]; then
    echo "Compile failed!"
    exit 1;
fi


mv LICENSE.md README.md build
mv include              build/scripting
mv minigames            build/scripting
mv MiniGames.sp         build/scripting
mv ammomanager.sp       build/scripting
mv bspcvar.sp           build/scripting
mv buttonlocker.sp      build/scripting
mv defaultskin.sp       build/scripting
mv inputkill_hotfix.sp  build/scripting
mv translations         build
mv gamedata             build

cd build
7z a $FILE -t7z -mx9 LICENSE.md README.md plugins scripting translations >nul
7z a $LATEST -t7z -mx9 LICENSE.md README.md plugins scripting translations >nul

echo "Upload file rsync ..."
RSYNC_PASSWORD=$RSYNC_PSWD rsync -avz --port $RSYNC_PORT ./$FILE $RSYNC_USER@$RSYNC_HOST::TravisCI/MiniGames/$1/
RSYNC_PASSWORD=$RSYNC_PSWD rsync -avz --port $RSYNC_PORT ./$LATEST $RSYNC_USER@$RSYNC_HOST::TravisCI/MiniGames/

if [ "$1" = "1.10" ]; then
echo "Upload RAW rsync ..."
RSYNC_PASSWORD=$RSYNC_PSWD rsync -avz --port $RSYNC_PORT ./plugins/MiniGames.smx $RSYNC_USER@$RSYNC_HOST::TravisCI/MiniGames/updater/plugins/
RSYNC_PASSWORD=$RSYNC_PSWD rsync -avz --port $RSYNC_PORT ./plugins/bspcvar.smx $RSYNC_USER@$RSYNC_HOST::TravisCI/MiniGames/updater/plugins/
RSYNC_PASSWORD=$RSYNC_PSWD rsync -avz --port $RSYNC_PORT ./plugins/buttonlocker.smx $RSYNC_USER@$RSYNC_HOST::TravisCI/MiniGames/updater/plugins/
RSYNC_PASSWORD=$RSYNC_PSWD rsync -avz --port $RSYNC_PORT ./plugins/defaultskin.smx $RSYNC_USER@$RSYNC_HOST::TravisCI/MiniGames/updater/plugins/
RSYNC_PASSWORD=$RSYNC_PSWD rsync -avz --port $RSYNC_PORT ./plugins/ammomanager.smx $RSYNC_USER@$RSYNC_HOST::TravisCI/MiniGames/updater/plugins/
RSYNC_PASSWORD=$RSYNC_PSWD rsync -avz --port $RSYNC_PORT ./plugins/inputkill_hotfix.smx $RSYNC_USER@$RSYNC_HOST::TravisCI/MiniGames/updater/plugins/
RSYNC_PASSWORD=$RSYNC_PSWD rsync -avz --port $RSYNC_PORT ./translations/com.kxnrl.minigames.translations.txt $RSYNC_USER@$RSYNC_HOST::TravisCI/MiniGames/updater/translations/
fi
