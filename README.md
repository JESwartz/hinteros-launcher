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

**After a system switch** (`lib/src/system/home_relaunch.dart`): gamescope runs the launcher
through the session's home loop (hinteros `nixos/modules/session.nix`), which sets
`HINTEROS_HOME_LINK` (`/run/current-system/hinteros-console/home`, the current system's
launcher), `HINTEROS_HOME_EXE` (the resolved launcher it started) and `HINTEROS_HOME_RELAUNCH`
(75). When
the link now points to a different launcher and the daemon refuses this one's API version, or
the daemon connection comes back after a drop (the switch restarted the daemon), the launcher
exits with 75 and the loop starts the new one in the same gamescope session. With the same
launcher installed, or without those variables (`--mock`, development), it stays and retries.

| Path | What |
|---|---|
| `schema/session-api.json` | Vendored copy of the daemon's schema (source of truth lives in `hinteros-daemon`) |
| `tool/gen_api.dart` | Generator: schema to `lib/src/api/generated.dart` (models, typed method stubs, sealed event class, error codes) |
| `lib/src/api/generated.dart` | Generated, committed. Do not edit |
| `lib/src/api/client.dart` | `DaemonClient`: handshake, request correlation, events, subscribe, reconnect |
| `lib/src/api/mock.dart` | `MockDaemon`: in-process fake with the same interface (all 0.11 methods and events: the relayed `system.*` API, the runtime settings, the admin password prompt, `session.restart` and the Store) |
| `lib/src/osk/` | The on-screen keyboard: `OskBackend` (+ mock), layouts, state, UI |
| `tool/gen_mock_art.dart` | Draws the placeholder cover art in `test/fixtures/art/` (committed; no network, no third-party pictures) |
| `tool/gen_mock_icons.dart` | Draws the generic placeholder app icons in `test/fixtures/icons/` (plain shapes, PNG and one SVG; no logos, no network) |
| `lib/src/data/app_icons.dart` | `AppIconCache`: loads, decodes (PNG, SVG via `flutter_svg`) and remembers app icons, computes their dominant colour |

### Mock daemon

`--mock` (or `HINTEROS_MOCK=1`) swaps the socket for the in-process mock, which behaves like the
0.9 daemon: HinterOS's default apps (built-in Steam, Jellyfin, YouTube, Crunchyroll, Firefox,
Plex), a fake Steam library of 14 games in every install state (`games.list`, sorted by name),
`apps.launch` (by id, command or `steam://rungameid/<appid>`), `apps.running`, `apps.focus`,
`apps.close` (then `app_exited` with reason `closed`), `steam.attention` / `steam.focus`, and the
`app_started`, `app_exited`, `focus_changed`, `games_changed`, `steam_attention` and `osk_visibility` events; a
`command` launch of `does-not-exist` fails with 2002. 0.5: the apps have generic local icons (`test/fixtures/icons`, found from the repo root or `HINTEROS_MOCK_ICONS=<dir>`), except YouTube and Plex, whose icons arrive later (F6, `apps_changed`); `MockDaemon.setAppIcon` does the same in tests. 0.4: `osk.show` / `osk.hide` (event only on a change; Home and a focus change hide it; `oskEnabled = false` gives 2005), `keys.type` (printable ASCII types, anything else comes back as `untypeable`), `keys.key`, `keys.action` (all logged in `MockDaemon.keyLog`; `keyboardAvailable = false` gives 2004), and, while the keyboard is visible, `input_nav` only to a mock constructed with `clientName: 'hinteros-osk'`. 0.6: the relayed system service (`MockDaemon.system`, `lib/src/api/mock_system_relay.dart`): `system.info`, `settings.get` / `set`, `ssh.set` (to on it waits for the admin password, see 0.8 below; `system.adminAuthorized = true` skips that), `generations.list`, `rebuild`, `hardware.redetect`, `rollback`, `update.check` (a job, 60 s cache), `update.apply` (only the last checked rev), `channel.set` / `base.set` (`needs_acknowledgement` for downgrades), `jobs.get` / `list` / `cancel`, and the `job_started` / `job_progress` / `job_finished` events. One mutating job at a time (`job_busy`); jobs step through their stages by themselves with `systemStepDelay`, or a test drives them (`progressJob`, `finishJob`); `unavailable = SystemUnavailableDataReason.down` gives `system_unavailable`; `failNext` injects any error (rate limit, low memory...). 0.7: the runtime settings (`MockDaemon.runtime`, `lib/src/api/mock_runtime.dart`): `network.status`, `wifi.scan` / `list` / `connect` / `disconnect` / `forget` / `enable` (a stored network joins without a password, a wrong password is `wrong_password` and stores nothing, WEP and 802.1X are refused, `keyChanged` makes a stored password stale), `bluetooth.*` (devices appear on the first scan; a controller pairs without a prompt, a `confirm` device sends `bluetooth_confirm` and waits for `bluetooth.confirm`, a `display` device waits for `finishDisplayPairing()`), `audio.*` (every call returns the state and sends `audio_changed`), `display.modes` / `set_mode` / `keep` / `revert` (the replaced mode is remembered until kept or reverted; `displayCanSet`, `displayIgnoresMode`), `power.*` (`inhibited = true` gives `power_inhibited`, `powerCapabilities`, `notAuthorized`), and `network_changed`, `wifi_list_changed`, `bluetooth_changed`, `bluetooth_confirm`, `audio_changed` after every change. `runtime.setUnavailable('bluez')` (also `networkmanager`, `audio`, `display`, `logind`) makes one service answer `unavailable` and leaves the rest working. 0.8: the admin password agent (`MockDaemon.auth`, `lib/src/api/mock_auth.dart`): `system.ssh.set` to on waits like the real call, sends `authentication_requested` (to a mock named `hinteros-launcher` only) and ends with the job on `auth.respond` (3 tries, then `permission_denied`), with `authentication_required` on `auth.cancel` or when `auth.agentRegistered = false`; `auth.*` from another client is `not_authorized`; the answer to `auth.respond` comes before the waiting call's. `session.restart` (`sessionRestarts`, `sessionRestartAvailable = false` gives `unavailable {logind, not_greetd}`). `store.list` and `system.apps.install` / `remove` over a wire catalog (`lib/src/api/mock_store.dart`: the fixture in `test/fixtures/catalog` with absolute `terms.file` paths, plus RetroArch with its cores, a video player, Kodi (conflicts with Jellyfin) and a retired app): states `installing` / `removing` while the job runs, `store_changed` when an apps job starts and ends, `more_after_update` from the update check's `new_apps`, the service's checks (`state_conflict` for a stale revision, `not_available`, transitive depends, `app_conflict` both ways, `terms_required` per app, `insufficient_resources` from `freeDiskMib`, `app_conflict` when removing an app another needs). No daemon needed for desktop work. Dev keys,
all going through the mock's event stream:

| Key | Does |
|---|---|
| Home | `home_pressed` (the launcher takes focus back first) |
| A / D / W / S, Space, Q, E | `input_nav` left / right / up / down, accept, back, context (press, then release) |
| F2 | the last started app exits |
| F3 / F4 | Steam shows a "Steam Guard" dialog (`steam_attention`) / it goes away |
| F5 | a game finishes its update (or, if all are installed, the first needs one): `games_changed` |
| F6 | an app icon arrives (YouTube, then Plex): `apps_changed` |

While an app has focus the mock sends no `input_nav`, like the daemon. Arrow keys, Enter,
Escape and Backspace work in every mode and are the same actions as `input_nav` (see below).


```
flutter run -d linux --dart-entrypoint-args=--mock
./result/bin/hinteros-launcher --mock --windowed
```

### Session API 0.13: admin PIN for box-wide actions, guest wipe

- **Admin PIN** (`lib/src/ui/profiles/profile_ui.dart` `withBoxAdminPin`, `runAdminJob` in
  `lib/src/ui/system/common.dart`): installing an update (Settings > Updates "Update now", which
  the update banner leads to, and the security notice; every profile, the guest too), rollback,
  channel change and software base change send `admin_pin` (system API 0.5).
  The launcher asks first on the same admin-PIN pad as the other admin actions when
  `profiles.list` shows an admin profile with a PIN; a wrong PIN
  (`pin_required {pin: admin}`) stays on the pad, Back on the empty pad does nothing. With no PIN
  on the admin profile, or when `profiles.list` fails, the call goes without one, and a
  `pin_required {pin: admin}` answer still opens the pad; with no admin profile (first boot) the
  service's message is shown. A downgrade's second call (`acknowledge_downgrade`) reuses the PIN.
  `hardware.redetect` takes it too (`SystemRepository.redetectHardware`); no screen calls it yet.
- **Rollback**: a generation with `readds_features` says on the confirmation that the box turns
  the parts the apps need on again; the job page shows the `box` stage after the switch and,
  from `features_readded`, that they are on again. A failed box stage says the rollback is done.
- **End guest session** removes everything the guest did now (`session.end_guest` asks for
  `system.guest.end`, job kind `guest_end`), not at the next restart.
- **Mock**: the box-wide actions check the admin PIN (`MockProfileBox.checkBoxAdmin`,
  `MockProfileSession.checkBoxAdminPin`; `schema1` or an admin without a PIN needs none),
  `system.guest.end` (guest only), and `generations.list`'s generation 10 re-adds
  `graphics32`/`steam-devices`.

### Session API 0.12: profiles (M7)

Design: `hinteros-docs/design/profiles.md` and `apps.md`. The schema's profile parts are the
launcher's proposal until the daemon's M7 schema is vendored (see `m7/DECISIONS.md`).

- **Picker** (`--greeter`, `lib/src/greeter_main.dart`, `lib/src/ui/profiles/greeter_screen.dart`):
  the greeter session's launcher, against the greeter-mode daemon (`greeter.*`). Profile tiles,
  Guest, Add profile (name with the launcher's own keyboard, colour, PIN twice, "Lock this
  profile", then "Getting things ready" for the create job), Power. A locked profile opens the
  PIN pad: D-pad and A, B deletes (B on an empty pad goes back), digits and Enter on a keyboard,
  no auto-submit, "That PIN didn't match." and the backoff countdown. After a login greetd
  accepted, "Loading Sam…" (`profile_loading.dart`: avatar, name, spinner) until the picker
  exits; the console shows the same words on the VT (`hinteros-system pin splash`) and the
  session's launcher shows the page again on its first frames (name from
  `/run/hinteros/profiles-public.json` by `$USER`) until Home has its data (at most 15 s).
  `greeter.list.switch_to` (a pending switch whose fast path did not apply, e.g. a locked
  target): the picker goes straight to that profile's PIN pad, never showing the bare tiles
  first; B there shows the tiles. The tiles and their page (`picker_view.dart`) are shared with
  the in-session picker.
- **In a profile's session** (`lib/src/ui/profiles/session_profile.dart`): `profile.current`
  decides first-boot mode (`setup_required`: the wizard ends with "Create your profile",
  `system.profiles.setup_admin`), the one-time "Set your PIN" (`pin_set` false) and the sleep
  lock screen (`screen_locked`, `lock_state`, `session.unlock`). The profile chip (last item of
  the tab row) opens Switch profile / Profile settings (End guest session for the guest).
  Switch profile (chip, lock screen) opens the boot picker's screen over the session:
  the open profile is marked "Open" and focused, choosing it (or B) goes back to where you were
  (nothing is called); another profile or Guest goes straight to the Switching page
  (`switch_progress`) and the not-responding pop-up (`switch_blocked`: Keep waiting, Force
  close, Cancel switch), with one question only while a Steam game runs; Add profile creates one
  ("Getting things ready") and switches to it. A locked profile's PIN is asked first, in this
  session, on the same PIN pad ("Switch to Sam"): a wrong PIN says so and nothing closes, B goes
  back; only the right one starts the switch (`session.switch_profile {id, pin}`), and the greeter
  then enters the profile with no picker. The not-responding pop-up counts up every second from
  `switch_blocked.waited_s`.
- **Session start**: "Loading Sam…" until Home has its data (at most 20 s); during the first 20 s a
  connection that is not up (yet, or again: the session daemon restarts once as a session
  starts) shows that page, never "Can't reach the HinterOS service".
- **Text fields in the profile flows** (names): Enter, also the on-screen keyboard's, only closes
  the keyboard and moves to Done; Done or Cancel decides.
- **Forgotten PIN**: every page that asks for an existing PIN (picker, lock screen, own-PIN
  checks, admin-PIN prompts) says "Forgot your PIN?": the person who set up the box removes it
  from a terminal (`sudo hinteros-system reset-pin <name>`), and the profile chooses a new one
  ("Set your PIN") at its next start. There is no in-UI recovery of the admin profile's PIN;
  another profile's PIN can still be reset with the admin PIN.
- **Settings -> Profiles** (`profiles_section.dart`): profiles with storage and Add profile; a
  profile's options: Switch to this profile (another one; as in the picker, its PIN first if
  locked), Rename, Colour, Change PIN, Lock this profile / Unlock this profile, App history
  (per-profile app rollback), Remove (the confirmation, then the PIN pad whose OK is Delete,
  held for 3 seconds: it turns light red at once and fills with red; letting go early empties
  it; a wrong PIN deletes nothing); the admin profile also edits the starter apps
  and turns the guest on or off. Actions on another profile ask for the admin PIN on the same
  pad.
- **Apps per profile**: the Store installs and removes "for this profile"; an app that needs a
  service the box does not run says so in red with Install disabled; the first launch of a
  starter-set app with vendor terms (`apps.list`'s `needs_terms`) shows them first
  (`system.apps.accept_terms`). The system rollback names the profiles the target generation
  would drop or bring back empty.
- **Mock**: `MockSystemServices` has `mockProfiles` (James p1, admin, PIN 2468; Sam p3, locked,
  PIN 1357; the guest) with the service's PIN rules and backoff; `--mock-profile=p3|guest|first-boot`
  picks whose session `--mock` runs. `MockDaemon.profiles` serves the wire methods for the
  contract test and the `Daemon*` repositories.

### Session API 0.9: Store icons, reloaded app list, readable failures

- **Store icons.** `store.list`'s `icon.path` (the daemon resolves catalog icons itself, installed or not, and sends `store_changed` when one arrives) is what Store cards and the detail page draw, with the same tile as app icons and the letter as fallback; `apps.list` icons stay the fallback for installed apps. The mock: `MockDaemon.system.setStoreIcon(id, path)`.
- **App list reload.** The daemon sends `apps_changed` when it reloads its app list after an install or remove, so Home, Apps and Games just follow `apps.list`; nothing refreshes by hand after a job. The mock adds and removes the app on job success and sends `apps_changed`.
- **No Steam.** The daemon leaves `steam` out of `apps.list` while Steam is not installed. Then Games shows "Steam is not installed" with the install button, and Home and Apps have no Steam tile (they only draw what `apps.list` returns).
- **Failures you can read.** A failed launch, switch or close is a dialog (not a toast) with the app's name in the title, a sentence for the error (2001 not in the app list, 2002 the program would not run, not connected) and "Error <code>: <message>" in small type. Every failure is also written to stderr, so the session journal has it for reading over SSH: `hinteros-launcher: start Steam failed: error 2002: ...`, `hinteros-launcher: a system call failed: error 3013: ...` (Store, settings, runtime calls) and `hinteros-launcher: job update (<id>) failed: <code> <message>`. `lib/src/log.dart` (`logFailure`, `logSink`).

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

The controller works as in the session: D-pad or left stick moves, A launches, B goes back (or, on a running
app or game, asks to close it), X is secondary, bumpers switch tabs, the Xbox button is Home. Reading the pad needs
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
`NavAction`s (arrows = directions, Enter = accept (A), Escape or Backspace = back (B), PageUp/PageDown = L1/R1, Y and X = context and secondary), and
`NavController.dispatch` (see "Navigation rules") is the only action layer. The table is one function, `navActionForKey` (`lib/src/nav/key_map.dart`), shared by the launcher and the installer. While a text field has the focus (the admin password prompt) Backspace and the letters Y and X are text, not buttons: Backspace deletes, Enter submits, Escape is back. `press` and `repeat`
move focus (the daemon does the key repeat); `release` never acts. `accept` launches the focused
card, on `press` only: `apps.launch {id}` for an app, `apps.launch {url:
"steam://rungameid/<appid>"}` for a game (it then runs as `steam-<appid>`); a failure (2001, 2002,
not connected) shows a snackbar. Cards of running apps and games carry a "Running" mark, refreshed
through `apps.running` on connect and on `app_started`, `app_exited` and `focus_changed`; running
games show on the Continue row with their Steam header art. `home_pressed` goes to Home.

**Close:** the `back` action (gamepad B / Circle; keyboard Escape or Backspace) on a running app
or game (Continue, Apps, Games) opens a confirm dialog "Close <name>?" over the
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
explicit `null`) and string enums (with or without `type: string`) with an `unknown` fallback, and
params/result schemas that are a `$ref` (the relayed `system.*` results; `display.set_mode`'s params, whose required fields mean the stub has no default argument); `oneOf` on a params object (as in
`apps.launch`) is not modelled, so all its fields are optional in Dart and the daemon validates.

### Tests

- `test/api/contract_test.dart` replays every method and event example of the schema through the
  mock and validates all output against the schema with the `json_schema` package.
- `test/api/client_test.dart` runs `DaemonClient` against a scripted fake server on a real socket.
- `test/app_icons_test.dart` covers the icon cache (PNG, SVG, dominant colour, broken files, a changed file behind the same path) and the tiles (icon vs letter, an icon arriving through `apps_changed`).
- `test/api03_ui_test.dart` covers the 0.3 behaviour through the UI: install-state badges (also that
  they fit narrow covers at text 1.0 to 1.6x), launching and explaining games, Close with its
  confirm step, the attention banner.
- `test/system/daemon_runtime_test.dart` runs the real network, Bluetooth, display/audio and power repositories over the mock's runtime (mapping, events, the 4xxx errors). `test/system/runtime_ui_test.dart` is the same through the Settings screens: Wi-Fi with a wrong password then the right one, Bluetooth pairing with a passkey (Accept, Reject, the code shown for a device that shows none), the display keep or revert dialog with its 15 seconds (`display.keep` / `display.revert`), `can_set` false, power refused while an update is being applied, and one section unavailable while the others work.
- `test/api/mock08_test.dart`: what the contract test's examples do not show about the 0.8 mock: the order of events and answers around the admin password prompt (`auth.respond` answers before the waiting `ssh.set`), three wrong passwords, cancel, who gets the events and may answer, the Store's states while an apps job runs, `store_changed`, dependencies and conflicts, `more_after_update`, `session.restart`.
- `test/system/daemon_store_test.dart`: `DaemonStore` over `MockDaemon`: the listing (sorted, states, terms text from the daemon's file path, unfree without readable terms left out, `unavailable {catalog}`, `system_unavailable`, icons from `apps.list`, a slow older answer not overwriting a newer one), following jobs and `store_changed`, `accepted_terms`, `app_conflict`, `insufficient_resources`, `not_found`, `not_available`, `job_busy`, a stale revision retried once (and only once). `test/system/daemon_store_ui_test.dart`: the same through the screens: install with terms and progress, a stale revision, `terms_required` with a newer version, conflicts, no space, remove with delete data (two confirmations), a running app closed first, retired and going-away apps, the update's new and removed apps, the Games tab's "Install Steam", and the session restart offer (also on a desktop session).
- `test/system/daemon_system_test.dart` runs the real repositories (`DaemonSystem`, `DaemonUpdates`, `DaemonJobs`) over `MockDaemon`'s relay: error mapping, jobs from events, cancel, downgrade acknowledgement, the update check and its cache, `settings.set` with a revision. `test/system/daemon_ui_test.dart` is the same through the Settings screens (SSH without a polkit agent, settings unavailable, About with the DEV badge, a security update through to "Restart session"). `test/osk/osk_auto_show_test.dart`: the keyboard opens and closes with the launcher's text fields.
- `test/installer/` covers the installer: `flow_test.dart` walks the screens with a fake backend (disk filtering, the one erase confirmation on the summary (A held 5 s on "Erase and install"; a shorter hold or Back erases nothing), password mismatch, SSH off by default, offline disabling the online-only apps, the plan JSON for several choices, progress, exit status 2 and 1 with their codes, typing with the pad on the in-app keyboard), `plan_test.dart`, `progress_test.dart`, `parsers_test.dart` (lsblk, nmcli; the catalog index is in `test/system/catalog_test.dart`, against `test/fixtures/catalog`, the real index with placeholder terms text), `process_backend_test.dart` (the real backend class against a stand-in script: the plan arrives on stdin, never in the arguments), `gamepad_test.dart` (the stick deadzone and hysteresis, key repeat, hotplug, disconnects and permission errors, all over synthetic evdev streams from `test/support/fake_pads.dart`; no real device is ever opened), `two_stage_test.dart` (the phase fields, the two progress sections, failed apps on Done), `keyboard_fallback_test.dart` (the evdev keyboard mapping incl. Shift symbols and key repeat, hotplug, and the focus gate: active only while unfocused, never doubled), `input_test.dart` (the installer driven by the keyboard alone and by the stick alone, from Welcome to the restart, and the text-field exceptions), `test/nav/key_map_test.dart`, `first_boot_test.dart`.
- `test/osk/` drives the on-screen keyboard with the mock backend: layout, D-pad navigation, shift,
  pages, and the exact backend calls for typing `P@ss-w0rd!` with D-pad presses only.
- `test/integration/` runs the real `hinteros-session` binary: `nix build .#checks.x86_64-linux.integration`.
  It starts the daemon with `--no-gamescope --no-inputplumber`, a temp config of two command apps
  and `--steam-dir` pointing at the daemon repo's fake Steam home, and covers the 0.8 handshake (an app with an explicit `icon` path gets it back in `apps.list`),
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
  `system_relay_integration_test.dart`: with no system service (`--system-socket` at a missing
  path) every `system.*` call is `system_unavailable {reason: down}`, ping and `apps.list` still
  work, and the real repositories report "Settings are unavailable". With a real
  `hinteros-system` (`HINTEROS_SYSTEM_BIN`, plus `ssh-keygen` on `PATH`) on a temporary fake root
  (`/etc/hinteros`, profile links, `release.json`, an SSH host key) the read-only methods
  (`system.info` with the DEV flag and host key fingerprints, `settings.get`, `generations.list`,
  `jobs.list`, `jobs.get` not found) go through the real relay and the real repositories. **Not
  covered:** the mutating methods against a real `hinteros-system`. The service checks the caller
  against logind (seat0) and polkit over D-Bus, and the fakes for those are Rust test helpers in
  the daemon repo (`crates/hinteros-system/tests/common`), which cannot be used from Dart; those
  paths (`ssh.set` to `authentication_required`, jobs and their events) are covered against the
  mock daemon's relay, whose answers the contract test checks against the schema.
  `runtime_integration_test.dart`: the launcher and the on-screen keyboard say hello at 0.11; with `--no-runtime` every Wi-Fi, Bluetooth, audio, display and power method answers `unavailable` naming its service (`networkmanager`, `bluez`, `audio`, `display`, `logind`) while ping and `apps.list` work, and the real repositories say "<service> isn't available on this box". **Not covered:** `--runtime-bus` with fake NetworkManager, BlueZ, logind, PipeWire and gamescope. The daemon's fakes are Rust test helpers inside its own integration tests (`crates/hinteros-session/tests/runtime_*`), not programs, so nothing from Dart can start them; those paths (wrong password, pairing with a passkey, keep and revert, `power_inhibited`) run against the mock daemon, whose answers the contract test checks against every schema example. The other integration tests start the daemon with `--no-runtime`, so they never reach the host's system bus.
  0.8 (`system_relay_integration_test.dart`): with a real `hinteros-system` and the real session daemon both reading the fixture catalog (`--catalog-index test/fixtures/catalog/catalog.json`, the real index format) `store.list` returns the index merged with state.json's installed apps (by name, Steam `installed`, the rest `available`, terms with the absolute path of a text that exists), and the real `DaemonStore` reads it with the terms text; without the index it is `unavailable {service: catalog}`, without the system service `system_unavailable`. `auth.respond` and `auth.cancel` with no pending request are `not_found` (the repository: cancel is quiet, respond is `notFound`), a client that is not the launcher gets `not_authorized`, and `session.restart` with logind pointed at a bus that does not exist is `unavailable {service: logind}` (**never run it against a real bus**: a greetd session would end). **Not covered:** everything that needs real polkit and PAM (the prompt end to end with a password, `system.apps.install` / `remove` on a real service, `session.restart` ending a greetd session): the daemon repo's VM tests `polkit-agent`, `store-install` and `session-restart`. The daemons are started with `--no-auth-agent`, so they never register with this machine's polkit.
  It is a separate check and is skipped by plain `flutter test` unless `HINTEROS_SESSION_BIN`
  points at the binary (and `HINTEROS_SYSTEM_BIN` at `hinteros-system`) (and `HINTEROS_STEAM_FIXTURE` at `crates/hinteros-session/tests/fixtures/steam-home`
  for the games test), e.g.
  `HINTEROS_SESSION_BIN=$(nix build ../hinteros-daemon#hinteros-session --no-link --print-out-paths)/bin/hinteros-session HINTEROS_STEAM_FIXTURE=../hinteros-daemon/crates/hinteros-session/tests/fixtures/steam-home flutter test test/integration`.

## Installer mode and first-boot wizard

The same binary is the installer UI for the ISO (roadmap M9): `hinteros-launcher --installer`
(or `HINTEROS_INSTALLER=1`). It is controller-only and talks to no session daemon: it runs the
system repo's `hinteros-install` backend. `--first-boot` (or `HINTEROS_FIRST_BOOT=1`) is the
wizard for a box that is already installed (see "First-boot wizard" below).

Screens: Welcome, Internet (cable status; Wi-Fi list and join through `nmcli`; or carry on
offline), Disk (internal disks from `lsblk --json`; removable, in-use and under 16 GiB disks are
listed with the reason and cannot be picked; a full-screen warning and then a second "last check"),
Admin account (user name, password and the password again, typed on the in-app keyboard), Options
(computer name, default `hinteros`; Enable SSH, off by default, with what it means; update
channel stable or beta), Apps (`AppSelectionView`: YouTube and Firefox ticked, apps that need a
download disabled with "Needs internet" while offline, vendor terms read and accepted), Summary,
Installing (`hinteros-install --validate-only`, then the install, with the stages in plain words,
a percentage and the warnings; on an error the explanation of its code, the log path
`/var/log/hinteros-install.log`, Try again or Change my choices) and Done (remove the stick,
Restart now = `systemctl reboot`).

Try it on the desktop with a scripted backend that touches nothing:

```
flutter run -d linux --dart-entrypoint-args=--installer,--mock,--windowed
# or: nix build && ./result/bin/hinteros-launcher --installer --mock --windowed
./result/bin/hinteros-launcher --installer --mock --mock-scenario=refused --windowed
```

**Keyboard (and stick).** Everything works from a USB keyboard and from the Xbox controller alone. Keyboard: arrows move, Enter = A (accept), Backspace or Escape = B (back), Tab and Shift+Tab move the focus, X and Y are secondary and context, PageUp/PageDown the bumpers, F1 the View button. While the in-app keyboard is up, it is a text field: letters, digits and space type, Backspace deletes, Enter submits (Done), Escape cancels (and does not go back), the arrows move around the on-screen keys. Controller: the D-pad and the left stick move (the right stick is ignored), A accepts, B goes back, X and Y are secondary and context, the bumpers are the page buttons; in the on-screen keyboard B closes it (cancels), X is Backspace, Y is Shift, Space is a key, Menu is Done and View cancels. The Guide button does nothing in the installer. Held directions repeat like the daemon (after 400 ms, then every 120 ms), for the stick and the D-pad alike. `--mock-scenario=` is `ok` (default: no network, Wi-Fi "Living Room" with
the password `correct horse`, a successful install after about ten seconds), `online` (a cable is
plugged in), `refused` (`hinteros-install` exits 2 with `disk-in-use`) or `failed` (exit 1 with
`install-failed`). The fake backend never runs a program. Without `--mock` the real backend
runs `lsblk`, `nmcli`, `hinteros-install` and `systemctl`: do not do that on a machine you care
about, the install erases the disk.

**Two stages.** `hinteros-install` installs the HinterOS base system first (`phase:"system"`), then the picked apps (`phase:"apps"`, an optional `app` id per line). The progress screen has two sections, "Installing HinterOS" (the stage checklist and its own percentage; once the apps stage starts it shows 100%) and "Installing apps" (one row per picked app: waiting, installing, done or failed, and a percentage of apps finished). A `level:"warn"` line with `code:"app-failed"` and `app` marks that app failed; the exit status stays 0 and the last line is `{stage:"done", failed_apps:[...]}`. Done then says "HinterOS is installed. These apps couldn't be installed and can be added later from the Store: ...". Lines without `phase` count as the system (older backends), and the apps' percentage does not depend on the backend's `percent` being per phase or overall. `--mock-scenario=apps-failed` shows the failure on the desktop.

**Keyboard focus fallback.** On real hardware under cage the window sometimes does not get the compositor's keyboard focus at first (the pad still works, it is read from evdev). While the window has no keyboard focus the installer therefore reads the USB keyboards from evdev itself (`evdev_keyboard.dart`: devices with letters, Enter and Space, never grabbed, same hotplug rescan as the pad; US layout with Shift and Caps Lock; the kernel's key repeat becomes repeat events) and feeds the same actions and text input as hardware keys. `keyboard_fallback.dart` decides when: the runner reports focus over the `hinteros/window` channel (`focus` bool, `isActive` query), any Flutter key event proves the compositor delivers keys (the evdev keys are then ignored, so nothing is typed twice), and an evdev key while GTK claims focus but no Flutter key arrives within 300 ms switches the fallback on. Focus changes, the first Flutter key event and the fallback switching on and off are logged to stderr (`hinteros-focus:` / `hinteros-evdev:`), as are GTK's toplevels and the runner's `present` retries (`linux/runner/my_application.cc`).

### How it works

| Path | What |
|---|---|
| `lib/src/installer/backend.dart` | `InstallerBackend`: network, Wi-Fi, disks, catalog, `validate(plan)`, `install(plan)` (an `InstallRun`: progress events plus the exit status), `reboot()` |
| `lib/src/installer/process_backend.dart` | The real one. Every command is an executable with a fixed argument list, no shell. The plan, with the admin password, goes to `hinteros-install --plan -` on stdin; a Wi-Fi password goes to `nmcli --ask` on stdin; nothing on a command line, nothing the tools print on stderr is kept or logged |
| `lib/src/installer/fake_backend.dart` | The fake: scripted progress, refusals (exit 2), failures (exit 1), the plans it was given, a mock machine (disks, Wi-Fi, catalog with placeholder vendor terms) |
| `lib/src/installer/plan.dart` | `InstallPlan`: the JSON the backend wants (`disk`, `hostname`, `admin {user, password}`, `ssh {enable}`, `channel`, `base`, `network`, `apps`, `wifi {ssid, psk}`), and the UI checks that mirror the backend's |
| `lib/src/installer/progress.dart` | The stdout lines `{stage, percent, level, message, code?}`, the verdict (exit 0 and a `done` line is success; 2 is "refused, nothing was touched"; 1 or anything else is "failed part-way"; exit 0 with an error line is a failure too), and the plain-words text for every error code |
| `lib/src/installer/parsers.dart` | `lsblk --json -b` and `nmcli -t` output (`\:` escapes) |
| `lib/src/system/catalog.dart` | The catalog index (format 2), shared with the Store: `parseCatalogIndex`, `loadCatalogIndex`, the terms reader |
| `lib/src/installer/gamepad.dart` | Controller input without the daemon: reads the evdev gamepads under `/dev/input` (A accepts, B back, X/Y, bumpers, View/Menu; D-pad and the left stick with a 0.5 deadzone, hysteresis and the daemon's key repeat; a rescan every 2 s for hotplug; `evdev_ioctl.dart` reads the stick range with `EVIOCGABS`) |
| `lib/src/installer/flow.dart` | `InstallerFlow`: the answers, the steps, the install run |
| `lib/src/installer/ui/` | The screens, the shared input host (`host.dart`), the in-app keyboard (`text_entry.dart`), the first-boot wizard |

**Keyboard.** There is no daemon on the ISO to type for us, so the installer shows the same
on-screen keyboard (`OskScreen`, same layouts) with an `InProcessKeyboard` as its `OskBackend`: the
keys go into the field instead of into uinput. Done, Menu or Enter saves; View or Escape cancels. A physical keyboard types into it directly (`OskScreen(hardwareKeys: true)`).

**Catalog.** One model (`StoreApp`) and one parser (`lib/src/system/catalog.dart`) read the real
index of the catalog repo (`indexVersion` 2, `schema/index.schema.json` there), for the installer
and the Store alike. The installer reads `/run/current-system/sw/share/hinteros/catalog.json` on
the ISO (`catalogIndexPath`; `ProcessInstallerBackend(catalogPath:)` overrides it for tests); the
vendor terms are text files next to it (`terms/<id>-<version>.txt`), which the index entry names as
`terms {title, version, url, retrieved, file}` and the parser reads into `VendorTerms.text`
(only paths of the form `terms/<name>.txt`). Only `status: available` entries are read. The
installer lists entries with `installer: true`, pre-selects `installerDefault`, and says "On the
installer" for `onIso` (everything else is a download and is disabled while offline). The safety
rule: an unfree entry (`free` is not true) whose terms are missing or unreadable is not offered, in
the installer or the Store. Without an index (or one of another version) the four free ISO apps are
offered as a fallback.

**Accepted terms.** The plan carries `acceptedTerms: {"<id>": "<terms version>"}` for the selected
apps that have terms (always present, `{}` when none); the system repo's `hinteros-install`
validates it against the index and records it on the box.

**Icons.** There is no daemon on the ISO and the installer UI never fetches anything, so the
installer's list shows the letter tile (`AppIconBadge` without an icon path). The Store gets icons
from the daemon (`StoreRepository.resolveIcon`: installed desktop icon, `iconUrl`, discovery on
`siteUrl`, the kiosk profile's favicon, then a letter tile); the index only carries the inputs
(`icon.desktopId`, `iconUrl`, `siteUrl`, `firefoxProfile`).

### What the system repo must set

- `hinteros.installer.ui.command` to the launcher in installer mode, for example
  `hinteros-launcher --installer`, started under cage (the same `--windowed`-less fullscreen mode
  as on the box: one fullscreen window).
- Run it as **root**. It reads the gamepads from `/dev/input`, runs `nmcli` (Wi-Fi) and
  `systemctl reboot` and starts `hinteros-install`, which needs root itself (`not-root` is exit 2).
  A narrowly scoped sudo rule is possible instead but needs exactly: `hinteros-install --plan -`,
  `hinteros-install --plan - --validate-only` and `systemctl reboot`; the UI never builds a command
  from typed text, so the rule can name those argument lists literally. Gamepad access then needs
  group `input`.
- On `PATH`: `hinteros-install`, `lsblk` and `nmcli` (NetworkManager running on the ISO),
  `systemctl`. `hinteros-install` is looked up by name.
- Fonts: the launcher bundles Atkinson Hyperlegible, so no font package is needed. Flutter
  under cage needs working GL (the GPU driver, or Mesa's software renderer for a machine without
  one); this has not been tried on the ISO yet.
- The catalog index and its `terms/` directory at the path above: the catalog repo's `index` package (`share/hinteros/catalog.json`, `share/hinteros/terms/*.txt`) in the ISO's system packages.
- Network: NetworkManager with `connectivity` checking on (`general CONNECTIVITY` is how the UI
  knows it is online). Without checking, a connected cable or Wi-Fi counts as online and the
  backend's own probe of cache.nixos.org has the last word.

### First-boot wizard

`--first-boot` shows the wizard on the running system: Welcome, Internet, Controllers
(Bluetooth pairing through the existing `BluetoothRepository`), a display check, All set. It is a
skeleton: the first profile, the update channel, the app step (`apps.install`, needs M8), a
display mode picker with keep and revert, skipping steps that are already done, and handing the
session over to the launcher are TODOs listed in `lib/src/installer/ui/first_boot.dart`. It uses the
daemon's runtime settings (`daemonSystemServices`), or the mock with `--mock`.

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

**Controller (B closes).** A types the focused key (Space is the wide key on the bottom row), **B closes the keyboard** (`osk.hide`; in the installer it cancels the edit like View), **X is Backspace** (repeats while held), **Y is Shift** (or "More" on the symbol pages), L1/R1 switch pages, Menu is Done. The hint line in the preview strip reads "A Type   B Close   X Delete   Y Shift" (hidden at large text sizes). On a physical keyboard Escape closes and Backspace deletes; the key echo is unchanged.
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
é"; with the preview masked (a password field) only their number). Anywhere else the
keyboard is summoned by the daemon (hold Guide and press Y). The launcher's own text fields call
`osk.show` themselves, see "Text entry".

**Controls** (the nav layer's conventions: presses and repeats move, only a press acts):

| Input | Does |
|---|---|
| D-pad | Moves between keys. Left/right wrap within a row; up/down go to the key above or below (rows of unequal keys use `NavRow.spans`, so the wide Space bar is under several letters) |
| accept (A) | Types the key |
| back (B) | Backspace, also while held (repeat) |
| context (Y) | Shift: one-shot, again for caps lock, again off. On the symbol pages: switches between symbols 1 and 2 |
| secondary (X) | Space |
| L1 / R1 | Letters / symbols page |
| the Done key | `osk.hide` at once (not behind keys still waiting for an answer; a failure shows in the strip and on stderr); the keyboard also resets (letters, shift off, empty preview) |

Shift was chosen for `context` rather than the page toggle because it is needed mid-word, while a
page change is one key away and has L1/R1. Pages: letters (digits row, `'` and `.`), symbols 1,
symbols 2 (`[ ] { }` and the backtick); together they cover every printable ASCII character. The
strip above the keys is a preview of what was typed since opening (Backspace removes). **It is
masked only for a password field** (`osk_visibility.password`, session API 0.10; a password must not
appear on the TV): dots, with the newest character readable for about a second, like a phone
password field. Any other field, or none reported (the Guide+Y chord), shows plain text. When the
field kind changes while the keyboard is up, the preview starts afresh, so a password never shows
unmasked. Settings > "Show typed passwords on the on-screen keyboard" (default off) shows passwords in
plain text too; the keyboard reads `launcher.json` again every time it opens. The preview is cleared on hide. Characters go out with `keys.type` (the daemon picks uinput or the
gamescope input method), Space included; the keyboard has no text field of its own.

## UI

### Layout: top tab bar

Sections are Home, Games, Apps, Store and Settings in a **top tab bar** (wordmark left, clock right). The
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
  "Show typed passwords on the on-screen keyboard" (privacy; off = in password fields the keyboard's
  preview shows dots).
  Below them the system sections (see "System screens"): Network, Bluetooth, Display, Audio, Power,
  Remote access, Updates, About.
- **Store:** see "Store". A top-level tab after Apps (see the placement note there).

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

### System screens, jobs and the Store

Everything below is built against **repository interfaces** (`lib/src/system/repositories.dart`).
Since session API 0.6 the daemon relays the privileged system service (`system.*`, design in
`design/system-api.md` in hinteros-docs), and `lib/src/system/daemon_system.dart` implements
`SystemRepository` (info, SSH, power), `UpdatesRepository` and `JobsRepository` over it. Since 0.7
the runtime settings (Wi-Fi, Bluetooth, audio, display, power) are served by the session daemon
itself, and `lib/src/system/daemon_runtime.dart` implements `NetworkRepository`,
`BluetoothRepository` and `DisplayAudioRepository` over them (`daemonSystemServices(connection)`,
what `main` uses; the error mapping is in `daemon_errors.dart`). Since 0.8 the same function also wires
`AuthRepository` (`daemon_auth.dart`: the admin password prompt), `restartSession` (`session.restart`)
and `StoreRepository` (`daemon_store.dart`: `store.list`, `store_changed`, `system.apps.install` /
`remove`). `--mock` uses the in-process fakes of `lib/src/system/mock_system.dart` (all
repositories; their `MockAuth` and `MockStore` follow the real ones' rules). Nothing is left
unavailable except what the daemon itself reports as such.

Responses may arrive out of order (a relayed call can wait minutes for the admin password), which
the client handles by matching on the request id; `system.ssh.set` has a 340 s timeout instead of
10 s.

**What the screens do with the daemon's answers**

| Answer | The screen |
|---|---|
| `wrong_password` (4003) | The Wi-Fi password dialog stays open with "That password was not accepted. Try again." and the on-screen keyboard comes back. A saved password the network no longer takes asks for the new one |
| `unavailable` (4001) | That section shows "<service> isn't available on this box." (Wi-Fi, Bluetooth, Audio, Display control, Power control) with Try again; the other sections are not touched |
| `bluetooth_confirm` (mode `confirm`) | A modal with the passkey and Reject / Accept (`bluetooth.confirm`); Back or a timeout rejects. Mode `display`: only the code, "Type this code on <device>", and the modal closes by itself when the pairing ends |
| `power_inhibited` (4005) | "Not right now": "Can't do that while an update is being applied." |
| `device_failed` (4002) | The daemon's message; for the display `not_applied` explains that HinterOS may be started with a fixed resolution |
| `not_authorized` (4004) | "HinterOS isn't allowed to change that on this box." |
| Display: `set_mode` | The existing 15 second "Keep this resolution?" dialog: Keep calls `display.keep`, Go back, Back or the countdown call `display.revert`. `can_set` false: the section says the resolution can't be changed from here and the modes explain instead of switching |
| Power: `power.capabilities` | An action logind answers `no`, `challenge` or `na` for is marked "Not allowed on this box" and explains when chosen |
| Events | `network_changed`, `wifi_list_changed`, `bluetooth_changed` and `audio_changed` update the open section (a scan finishing, a controller connecting, the volume changed by a headset) |

| Interface | Wraps (later) | Used by |
|---|---|---|
| `SystemRepository` | `system.info`, `ssh.set`, `settings.get` / `set` (with `revision`), `power.capabilities` / `suspend` / `reboot` / `poweroff`, `session.restart` | About, Power, Remote access, session restart |
| `AuthRepository` | `authentication_requested` / `authentication_finished`, `auth.respond`, `auth.cancel` | the admin password prompt (shell-wide) |
| `UpdatesRepository` | `update.check`, `update.apply`, `generations.list`, `rollback`, `channel.set`, `base.set` | Updates, reminders |
| `JobsRepository` | `jobs.get` / `jobs.cancel`, `job_started` / `job_progress` / `job_finished` | the progress page |
| `NetworkRepository` | `network.status`, `wifi.*`, `network_changed`, `wifi_list_changed` | Network |
| `BluetoothRepository` | `bluetooth.*`, `bluetooth_changed`, `bluetooth_confirm` | Bluetooth |
| `DisplayAudioRepository` | `display.modes` / `set_mode` / `keep` / `revert`, `audio.*`, `audio_changed` | Display, Audio |
| `StoreRepository` | `store.list`, `store_changed`, `system.apps.install` / `remove` (+ the job events) | Store, Games |

`MockJobs` behaves like the service: one mutating job at a time (`job_busy`), stages, progress,
cancel until activation. Tests drive it by hand (`progress`, `finish`); `--mock` lets jobs run
through their stages by themselves.

- **Modal stack** (`lib/src/ui/modal_host.dart`): dialogs and full-screen pages each own a `NavRegion`;
  the top one takes all input, Back closes it unless it says otherwise. Regions also have
  `interceptMove` and `onAction` hooks (the terms page scrolls on up/down and pages on L1/R1; the
  volume row steps on left/right).
- **Text entry:** a masked `TextField` bound to a nav row (`NavTextField`). **The keyboard opens by
  itself:** a field that gains focus calls `osk.show`, and focus leaving it, the dialog closing or
  a submit calls `osk.hide` (a refused password shows it again for the retry); `OskControl`
  (`lib/src/osk/osk_control.dart`, reached through `OskScope`) counts the focused fields so one
  going away after the next took focus does not hide it. If the keyboard is off (`osk_unavailable`,
  2005) or there is no daemon, the field still works with a physical keyboard. What the keyboard
  types arrives as `keys.type` text and `keys.action` Backspace/Enter, which the daemon injects
  into the focused window (the launcher's; the keyboard window never takes focus), so the field
  needs nothing special: `test/osk/osk_auto_show_test.dart` checks text, Backspace and Enter reach
  it and that typing Y or X is text, not a button press. (Checked in widget tests only; the key
  injection itself is the daemon's, and the real chain, uinput to gamescope to GTK to the field,
  is on the hardware checklist.) "Hold Guide, press Y" is no longer printed in the dialogs; it is
  kept in Settings, under "Typed text on keyboard", as the way to open the keyboard anywhere else.
- **Remote access:** one SSH toggle. SSH is plain username and password for now (you log in as the
  admin account). Key import and key-only login are in the backlog. The toggle just calls
  `ssh.set`; turning it on makes the daemon ask for the admin password, which shows as the prompt
  described in "Admin password and polkit".
- **Progress page** (`pages.dart`): the stages of the job kind, a percentage where the job reports one,
  Cancel until activation ("Can't cancel now" after), "your session will restart" while running,
  "Restart session" when `session_restart_required`, and on failure or cancel what went wrong plus
  "Nothing was changed". Back does not leave a running job's page. "Restart session" calls `session.restart`; the daemon answers and then ends the session (the launcher goes with it, greetd starts a new one). On a desktop session (not greetd) the daemon refuses and the page says "This is not a TV session, so it cannot be restarted from here".
- **Updates:** at startup the box checks once (`UpdateReminders`; the real check waits for the
  connection, and is tried again after 5, 15, 45 and 120 s while the system service is not up
  yet, since it can start after the session; the update check is a job whose result arrives with
  `job_finished`, or comes straight back when cached within 60 s). The version of an update is
  `available.version` ("HinterOS 0.6.1", session API 0.11) when that is a release version, else
  its date (the daemon's short-rev fallback, or an older daemon); the notice's severity is
  `available.security`, with `available.security_summary` under it when the release has one (also
  on Settings, Updates). Behind its channel, Home shows a
  non-modal banner ("See update" leads to Settings, Updates) at startup and on every return to Home.
  A **security update** (severity trailer) shows a full-screen notice instead: the severity, a
  visible countdown, and for 5 seconds buttons, Back and Home do nothing; then "Later" (focused
  first) and "Update now". The notice appears at startup and on every return to Home until the update is
  installed. Nothing is ever installed without choosing it.
- **Store (a top-level tab, after Apps):** categories on the left, apps on the right, an app page
  (modal) with Install or Remove. Why a tab and not a place under Apps: it is reachable with L1/R1,
  has its own two-pane navigation, and keeps the Apps grid as "what you have". The real repository
  is `DaemonStore` (`lib/src/system/daemon_store.dart`): `store.list` is the listing (every app with
  its `state`: available, installed, installing, removing, retired, unavailable), refreshed on
  `store_changed` and after every (re)connect; an answer that arrives after a newer request's is
  dropped. The terms text is read from the absolute path in `terms.file` (offline), and an unfree
  app whose text cannot be read is not offered. Icons: the daemon resolves them for installed apps
  (`apps.list`'s `icon`); an app that is not installed gets the letter tile (the launcher fetches
  nothing). **Install:** confirm (size, the apps that come along, transitively), then the vendor
  terms of the app **and of every app that comes with it**, each in full (up/down scroll, L1/R1
  page, "Accept and install" stays off until the end is reached), then
  `system.apps.install {ids, revision (from settings.get), accepted_terms: {id: version read}}`, then
  the progress page (job kind `apps_install`). A stale revision (`state_conflict`) is fetched again
  and the call tried once more. **What the service says:** `terms_required` shows the terms of the
  app it names again (re-reading the listing: the version may be newer) and retries with the new
  version; `app_conflict` says which app is in the way ("Kodi cannot be installed together with
  Jellyfin. Remove Jellyfin first if you want Kodi."; for removing: "RetroArch needs Emulator
  cores"); `insufficient_resources` says how much space is needed and free; "already installed"
  says so. **Remove:** confirm with "Also delete this app's data in all profiles"; ticking it asks
  again (Steam: installed games go too); a running app is closed first (`apps.close`); then
  `system.apps.remove {ids, revision, delete_data}` (job kind `apps_remove`). **States:** cards say
  Installing... / Removing...; a retired app ("This app is retired. <reason> It keeps working")
  and one the next update takes away can be removed. **"More apps are available after the next
  update"** shows from `store.list`'s `more_after_update` or an update check's `new_apps` (the
  names are listed); Settings > Updates names `removed_apps` with the catalog's reason, also in
  the "Update now" confirm. **Games tab:** with Steam not installed, "Install Steam" runs the same
  install flow right there (`installSteam`), not shown until the first listing arrived. The mock
  Store (`MockStore`) reads `test/fixtures/catalog/catalog.json` (or `$HINTEROS_MOCK_CATALOG`) in
  the real index format, plus three mock-only apps for dependencies.

- **Installer app selection** (`lib/src/ui/app_selection.dart`): `AppSelectionController` and
  `AppSelectionView` for the M9 installer and first-boot wizard: a checklist with the `installerDefault` apps
  ticked, "On the installer" vs "Download, size" per app, terms acceptance for ticked apps with terms,
  Continue off until accepted. It needs a `ModalHost` above it (see `test/support/modal_host_harness.dart`).

### Data access

The UI reads through `AppsRepository` (apps, running, launch, close, Steam attention and focus) and
`GamesRepository` (`games.list`, launch by Steam URL) in `lib/src/data/`, combined in
`LauncherData`, which owns all daemon traffic and re-queries on connect and on events (the daemon
does not replay them). The client speaks session API 0.11 (during 0.x the minor must match); the on-screen keyboard's connection too.

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
(`osk_*_1080p.png`). `home_games_row_text160_1080p.png` shows the install badges at 1.6x. `test/golden/runtime_test.dart` covers the runtime settings on the real repositories over the mock daemon (`bt_pair_*` for the passkey modal, `wifi_wrong_password`, `settings_bt_unavailable`, `settings_display_cannot_set`, `display_keep_daemon`, `power_inhibited`, `settings_power_restricted`, `settings_net_no_internet`). `test/golden/system_test.dart` covers the system screens (`settings_sys_*`, `auth_prompt_*` (the admin password prompt: masked, and after a wrong password in high contrast at 1.6x; also over the real repositories), `ssh_cancelled`, `wifi_password`, `display_*`), the progress page (`progress_*`), the security notice (`security_notice_*`, also high contrast at 1.6x, locked and unlocked), the Home reminder, the Store (`store_*`; over the real repository: `store_retired_detail`, `store_install_conflict`, `store_installing_progress`, `store_no_space`, `store_more_apps_highcontrast_text160`), the terms page (`terms_*`, also high contrast at 1.6x, from the top and scrolled to the end), `games_steam_missing` and `installer_app_selection`. `test/golden/installer_test.dart` has `installer_*_1080p.png` for every installer screen (welcome, network, disk, the disk warning and the second confirmation, the warning in high contrast at 1.4x text, account, keyboard, options, apps offline and online, summary, progress with the system stage and with the apps stage, both failures, done, done with failed apps). Further goldens cover the Games grid (unscrolled, scrolled to the last row, with artwork), Home with a
running game, the attention banner, the close confirm and the app tiles at text 1.3x/1.6x (also high
contrast). Tests load the bundled font explicitly (`flutter_test_config.dart`, no
Ahem), use a fixed clock, the in-process mock, the committed placeholder art
(`test/fixtures/art/`, decoded into the image cache before the first frame) and settle animations.
The comparator allows 0.05% differing pixels.
`test/golden/greeter_test.dart` covers the picker (`greeter_*`: tiles, PIN pad with the "Forgot your
PIN?" hint, Add profile, `greeter_loading` after a login) and `test/golden/profiles_test.dart` the
profile screens in a session (`profiles_*`: the chip menu, `profiles_switch_picker` with the open
profile marked, `profiles_switch_pin` (a locked target's PIN in the session), not responding,
the lock screen, Settings -> Profiles, `profiles_delete_pin_hold` (Delete half held),
`profiles_startup_loading` for the first frames).

```
nix run .#update-goldens   # renders them in the Nix sandbox (same environment as the check), copies them in
git diff --stat test/golden && git add test/golden   # look at the images, commit them with the code
```

`nix flake check` (check `test`) runs `flutter test` including the golden comparison in the sandbox.
Goldens are generated on this machine, the future CI runner host; moving the runner to other
hardware means regenerating all of them in one reviewed commit (TESTING.md). Plain `flutter test`
in `nix develop` also compares them, and may differ slightly from the sandbox; use
`update-goldens` rather than `flutter test --update-goldens` when committing.

### Admin password and polkit

`ssh.set` (turning SSH on) is guarded by the polkit action `org.hinteros.system.ssh` with
`auth_admin`: the admin password. Since session API 0.8 the **session daemon is polkit's
authentication agent** for the calls it relays, and the launcher shows the password prompt:

1. The launcher calls `ssh.set {enabled: true}`. The call **waits** (up to 330 s at the daemon, so
   the client gives it 340 s), and its response may come after the answers to later calls.
2. The daemon sends `authentication_requested {cookie, action, message, identities}` to the
   launcher only. `AuthPrompter` (`lib/src/ui/auth_prompt.dart`, owned by the shell, so it shows
   over whatever screen is up) opens the **Admin password** dialog: "Enter the password for
   <account> to turn on SSH." (the account is the first identity; for an action the launcher
   does not know, polkit's own message is shown instead), a masked field (the on-screen keyboard
   opens with it; "Show what I type" is off), Cancel and Submit.
3. Submit sends `auth.respond {cookie, password}`. `{ok: false, attempts_left}` keeps the dialog
   open with "That is not the password. 2 tries left." (the field is empty again and the keyboard
   comes back); after the third wrong one the request fails and the dialog closes. `{ok: true}`
   closes it and the progress page of the SSH job follows.
4. Cancel or Back sends `auth.cancel {cookie}`. `authentication_finished {cookie, outcome}`
   (authorized, failed, cancelled, also when polkit gives up after 2 minutes) closes the dialog
   without sending anything.
5. The waiting `ssh.set` ends with the job, or with `authentication_required` ("The admin password
   was not given, so nothing was changed.": cancelled, timed out, or no agent registered) or
   `permission_denied {reason: polkit}` ("The admin password was wrong too many times. Nothing was
   changed."). Turning SSH off needs no password.

**The password:** it is read from the field and the field is emptied in the same moment; it is the
argument of `auth.respond` and nothing else (not stored in a state object, not in an error, not
logged: `AuthAnswer` carries only `ok` and the tries left). Dart strings cannot be wiped from
memory, so this is as far as the launcher can go; the daemon wipes its copy, and only the launcher
connection (hello name `hinteros-launcher`) may answer. `auth.respond` for a request that is
over is `not_found` (the dialog just closes). The flag `adminPasswordUi` that kept this off until
the daemon had an agent is gone.

What the tests cover: `test/system/system_ui_test.dart` (the prompt on `MockAuth`: masked, empty
refused, wrong then right, three wrong, Back, Cancel, closed by the daemon, off needs none),
`test/system/daemon_ui_test.dart` and `test/system/daemon_system_test.dart` (the same over the real
repositories and `MockDaemon`'s agent, including the out-of-order answers and `not_authorized` for
other clients), `test/api/mock08_test.dart` (the mock's order of events and answers). **Not covered
anywhere here:** polkit and PAM themselves. That a real polkit matches the system service's
subject to the agent the user service registered, that the helper runs under the unit's
`NoNewPrivileges`, and that three wrong passwords really fail are the daemon repo's VM test
(`polkit-agent`).
