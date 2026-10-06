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

The same binary is also the on-screen keyboard: `./result/bin/hinteros-osk` (see "On-screen keyboard").

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
| `lib/src/api/mock.dart` | `MockDaemon`: in-process fake with the same interface (all 0.5 methods and events) |
| `lib/src/osk/` | The on-screen keyboard: `OskBackend` (+ mock), layouts, state, UI |
| `tool/gen_mock_art.dart` | Draws the placeholder cover art in `test/fixtures/art/` (committed; no network, no third-party pictures) |
| `tool/gen_mock_icons.dart` | Draws the generic placeholder app icons in `test/fixtures/icons/` (plain shapes, PNG and one SVG; no logos, no network) |
| `lib/src/data/app_icons.dart` | `AppIconCache`: loads, decodes (PNG, SVG via `flutter_svg`) and remembers app icons, computes their dominant colour |

### Mock daemon

`--mock` (or `HINTEROS_MOCK=1`) swaps the socket for the in-process mock, which behaves like the
0.5 daemon: HinterOS's default apps (built-in Steam, Jellyfin, YouTube, Crunchyroll, Firefox,
Plex), a fake Steam library of 14 games in every install state (`games.list`, sorted by name),
`apps.launch` (by id, command or `steam://rungameid/<appid>`), `apps.running`, `apps.focus`,
`apps.close` (then `app_exited` with reason `closed`), `steam.attention` / `steam.focus`, and the
`app_started`, `app_exited`, `focus_changed`, `games_changed`, `steam_attention` and `osk_visibility` events; a
`command` launch of `does-not-exist` fails with 2002. 0.5: the apps have generic local icons (`test/fixtures/icons`, found from the repo root or `HINTEROS_MOCK_ICONS=<dir>`), except YouTube and Plex, whose icons arrive later (F6, `apps_changed`); `MockDaemon.setAppIcon` does the same in tests. 0.4: `osk.show` / `osk.hide` (event only on a change; Home and a focus change hide it; `oskEnabled = false` gives 2005), `keys.type` (printable ASCII types, anything else comes back as `untypeable`), `keys.key`, `keys.action` (all logged in `MockDaemon.keyLog`; `keyboardAvailable = false` gives 2004), and, while the keyboard is visible, `input_nav` only to a mock constructed with `clientName: 'hinteros-osk'`. No daemon needed for desktop work. Dev keys,
all going through the mock's event stream:

| Key | Does |
|---|---|
| Home | `home_pressed` (the launcher takes focus back first) |
| A / D / W / S, Space, Q, E | `input_nav` left / right / up / down, accept, back, context (press, then release) |
| F2 | the last started app exits |
| F3 / F4 | Steam shows a "Steam Guard" dialog (`steam_attention`) / it goes away |
| F5 | a game finishes its update (or, if all are installed, the first needs one): `games_changed` |
| F6 | an app icon arrives (YouTube, then Plex): `apps_changed` |

While an app has focus the mock sends no `input_nav`, like the daemon. Arrow keys, Enter and
Escape work in every mode and are the same actions as `input_nav` (see below).


```
flutter run -d linux --dart-entrypoint-args=--mock
./result/bin/hinteros-launcher --mock --windowed
```

### App icons

Every app tile shows the app's own icon; the letter tile is only the fallback. The daemon ships no
logos: `apps.list`'s `icon` is an absolute path to a local image (PNG, SVG, ICO, JPEG, WebP) that
it resolves at runtime from the app's desktop file and the icon themes, or fetches for web apps.
It may appear later or change, and the daemon then sends `apps_changed`; the launcher subscribes,
queries `apps.list` again, and every tile picks up the new file (the same path with new content
too: the files are compared on every refresh).

`AppIconCache` (`lib/src/data/app_icons.dart`) reads the file once and decodes it to a raster
image of at most 512 px on the long side. An SVG is parsed with `flutter_svg` and drawn once into
the same kind of image, so the tiles paint one cheap `RawImage` either way and nothing is
re-rasterised per frame. Along the way it samples about 4000 pixels for the icon's dominant colour
(saturated pixels count more than greys) and mean luminance; no `palette_generator`, and nothing
runs per frame. A file that is missing or cannot be decoded gives no icon, and the tile falls back
to the letter (while the first load is pending the tile shows its gradient without the letter, so
there is no flash).

**Tile** (`AppTile`, Home Continue/Apps and the Apps grid): 16:9 card; a backdrop that is a dark
tint of the icon's colour (a vertical gradient with a soft glow behind the icon); the icon centred
and contained (never cropped, at most 64% of the tile height) on top; the name over a dark scrim at
the bottom, white, one line. An icon so dark that it would vanish (mean luminance under 0.2)
gets a light neutral backdrop instead. The Running mark stays at the top left and scales down to at
most half the tile width; the icon sits in the room to its right when it fits there at full size,
else below it, so mark, icon and name never overlap at 1.0 to 1.6x text. High contrast keeps the
outline. A running game keeps its header art as the tile; the close-confirm dialog shows the app's
icon next to the title. Goldens: `home_1080p`, `apps_1080p`, the 1.6x and high-contrast variants,
`apps_broken_icons_1080p` (letter fallback for a broken and a missing file) and
`close_confirm_*`.

### Try it on the desktop with the real daemon and a controller

The daemon has a development preview that runs `hinteros-session` without gamescope or
InputPlumber, with your real Steam library and a sample app list, and reads an Xbox controller
straight from evdev. In one terminal:

```
nix run git+https://justsomeshed.com/JSwartz/HinterOS/hinteros-daemon.git#desktop-preview
```

It prints "hinteros-session is listening on:" and the socket path (in a temporary
directory, such as `/run/user/1000/hinteros-preview.XXXXXX/session.sock`), and keeps running;
stop it with Ctrl+C.
In a second terminal, in this repo:

```
HINTEROS_SESSION_SOCKET=<printed path> nix run . -- --windowed
```

The controller works as in the session: D-pad or left stick moves, A launches, B goes back, Y closes
a running app, X is secondary, bumpers switch tabs, the Xbox button is Home. Reading the pad needs
access to the device (a pad on your seat has it through logind, otherwise join the `input` group).
App icons are resolved from your desktop's icon themes and `.desktop` files, and web apps' icons
arrive a moment after start (`apps_changed`), so the tiles fill in live.

Launching an app or game from the launcher starts it for real on your desktop: Steam games go
through your running Steam client and apps are ordinary processes. Home returns to the launcher
but does not hide their windows, and nothing is sandboxed. Keyboard-profile apps and `keys.*` are
off in the preview (no uinput), so TV web apps get no controller-to-keys mapping. See the daemon's
README, "Desktop preview".

### Launching and input

Controller input arrives as `input_nav {action, phase}` events; the keyboard maps onto the same
`NavAction`s (arrows = directions, Enter = accept, Escape = back, PageUp/PageDown = L1/R1), and
`NavController.dispatch` (see "Navigation rules") is the only action layer. `press` and `repeat`
move focus (the daemon does the key repeat); `release` never acts. `accept` launches the focused
card, on `press` only: `apps.launch {id}` for an app, `apps.launch {url:
"steam://rungameid/<appid>"}` for a game (it then runs as `steam-<appid>`); a failure (2001, 2002,
not connected) shows a snackbar. Cards of running apps and games carry a "Running" mark, refreshed
through `apps.running` on connect and on `app_started`, `app_exited` and `focus_changed`; running
games show on the Continue row with their Steam header art. `home_pressed` goes to Home.

**Close:** the `context` action (gamepad Y / Triangle; keyboard Y or the menu key; `E` with `--mock`)
on a running app or game (Continue, Apps, Games) opens a confirm dialog "Close <name>?" over the
screen. It takes all input until answered: Cancel is focused first, Left/Right move, Accept
chooses, Back cancels, the Home button dismisses it, and it goes away by itself if the app ends
meanwhile. Confirming calls `apps.close {id}`; `app_exited` (reason `closed`) updates Continue (the
card stays as a plain recent launch for apps, and disappears for games). For Steam the dialog says
that only Big Picture closes, as the daemon never kills the client.

**Steam attention:** while `steam_attention` lists windows (also queried with `steam.attention` on
every connect), a non-modal banner "Steam needs your attention: <title>" ("and N more" for several)
sits between the tab bar and the content, with an "Open Steam" button that calls `steam.focus`
(error 2003 just refreshes the banner). It is part of the vertical focus order (tab bar, banner,
content); `secondary` (gamepad X, keyboard X) triggers the same action from anywhere. An empty list
clears it, and focus returns to the content if it was on the banner.

Other actions are ignored, as the schema requires of clients.

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
- `test/app_icons_test.dart` covers the icon cache (PNG, SVG, dominant colour, broken files, a changed file behind the same path) and the tiles (icon vs letter, an icon arriving through `apps_changed`).
- `test/api03_ui_test.dart` covers the 0.3 behaviour through the UI: install-state badges (also that
  they fit narrow covers at text 1.0 to 1.6x), launching and explaining games, Close with its
  confirm step, the attention banner.
- `test/osk/` drives the on-screen keyboard with the mock backend: layout, D-pad navigation, shift,
  pages, and the exact backend calls for typing `P@ss-w0rd!` with D-pad presses only.
- `test/integration/` runs the real `hinteros-session` binary: `nix build .#checks.x86_64-linux.integration`.
  It starts the daemon with `--no-gamescope --no-inputplumber`, a temp config of two command apps
  and `--steam-dir` pointing at the daemon repo's fake Steam home, and covers the 0.5 handshake (an app with an explicit `icon` path gets it back in `apps.list`),
  `apps.list` (built-in `steam` first), `apps.launch` (configured app, unknown app, spawn failure),
  `apps.running`, `app_started` / `app_exited`, `apps.close` (reason `closed`, 2001 when not
  running), `games.list` against the fixture (names, install state, artwork files that exist),
  `steam.attention` and `steam.focus` (2003) without Steam windows.
  The keyboard part runs the real `DaemonOskBackend` as client `hinteros-osk` with `--fake-keyboard <file>`
  and `[osk] command = []` (no keyboard process): `osk.show` / `osk.hide` reach every client as
  `osk_visibility`, `keys.type`, `keys.key` and `keys.action` write the expected key events
  (`down 30`, `up 30`...) into the fake keyboard log, `untypeable` for a character without a key,
  2004 without a virtual keyboard (`--no-uinput`), 2005 with `[osk] enable = false`. What it cannot
  cover is `input_nav` routing to the `hinteros-osk` connection: that needs a fake InputPlumber on a
  D-Bus, which the daemon's own tests have (the launcher's mock and tests cover the client side).
  It is a separate check and is skipped by plain `flutter test` unless `HINTEROS_SESSION_BIN`
  points at the binary (and `HINTEROS_STEAM_FIXTURE` at `crates/hinteros-session/tests/fixtures/steam-home`
  for the games test), e.g.
  `HINTEROS_SESSION_BIN=$(nix build ../hinteros-daemon#hinteros-session --no-link --print-out-paths)/bin/hinteros-session HINTEROS_STEAM_FIXTURE=../hinteros-daemon/crates/hinteros-session/tests/fixtures/steam-home flutter test test/integration`.

## On-screen keyboard

`hinteros-osk` is a second app in the same binary and the same Flutter build: the launcher started
with `--osk` (entry `lib/osk_main.dart`, `runOsk`). **Why one binary:** a second entrypoint would
mean a second `buildFlutterApplication` (another AOT compile and another copy of the Flutter
engine, 17 MB) for what is the same runner, theme and nav code. The GTK runner switches on
`--osk` (or `HINTEROS_OSK=1`), and the package ships `bin/hinteros-osk`, a two-line wrapper that
execs `hinteros-launcher --osk`. Nix: `packages.hinteros-launcher` contains both programs;
`packages.hinteros-osk` (also `overlays.default`'s `hinteros-osk`) is just `bin/hinteros-osk`
linked to it, for a system that wants only the keyboard.

**Window** (spike 5): X11 `WM_CLASS` is `hinteros-osk` for both name and class; the window has an
RGBA (32-bit ARGB) visual, `app-paintable`, a Flutter clear colour of `#00000000`, no decoration,
never takes focus, covers the whole output and sets `GAMESCOPE_EXTERNAL_OVERLAY=1` on itself. The
Flutter side paints only the keyboard panel (bottom 40% of the height, solid, rounded top corners);
everything else is transparent. Showing and hiding is the daemon's job (`_NET_WM_WINDOW_OPACITY`);
the process stays resident, and on `osk_visibility {visible: true}` it re-reads `launcher.json` (text
size, contrast, focus marker) and focuses `q`. A 4K screen at devicePixelRatio 1 gets the same
keyboard scaled by height / 1080. Checked here under Xvfb: depth-32 window, class and atom set;
alpha through a real compositor and gamescope is on the spike's hardware checklist.

Run it on the desktop: `flutter run -d linux -t lib/osk_main.dart --dart-entrypoint-args=--osk,--mock,--windowed`
or `./result/bin/hinteros-osk --mock --windowed`. `--mock` prints what it would send to the daemon;
the arrow keys, Enter, Escape/Backspace, Y and X stand in for the pad.

**Backend:** the UI only talks to `OskBackend` (`lib/src/osk/osk_backend.dart`): `type(text)`
(`keys.type`; returns the `untypeable` characters), `action(backspace|enter|tab)` (`keys.action`),
`key(key, modifiers)` (`keys.key`, unused so far), `hide()` (`osk.hide`), plus the streams `nav`
(`input_nav`) and `visibility` (`osk_visibility`). `MockOskBackend` records every call
(`type:P`, `action:backspace`, `hide`...). `DaemonOskBackend` is the real one: it connects to
`$HINTEROS_SESSION_SOCKET` (else the default socket) with the hello client name `hinteros-osk`,
which is what makes the daemon send it `input_nav` while the keyboard is visible (and the launcher,
client `hinteros-launcher`, not; it also drops any `input_nav` that arrives while `osk_visibility`
says the keyboard is up). `osk_visibility {visible: false}` resets the keyboard (letters, shift
off, empty preview). Errors show in the strip for a few seconds: 2004 `keyboard_unavailable` as
"No keyboard available", and characters that `keys.type` reports as `untypeable` ("Cannot type:
é"; with the preview masked only their number, as the characters may be secret). The launcher has
no button that summons the keyboard (the daemon does it: hold Guide and press Y), so it never calls
`osk.show`.

**Controls** (the nav layer's conventions: presses and repeats move, only a press acts):

| Input | Does |
|---|---|
| D-pad | Moves between keys. Left/right wrap within a row; up/down go to the key above or below (rows of unequal keys use `NavRow.spans`, so the wide Space bar is under several letters) |
| accept (A) | Types the key |
| back (B) | Backspace, also while held (repeat) |
| context (Y) | Shift: one-shot, again for caps lock, again off. On the symbol pages: switches between symbols 1 and 2 |
| secondary (X) | Space |
| L1 / R1 | Letters / symbols page |
| the Done key | `osk.hide`; the keyboard also resets (letters, shift off, empty preview) |

Shift was chosen for `context` rather than the page toggle because it is needed mid-word, while a
page change is one key away and has L1/R1. Pages: letters (digits row, `'` and `.`), symbols 1,
symbols 2 (`[ ] { }` and the backtick); together they cover every printable ASCII character. The
strip above the keys is a preview of what was typed since opening (Backspace removes). **It is
masked by default** (a password must not appear on the TV): dots, with the newest character readable
for about a second, like a phone password field. Settings > "Show typed text on the on-screen
keyboard" (default off) shows it in plain text; the keyboard reads `launcher.json` again every time
it opens. The preview is cleared on hide. Characters go out with `keys.type` (the daemon picks uinput or the
gamescope input method), Space included; the keyboard has no text field of its own.

## UI

### Layout: top tab bar

Sections are Home, Games, Apps and Settings in a **top tab bar** (wordmark left, clock right). The
Server tab (phase 2) only appears with `--server` or `HINTEROS_SERVER=1`. A top bar was chosen over
a side rail for a TV at couch distance: content (card rows, a 6-column game grid, list-detail
Settings) gets the full 1920 px width, the whole bar sits in one glance line with the first row
instead of a column at the screen edge (where overscan and the far-left of a wide TV hurt), and
Up from the first row to the bar and Left/Right between tabs is the same grammar as the rest of the
UI. Focus on a tab selects its section (like console UIs); Down enters the section where you left it.

- **Home:** Continue (running apps and games, then this session's recent launches; hidden when
  empty), Apps, Games (first 12), in one vertically scrolling page.
- **Games:** the Steam library from `games.list` as a grid of 2:3 covers (`artwork.portrait`, loaded
  with `Image.file`) with the title underneath. Without art, or if the file cannot be read, a
  placeholder (hue from the title, big initial, drawn in code) shows instead. Games that are not
  `installed` are dimmed and carry a badge ("Update required", "Updating", "Installing",
  "Removing"; an unknown state counts as Updating; on narrow covers "Update required" breaks into
  two lines and the badge scales down as a whole, so no word is cut off); accepting one explains why it cannot start
  instead of launching it. The list is refreshed on connect and on `games_changed`.
- **Apps:** grid of 16:9 tiles. The built-in Steam entry (Big Picture) comes first, as the daemon
  lists it.
- Scrolling content (Home, the grids) dissolves into the background under the tab bar instead of
  being cut off; grids have a fixed section header and scroll by whole rows, so a focused row is
  never half hidden. App tiles lay out Running mark, initial and name in a column: they cannot
  overlap at any text size (the initial gives way when there is no room).
- **Settings:** list left, options of the highlighted entry right (list-detail). Local settings:
  text size (100/120/140/160%), high contrast, focus marker (ring/glow/bar), reduce motion.
  "Show typed text on the on-screen keyboard" (privacy; off = the keyboard's preview shows dots).
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
- Rows of unequal items (the on-screen keyboard) give `NavRow` per-item `spans`; up/down then go to
  the item under the position you aimed for, kept across rows.
- First item focused on start (as soon as Home has items).
- **Back** goes up one level: settings detail to its list, section content (or the tab bar) to the
  Home tab with Home focus restored; on Home it does nothing.
- **Home button** always goes to the Home tab with the first item of the first non-empty row
  focused (Continue if something runs, else Apps) and column memory reset, also when another tab
  was showing.
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
{ "version": 1, "text_scale": 1.0, "high_contrast": false, "focus_style": "ring", "reduce_motion": false, "osk_show_typed": false }
```

### Data access

The UI reads through `AppsRepository` (apps, running, launch, close, Steam attention and focus) and
`GamesRepository` (`games.list`, launch by Steam URL) in `lib/src/data/`, combined in
`LauncherData`, which owns all daemon traffic and re-queries on connect and on events (the daemon
does not replay them). The client speaks session API 0.5 (during 0.x the minor must match).

### Fonts

Atkinson Hyperlegible Regular and Bold (`assets/fonts/`), SIL Open Font License 1.1, licence text in
`assets/fonts/OFL.txt` (copied from the `atkinson-hyperlegible` package in nixpkgs). Declared in
`pubspec.yaml` as family `AtkinsonHyperlegible`.

### Golden tests

`test/golden/screens_test.dart` captures every screen at 1920x1080 and Home and Games at 3840x2160
(1920x1080 logical at DPR 2), plus Home in high contrast at 1.6x text, into
`test/golden/goldens/`. `test/golden/osk_test.dart` renders the on-screen keyboard at 1920x1080 over
a checkerboard (so the transparent area and the panel's rounded corners show): letters, symbols with dots in the preview,
the masked preview with its newest character readable, the preview with the setting on, high contrast at 1.6x with caps lock, and the bar focus marker with one-shot shift
(`osk_*_1080p.png`). `home_games_row_text160_1080p.png` shows the install badges at 1.6x. Further goldens cover the Games grid (unscrolled, scrolled to the last row, with artwork), Home with a
running game, the attention banner, the close confirm and the app tiles at text 1.3x/1.6x (also high
contrast). Tests load the bundled font explicitly (`flutter_test_config.dart`, no
Ahem), use a fixed clock, the in-process mock, the committed placeholder art
(`test/fixtures/art/`, decoded into the image cache before the first frame) and settle animations.
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
