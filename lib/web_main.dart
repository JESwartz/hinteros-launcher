import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/api/api.dart' show NavAction, NavPhase;
import 'src/app.dart';
import 'src/demo/web_demo.dart';
import 'src/log.dart';
import 'src/platform/gamepad_web.dart';
import 'src/platform/local_files_web.dart';
import 'src/settings/launcher_settings.dart';
import 'src/system/mock_system.dart';
import 'src/system/profiles.dart';
import 'src/ui/profiles/greeter_screen.dart';

/// Entry point of the browser demo (`flutter build web -t
/// lib/web_main.dart`): the launcher against the in-process mock daemon, as
/// `--mock --windowed` on the desktop, with its own free content bundled as
/// web-only assets (`lib/src/demo/web_demo.dart`). No Server tab, no dev
/// keys. Settings and the mock live for the page only.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  logSink = debugPrint;
  await preloadLocalFiles(textPrefixes: demoTextPrefixes);
  _Box().start('p1');
}

/// How long `Opening <name>...` stays before the next session starts.
const _opening = Duration(milliseconds: 1500);

/// The box of the page: what lasts across profile switches (the profiles,
/// the installed apps, the starter set, each profile's launcher settings),
/// and the session or picker on screen. On a box greetd ends a session and
/// starts the next one; here [start] and [picker] do it with a fresh
/// `runApp`, so no state of the old session is left.
class _Box {
  final box = MockProfileBox(profiles: demoProfiles());
  Set<String>? _installed;
  StarterSet? _starter;
  final _settings = <String, SettingsStorage>{};
  var _run = 0;

  /// Where the controller and the Home key go now.
  void Function(NavAction, NavPhase) _nav = (_, _) {};
  void Function() _home = () {};

  late final _pad = WebGamepad(nav: (a, p) => _nav(a, p), home: () => _home())
    ..start();

  /// A session of [profileId] (a profile id or `guest`).
  void start(String profileId) {
    final demo = WebDemo(
      profileId: profileId,
      box: box,
      installed: _installed,
      starter: _starter,
    );
    final services = demo.services;
    services.mockProfiles.onSwitched = (target) {
      _installed = services.mockStore.installed;
      _starter = services.mockProfiles.starter;
      Timer(_opening, () {
        services.dispose();
        target.isEmpty ? picker() : start(target);
      });
    };
    _nav = (a, p) => demo.daemon.emitNav(a, p);
    _home = demo.daemon.pressHome;
    // A guest starts fresh every time; a profile keeps its settings.
    final storage = profileId == CurrentProfile.guestId
        ? MemorySettingsStorage()
        : _settings.putIfAbsent(profileId, MemorySettingsStorage.new);
    _show(
      CallbackShortcuts(
        bindings: {
          // The Home button: back to Home, also from a "running" app.
          const SingleActivator(LogicalKeyboardKey.home): () => _home(),
        },
        child: Focus(
          canRequestFocus: false,
          child: LauncherApp(
            data: buildData(demo.daemon),
            settings: SettingsController(storage),
            services: services,
            showServer: false,
            gamesNeedSteam: false,
          ),
        ),
      ),
    );
  }

  /// The profile picker, as at boot.
  void picker() {
    final services = MockSystemServices(autoRunJobs: true, profileBox: box);
    final pad = StreamController<(NavAction, NavPhase)>.broadcast();
    final greeter = MockGreeter(services.mockJobs, box: box);
    _nav = (a, p) => pad.add((a, p));
    _home = () {};
    _show(
      GreeterApp(
        greeter: greeter,
        jobs: services.mockJobs,
        system: services.mockSystem,
        pad: pad.stream,
        hideCursor: false,
        onEntered: () => Timer(_opening, () {
          unawaited(pad.close());
          services.dispose();
          start(greeter.entered!);
        }),
      ),
    );
  }

  void _show(Widget app) {
    _pad; // polling starts with the first screen
    runApp(KeyedSubtree(key: ValueKey(++_run), child: app));
  }
}
