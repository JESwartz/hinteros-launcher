# HinterOS Launcher

The Flutter UI that runs as the home app in the gamescope session: Home, Games, Apps, Settings
(Server in phase 2). It talks to the daemon over a Unix socket and contains no system logic.

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

By default the app runs as a console home app: fullscreen, undecorated (no title bar or close
button) and with a hidden mouse cursor. Pass `--windowed` (or set `HINTEROS_WINDOWED=1`) for a
normal decorated 1280x720 window during desktop development, e.g.
`./result/bin/hinteros-launcher --windowed`.

After changing `pubspec.yaml`, run `flutter pub get` and commit `pubspec.lock`; the Nix build reads it directly.

## Daemon API

The launcher talks to `hinteros-session` over a Unix socket (JSON-RPC 2.0, one message per line;
rules in `hinteros-docs/design/api.md`). The socket is `$HINTEROS_SESSION_SOCKET`, else
`$XDG_RUNTIME_DIR/hinteros/session.sock`. If the daemon is missing or speaks another API version,
the home screen says so and the client keeps retrying with backoff.

| Path | What |
|---|---|
| `schema/session-api.json` | Vendored copy of the daemon's schema (source of truth lives in `hinteros-daemon`) |
| `tool/gen_api.dart` | Generator: schema to `lib/src/api/generated.dart` (models, typed method stubs, sealed event class, error codes) |
| `lib/src/api/generated.dart` | Generated, committed. Do not edit |
| `lib/src/api/client.dart` | `DaemonClient`: handshake, request correlation, events, subscribe, reconnect |
| `lib/src/api/mock.dart` | `MockDaemon`: in-process fake with the same interface |

### Mock daemon

`--mock` (or `HINTEROS_MOCK=1`) swaps the socket for the in-process mock: a fake app list that
behaves like the 0.2 daemon (`apps.launch` starts an app and focuses it, `apps.running`,
`apps.focus`, and the `app_started`, `app_exited`, `focus_changed` events; a `command` launch of
`does-not-exist` fails with 2002). No daemon needed for desktop work. Dev keys, all going through
the mock's event stream:

| Key | Does |
|---|---|
| Home | `home_pressed` (the launcher takes focus back first) |
| A / D / W / S, Space, Q | `input_nav` left / right / up / down, accept, back (press, then release) |
| F2 | the last started app exits |

While an app has focus the mock sends no `input_nav`, like the daemon. Arrow keys, Enter and
Escape work in every mode and are the same actions as `input_nav` (see below).


```
flutter run -d linux --dart-entrypoint-args=--mock
./result/bin/hinteros-launcher --mock --windowed
```

### Launching and input

Controller input arrives as `input_nav {action, phase}` events; the keyboard maps onto the same
`NavAction`s (arrows = directions, Enter = accept, Escape = back, PageUp/PageDown = L1/R1), and
`NavController.dispatch` (see "Navigation rules") is the only action layer. `press` and `repeat`
move focus (the daemon does the key repeat); `release` never acts. `accept` calls `apps.launch {id}`
for the focused card, on `press` only; a failure (2001, 2002, not connected) shows a snackbar.
Cards of running apps carry a "Running" mark, refreshed through `apps.running` on connect and on
`app_started`, `app_exited` and `focus_changed`. `home_pressed` goes to Home. Other actions are
ignored, as the schema requires of clients.

### Regenerating and updating the schema

```
dart tool/gen_api.dart            # regenerate lib/src/api/generated.dart from schema/session-api.json
dart tool/gen_api.dart --check    # exit 1 if it is stale (also a flake check)
nix flake update hinteros-daemon  # bump the daemon input to its latest
nix run .#update-schema           # copy its schema into schema/ and regenerate; commit the result
```

`nix flake check` fails (`schema-vendored`) while `schema/session-api.json` differs from the
schema in the pinned `hinteros-daemon` input, and fails (`generated`) while the generated file
is stale. After re-vendoring, the mock and contract test must cover any new methods. The generator
handles `$ref` unions (`oneOf [X, null]` becomes `X?`), required-but-nullable fields (sent as
explicit `null`) and string enums with an `unknown` fallback; `oneOf` on a params object (as in
`apps.launch`) is not modelled, so all its fields are optional in Dart and the daemon validates.

### Tests

- `test/api/contract_test.dart` replays every method and event example of the schema through the
  mock and validates all output against the schema with the `json_schema` package.
- `test/api/client_test.dart` runs `DaemonClient` against a scripted fake server on a real socket.
- `test/integration/` runs the real `hinteros-session` binary: `nix build .#checks.x86_64-linux.integration`.
  It starts the daemon with `--no-gamescope --no-inputplumber` and a temp config of two command
  apps, and covers the 0.2 handshake, `apps.list`, `apps.launch` (configured app, unknown app,
  spawn failure), `apps.running`, `app_started` and `app_exited`.
  It is a separate check and is skipped by plain `flutter test` unless `HINTEROS_SESSION_BIN`
  points at the binary, e.g. `HINTEROS_SESSION_BIN=$(nix build ../hinteros-daemon#hinteros-session --no-link --print-out-paths)/bin/hinteros-session flutter test test/integration`.

## UI

### Layout: top tab bar

Sections are Home, Games, Apps and Settings in a **top tab bar** (wordmark left, clock right). The
Server tab (phase 2) only appears with `--server` or `HINTEROS_SERVER=1`. A top bar was chosen over
a side rail for a TV at couch distance: content (card rows, a 6-column game grid, list-detail
Settings) gets the full 1920 px width, the whole bar sits in one glance line with the first row
instead of a column at the screen edge (where overscan and the far-left of a wide TV hurt), and
Up from the first row to the bar and Left/Right between tabs is the same grammar as the rest of the
UI. Focus on a tab selects its section (like console UIs); Down enters the section where you left it.

- **Home:** Continue (running apps, then this session's recent launches; hidden when empty), Apps,
  Games (first 12), in one vertically scrolling page.
- **Games:** grid of 2:3 covers with the title underneath; placeholder art (hue from the title, big
  initial, drawn in code, no asset or network) when there is no image.
- **Apps:** grid of 16:9 tiles.
- **Settings:** list left, options of the highlighted entry right (list-detail). Local settings:
  text size (100/120/140/160%), high contrast, focus marker (ring/glow/bar), reduce motion.
  "System" is a placeholder (M5).

The layout is designed in 1920x1080 logical pixels. A 4K screen under native Wayland runs it at
devicePixelRatio 2, so the same layout; any other size (720p TV, desktop window) is scaled uniformly
to fit (`lib/src/app.dart`).

### Navigation rules

Code: `lib/src/nav/` (pure rules in `nav_model.dart`, binding to Flutter `FocusNode`s in
`nav_controller.dart`); screens only declare `NavRegion`s and put `NavFocusable` items in them.

- Left/Right move within a row and **stop at its ends**; they never change row. On the tab bar
  they wrap.
- Up/Down go to the neighbouring non-empty row. On Home **each row remembers its column**; a row
  not visited yet is entered at the current column, clamped. In grids the wanted column is
  **sticky** across a short last row (down then up returns to where you were).
- Up from the top row goes to the tab bar; Down from the bottom row stays.
- First item focused on start (as soon as Home has items).
- **Back** goes up one level: settings detail to its list, section content (or the tab bar) to the
  Home tab with Home focus restored; on Home it does nothing.
- **Home button** always goes to the Home tab with the first card focused and column memory reset.
- PageLeft/PageRight (L1/R1) switch tabs from anywhere.
- Tested in `test/nav/` (rules, and end to end through the shell).

### Theme and accessibility

`lib/src/theme/hinter_theme.dart`: `HinterTokens` (colours, 8 px spacing grid, radii, type scale
from 24 px caption to 56 px headline, durations), provided by `HinterTheme.of(context)`. Focus is
shown by scale-up plus a marker that differs in **shape and thickness**, not only colour: a thick
white ring with a dark gap (default), a thin ring with a glow, or a bar under the card. High contrast
is black/white with a yellow focus marker. Text scale 1.0 to 1.6 applies through `MediaQuery`
(layouts make room; the wordmark yields above 1.3x). Reduce motion removes scale and scroll
animations.

### Settings file

`$XDG_CONFIG_HOME/hinteros/launcher.json` (default `~/.config/hinteros/launcher.json`), written
atomically on every change; a missing or corrupt file means defaults, unknown or invalid values fall
back per field:

```json
{ "version": 1, "text_scale": 1.0, "high_contrast": false, "focus_style": "ring", "reduce_motion": false }
```

### Data access and API 0.3

The UI reads through `AppsRepository` and `GamesRepository` (`lib/src/data/`), combined in
`LauncherData`. Games currently use temporary sources marked `TODO(0.3)`: `AppsBackedGamesRepository`
(`apps.list` entries whose id starts with `steam`) against the daemon, `MockGamesRepository` with
`--mock`. Waiting on 0.3: `games.list` with artwork paths, `apps.close` (a Close action on Continue
cards), games-changed events, launching games by id.

### Fonts

Atkinson Hyperlegible Regular and Bold (`assets/fonts/`), SIL Open Font License 1.1, licence text in
`assets/fonts/OFL.txt` (copied from the `atkinson-hyperlegible` package in nixpkgs). Declared in
`pubspec.yaml` as family `AtkinsonHyperlegible`.

### Golden tests

`test/golden/screens_test.dart` captures every screen at 1920x1080 and Home and Games at 3840x2160
(1920x1080 logical at DPR 2), plus Home in high contrast at 1.6x text, into
`test/golden/goldens/`. Tests load the bundled font explicitly (`flutter_test_config.dart`, no
Ahem), use a fixed clock, the in-process mock, locally drawn placeholder art and settle animations.
The comparator allows 0.05% differing pixels.

```
nix run .#update-goldens   # renders them in the Nix sandbox (same environment as the check), copies them in
git diff --stat test/golden && git add test/golden   # look at the images, commit them with the code
```

`nix flake check` (check `test`) runs `flutter test` including the golden comparison in the sandbox.
Goldens are generated on this machine, the future CI runner host; moving the runner to other
hardware means regenerating all of them in one reviewed commit (TESTING.md). Plain `flutter test`
in `nix develop` also compares them, and may differ slightly from the sandbox; use
`update-goldens` rather than `flutter test --update-goldens` when committing.
