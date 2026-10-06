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

Home shows one card per `apps.list` entry. Controller input arrives as `input_nav {action, phase}`
events, and the keyboard maps onto the same `NavAction`s (arrows = directions, Enter = accept,
Escape = back), so `HomeScreen._nav` is the only action layer. `press` and `repeat` move focus
(the daemon does the key repeat); `release` never acts. `accept` calls `apps.launch {id}` for the
focused card, on `press` only; a failure (2001, 2002, not connected) shows a snackbar. Cards of
running apps carry a "Running" mark, refreshed through `apps.running` on connect and on
`app_started`, `app_exited` and `focus_changed`. `home_pressed` resets focus to the first card.
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
- `test/integration/` runs the real `hinteros-session` binary: `nix build .#checks.x86_64-linux.integration`.
  It starts the daemon with `--no-gamescope --no-inputplumber` and a temp config of two command
  apps, and covers the 0.2 handshake, `apps.list`, `apps.launch` (configured app, unknown app,
  spawn failure), `apps.running`, `app_started` and `app_exited`.
  It is a separate check and is skipped by plain `flutter test` unless `HINTEROS_SESSION_BIN`
  points at the binary, e.g. `HINTEROS_SESSION_BIN=$(nix build ../hinteros-daemon#hinteros-session --no-link --print-out-paths)/bin/hinteros-session flutter test test/integration`.
