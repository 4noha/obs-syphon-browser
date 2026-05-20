# obs-syphon-browser

OBS Studio plugin (macOS). Renders Syphon servers as live previews in a
dedicated Qt dock — without ever putting them on Program or Preview. The
user clicks "Add to current scene" on a preview tile to commit a server to
the broadcast pipeline.

User-visible name in OBS: **"4K Splitter"** (dock title, locale string,
`obs_module_name()`). Internals stay `obs-syphon-browser` (bundle id, repo,
target).

## Non-negotiable invariant

Previews use private `obs_display_t` surfaces bound to native NSViews
inside Qt widgets. These render off the Program/Preview graph — frames there
**never** reach broadcast or recording. Internal `obs_source_t` instances
created for preview must never be added to any `obs_scene_t`. The only path
into a scene is the explicit "Add to current scene" button which calls
`obs_source_create("syphon-input", ...)` + `obs_scene_add(...)`.

Break this invariant and you defeat the entire reason the plugin exists.

## File map

```
src/
  plugin-main.cpp              OBS module entry, dock registration on
                               OBS_FRONTEND_EVENT_FINISHED_LOADING
  syphon-browser-dock.{hpp,cpp} Qt QFrame grid of preview tiles + status label
  syphon-preview-tile.{hpp,mm}  Single tile: native-NSView widget + private
                               obs_display + "Add to current scene" button.
                               Must be .mm — gs_init_data.window.view is `id`
                               on macOS.
  syphon-server-directory.{hpp,mm}  NSNotificationCenter subscription on
                               SyphonServerAnnounce/Retire/Update; emits
                               serversChanged signal to dock.
  syphon-client.{hpp,mm}        SyphonMetalClient pull-mode (newFrameImage
                               returns id<MTLTexture>, not a SyphonImage
                               wrapper — that's the deprecated GL path).
                               Pulls IOSurface from the texture, hands to
                               gs_texture_create_from_iosurface.
vendor/SyphonFramework/Syphon.framework   Not in git. See "Build" below.
data/locale/en-US.ini          SyphonBrowser.Title = "4K Splitter"
```

ARC is enabled for `.mm` files. Don't write `[obj release]`.

## Build

```bash
cmake --preset macos
cmake --build --preset macos --config RelWithDebInfo
cmake --install build_macos --config RelWithDebInfo
# Clean the package-staging cruft cmake/install leaves behind:
rm -rf ~/Library/Application\ Support/obs-studio/plugins/{package,temp,obs-syphon-browser.pkg}
```

First `cmake --preset macos` downloads obs-deps, Qt6 prebuilt, and the
OBS 31.1.1 source tarball into `.deps/` (~500 MB).

OBS must be **stopped** before reinstalling. Otherwise the swap silently
no-ops and the next launch keeps the old binary.

## Vendoring Syphon.framework

The plugin will build without it (HAVE_SYPHON_FRAMEWORK=0) but discovery is
disabled — dock just shows "No Syphon servers running". To enable:

Xcode 26 ships without the Metal Toolchain, so `xcodebuild` on the Syphon
upstream sources fails at SyphonMetalShaders.metal. Workaround: combine
OBS's bundled Syphon binary with the upstream headers (hybrid install).
Recipe is in `vendor/README.md`.

At runtime the plugin's `@rpath/Syphon.framework/...` resolves to OBS's own
`/Applications/OBS.app/Contents/Frameworks/Syphon.framework` via the
`@executable_path/../Frameworks` rpath entry. Nothing about Syphon is
embedded in the plugin bundle.

## Three gotchas baked into the build that look weird but are necessary

### 1. `cmake/.CMakeBuildNumber` must exist with an integer

`cmake/common/buildnumber.cmake` only sets `PLUGIN_BUILD_NUMBER` when
either `$ENV{CI}` is set or the cache file exists. Outside CI on a fresh
checkout, the variable is empty, and the helper `set_target_properties_plugin`
gets misaligned key/value pairs and dies with "called with incorrect number
of arguments". Seed with `echo 1 > cmake/.CMakeBuildNumber`.

### 2. AGL.framework stub is created at configure time and embedded in the bundle

Qt6's prebuilt `.prl` files transitively list `-framework AGL`, but AGL was
removed from the macOS 14+ SDK. CMakeLists.txt builds an empty universal
AGL.framework under `${CMAKE_BINARY_DIR}/agl-stub/` so the linker can resolve
the reference, and a POST_BUILD step `ditto`s it into
`<plugin>/Contents/Frameworks/AGL.framework` and re-signs the bundle.

The plugin's rpath has both `@executable_path/../Frameworks` (for OBS-bundled
deps like Syphon and Qt) and `@loader_path/../Frameworks` (for the embedded
AGL stub). Use `ditto`, not `cmake -E copy_directory` — the latter follows
symlinks and breaks the framework layout, after which codesign reports
"bundle format is ambiguous".

### 3. CMake's INSTALL_RPATH / BUILD_RPATH are no-ops here

`cmake/macos/xcode.cmake` sets `CMAKE_SKIP_RPATH=TRUE` and configures rpath
exclusively via the Xcode attribute `LD_RUNPATH_SEARCH_PATHS`. If you need
to add an rpath, override that XCODE_ATTRIBUTE on the target — touching
INSTALL_RPATH/BUILD_RPATH does nothing.

## Diagnosing load failures

If OBS shows "プラグインの読み込みに失敗しました" / "Failed to load plugin":

```bash
LATEST=$(ls -t ~/Library/Application\ Support/obs-studio/logs/*.txt | head -1)
grep -i obs-syphon-browser "$LATEST"
```

The line you want is the `os_dlopen` failure right before
`Module ... not loaded`. Usually a `Library not loaded: @rpath/...` line
tells you which dylib dyld couldn't find — that's almost always an rpath
or embedding problem, not a code problem.

## Related project

`~/works/4ksplitter_` (separate repo, Unity) is the Syphon **sender**.
This plugin is the receiving side: the 4ksplitter app emits 4 views as
Syphon servers, OBS sees them in the dock, the user picks which view goes
on air via "Add to current scene".
