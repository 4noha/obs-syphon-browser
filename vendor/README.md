# Vendor dependencies

## Syphon Framework

This plugin needs `Syphon.framework` to actually discover servers and pull
textures. Drop a built copy into `vendor/SyphonFramework/Syphon.framework` and
reconfigure CMake; the build will pick it up automatically and define
`HAVE_SYPHON_FRAMEWORK=1`.

Build it from source:

```bash
git clone https://github.com/Syphon/Syphon-Framework.git /tmp/Syphon-Framework
cd /tmp/Syphon-Framework
xcodebuild -project Syphon.xcodeproj -target Syphon \
  -configuration Release -arch arm64 -arch x86_64
mkdir -p <repo>/vendor/SyphonFramework
cp -R build/Release/Syphon.framework <repo>/vendor/SyphonFramework/
```

OBS itself ships a `Syphon.framework` inside its bundle at
`/Applications/OBS.app/Contents/Frameworks/Syphon.framework` — you can copy
that for development, but the build-from-source path above is preferred for
reproducibility.

Without the framework, the plugin still builds and the dock UI works, but
server discovery is disabled (the dock will report "No Syphon servers
running").
