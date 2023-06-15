# Go to build dir
cd build

# Create package dir
mkdir -p package/addons/sourcemod/plugins
mkdir -p package/addons/sourcemod/gamedata

# Copy all required stuffs to package
cp -r addons/sourcemod/plugins/vscript.smx package/addons/sourcemod/plugins
cp -r ../gamedata/vscript.txt package/addons/sourcemod/gamedata
cp -r ../LICENSE package