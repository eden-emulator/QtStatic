# QtStatic

Static builds of Qt 6

## Licensing

These builds are distributed under the terms of Qt's license. The build script itself is GPLv3.

## TODO

- cross comp
- docs on deps?
- windows
- CPU opts; e.g. build for your specific CPU :)

## deps

That I know of at least.

All platforms require Ninja, CMake >=3.22, and Python.

### Linux

Basically just X11, glib, zstd, and pthread. Vulkan maybe? <https://doc.qt.io/qt-6/linux-requirements.html>

Also check Arch Linux packages for:

- [qt6-base](https://archlinux.org/packages/extra/x86_64/qt6-base/)
- [qt6-declarative](https://archlinux.org/packages/extra/x86_64/qt6-declarative/)
- [qt6-tools](https://archlinux.org/packages/extra/x86_64/qt6-tools/)

### macOS

nothing

### Windows

idk
