# Syphon Browser for OBS

OBS Studio plugin (macOS) that lets you **browse and preview Syphon servers in a
dedicated dock** without ever placing them on the program/preview canvas.
Previews are rendered to private `obs_display_t` surfaces that bypass the
broadcast/recording pipeline entirely, so there is no risk of an unintended
source leaking on air. When you pick one, the plugin instantiates the standard
`syphon-input` source and adds it to the current scene.

## Why this exists

OBS's normal workflow forces you to add a source to a scene to see what it
contains. For workflows where the program output is hot (live streaming,
recording), that's a real hazard. This plugin treats Syphon discovery as a
side-channel: enumerate, preview, then commit.

## Architecture

```
SyphonServerDirectory (NSNotificationCenter)
        │
        ▼
SyphonBrowserDock (Qt6, registered via obs_frontend_add_dock_by_id)
        │
        ├── grid of SyphonPreviewTile widgets
        │     ├── SyphonClient (IOSurfaceRef pump)
        │     ├── obs_display_t bound to QWidget::winId()  ← private; not on program
        │     └── "Add to current scene" → obs_scene_add(syphon-input)
        │
        └── settings (server filter, tile size, refresh rate)
```

Key invariant: `obs_source_t` instances created internally for preview never
enter `obs_scene_t`. Only the explicit user action creates a scene-resident
source.

## Build

Requires macOS 12+, Xcode 16+, CMake 3.30+. Dependencies (libobs, Qt6,
prebuilt obs-deps) are downloaded automatically by CMake into `.deps/`.

```bash
cmake --preset macos
cmake --build --preset macos --config RelWithDebInfo
```

The built `.plugin` bundle is installed to
`~/Library/Application Support/obs-studio/plugins/` via the `install` target.

## Status

Early prototype. See task list / commits for current progress.

## License

GPL-2.0-or-later (matches OBS).
