# Vendor dependencies

## Syphon Framework

This plugin needs `Syphon.framework` to actually discover servers and pull
textures. Drop a built copy into `vendor/SyphonFramework/Syphon.framework` and
reconfigure CMake; the build will pick it up automatically and define
`HAVE_SYPHON_FRAMEWORK=1`.

### Recommended: hybrid install (works on Xcode 16+ without the Metal Toolchain)

Xcode 26 ships without the Metal Toolchain, so building Syphon-Framework
from source fails at the SyphonMetalShaders.metal step unless you run
`xcodebuild -downloadComponent MetalToolchain` first (large download).

OBS already ships a precompiled, universal Syphon.framework. The cleanest
local path is to combine that binary with the upstream headers:

```bash
# 1. Get the upstream sources for headers
git clone --depth 1 https://github.com/Syphon/Syphon-Framework.git /tmp/Syphon-Framework

# 2. Assemble vendor/SyphonFramework/Syphon.framework
DST=<repo>/vendor/SyphonFramework/Syphon.framework
rm -rf "$DST"
cp -R /Applications/OBS.app/Contents/Frameworks/Syphon.framework "$DST"
chmod -R u+w "$DST"
mkdir -p "$DST/Versions/A/Headers"
cp /tmp/Syphon-Framework/*.h "$DST/Versions/A/Headers/"
( cd "$DST" && ln -sf Versions/Current/Headers Headers )
```

At runtime the plugin's `@rpath/Syphon.framework/...` resolves to OBS's own
bundled framework (the plugin's rpath is `@executable_path/../Frameworks`,
which from OBS's binary points at `/Applications/OBS.app/Contents/Frameworks/`),
so nothing additional has to be embedded in the plugin bundle.

### Alternative: build Syphon-Framework from source

```bash
xcodebuild -downloadComponent MetalToolchain   # ~hundreds of MB, one-time
git clone https://github.com/Syphon/Syphon-Framework.git /tmp/Syphon-Framework
cd /tmp/Syphon-Framework
xcodebuild -project Syphon.xcodeproj -target Syphon \
  -configuration Release -arch arm64 -arch x86_64 ONLY_ACTIVE_ARCH=NO \
  MACOSX_DEPLOYMENT_TARGET=12.0
cp -R build/Release/Syphon.framework <repo>/vendor/SyphonFramework/
```

Without the framework, the plugin still builds and the dock UI works, but
server discovery is disabled (the dock will report "No Syphon servers
running").
