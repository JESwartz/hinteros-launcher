# HinterOS Launcher

The Flutter UI that runs as the home app in the gamescope session: Home, Games, Apps,
Server and Settings. It talks to the daemon over a Unix socket and contains no system logic.

Part of [HinterOS](https://justsomeshed.com/JSwartz/HinterOS/hinteros). Licensed under GPL-3.0-only, see [LICENSE](LICENSE).

## Develop

```
nix develop                   # Flutter, gamescope, nixfmt; installs git hooks
flutter run -d linux          # desktop window; arrow keys stand in for the D-pad
flutter test                  # widget tests
gamescope --steam -- flutter run -d linux   # nested gamescope, closer to the real session
nix build && ./result/bin/hinteros-launcher
nix flake check               # nixfmt, dart format, dart analyze, flutter test, package build
```

Pass `--fps` (or set `HINTEROS_FPS=1`) to show a frame-rate overlay (fps and worst frame time),
e.g. `./result/bin/hinteros-launcher --fps`, or `flutter run -d linux --dart-entrypoint-args=--fps`.

After changing `pubspec.yaml`, run `flutter pub get` and commit `pubspec.lock`; the Nix build reads it directly.
