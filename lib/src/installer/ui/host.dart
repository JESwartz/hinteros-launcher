import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/api.dart' show NavAction, NavPhase;
import '../../app.dart' show DesignScale;
import '../../settings/launcher_settings.dart';
import '../../nav/nav_controller.dart';
import '../../theme/hinter_theme.dart';
import '../../ui/modal_host.dart';
import '../gamepad.dart';
import 'text_entry.dart';

/// What a screen gets from the [ConsoleHost]: the navigation layer, modal
/// pages, the one content region and the in-app keyboard.
class ConsoleController {
  ConsoleController(this.nav) {
    modals = ModalController(nav);
    nav.adopt(content);
    nav.fallback = () => modals.topRegion ?? content;
  }

  final NavController nav;
  late final ModalController modals;

  /// The region of the current screen's focusable rows.
  final content = NavRegion('content');

  /// Back, when nothing else (a modal) took it. Return false to ignore.
  bool Function()? onBack;

  InProcessKeyboard? _keyboard;

  /// Whether the in-app keyboard is up.
  bool get typing => _keyboard != null;

  /// The keyboard that is up, for tests that type without walking the keys.
  @visibleForTesting
  InProcessKeyboard? get keyboard => _keyboard;

  /// Moves focus to [content] as soon as it has rows. Call after changing
  /// what the content shows.
  void refocus() => nav.focusRegion(content);

  /// A fresh start for a new screen: no rows, first item focused.
  void newScreen() {
    content.setRows(const []);
    content.reset();
    refocus();
  }

  /// Edits [initial] with the in-app on-screen keyboard (there is no daemon
  /// on the ISO to type for us). Resolves with the text when Done or Enter is
  /// pressed, null when cancelled with the View button.
  Future<String?> editText({
    required String title,
    String initial = '',
    bool secret = false,
    String? hint,
    int maxLength = 128,
  }) async {
    if (_keyboard != null) return null;
    final kb = InProcessKeyboard(initial, maxLength: maxLength);
    _keyboard = kb;
    try {
      return await modals.show<String>((context, modal) {
        kb.onDone = (text) => modal.close(text);
        kb.onCancel = () => modal.close();
        return TextEntryScreen(
          keyboard: kb,
          title: title,
          hint: hint,
          secret: secret,
        );
      });
    } finally {
      _keyboard = null;
      unawaited(kb.dispose());
    }
  }

  /// One action from the controller or keyboard.
  void action(NavAction a, NavPhase phase) {
    final kb = _keyboard;
    if (kb != null) {
      if (phase == NavPhase.press &&
          (a == NavAction.view || a == NavAction.menu)) {
        kb.onCancel?.call();
      } else {
        kb.emitNav(a, phase);
      }
      return;
    }
    nav.dispatch(a, phase);
  }
}

/// The input and modal plumbing shared by the installer and the first-boot
/// wizard: keyboard keys and the evdev gamepad become [NavAction]s, in one
/// place, and a keyboard of our own stands in for the daemon's.
class ConsoleHost extends StatefulWidget {
  const ConsoleHost({super.key, required this.builder, this.pad});

  final Widget Function(BuildContext context, ConsoleController console)
  builder;

  /// Controller presses (the gamepad). Null: keyboard only.
  final Stream<PadEvent>? pad;

  @override
  State<ConsoleHost> createState() => _ConsoleHostState();
}

class _ConsoleHostState extends State<ConsoleHost> {
  late final _nav = NavController();
  late final ConsoleController _console = ConsoleController(_nav);
  StreamSubscription<PadEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _nav.onBack = () => _console.onBack?.call() ?? false;
    _sub = widget.pad?.listen((e) => _console.action(e.$1, e.$2));
  }

  @override
  void dispose() {
    _sub?.cancel();
    _console.content.dispose();
    super.dispose();
  }

  static NavAction? _actionForKey(LogicalKeyboardKey k) {
    if (k == LogicalKeyboardKey.arrowLeft) return NavAction.left;
    if (k == LogicalKeyboardKey.arrowRight) return NavAction.right;
    if (k == LogicalKeyboardKey.arrowUp) return NavAction.up;
    if (k == LogicalKeyboardKey.arrowDown) return NavAction.down;
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      return NavAction.accept;
    }
    if (k == LogicalKeyboardKey.escape) return NavAction.back;
    if (k == LogicalKeyboardKey.pageUp) return NavAction.pageLeft;
    if (k == LogicalKeyboardKey.pageDown) return NavAction.pageRight;
    if (k == LogicalKeyboardKey.keyY) return NavAction.context;
    if (k == LogicalKeyboardKey.keyX) return NavAction.secondary;
    // Stands in for the View button: cancels the keyboard.
    if (k == LogicalKeyboardKey.f1) return NavAction.view;
    return null;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    final a = _actionForKey(e.logicalKey);
    if (a == null) return KeyEventResult.ignored;
    _console.action(a, switch (e) {
      KeyDownEvent() => NavPhase.press,
      KeyRepeatEvent() => NavPhase.repeat,
      _ => NavPhase.release,
    });
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: t.background,
        body: ModalHost(
          controller: _console.modals,
          child: Builder(builder: (c) => widget.builder(c, _console)),
        ),
      ),
    );
  }
}

/// The `MaterialApp` shared by the console-style apps (installer, first-boot
/// wizard): the launcher's theme and text size, the 1920x1080 design scale.
class ConsoleApp extends StatelessWidget {
  const ConsoleApp({
    super.key,
    required this.settings,
    required this.title,
    required this.home,
  });

  final LauncherSettings settings;
  final String title;
  final Widget home;

  @override
  Widget build(BuildContext context) {
    final tokens = HinterTokens.fromSettings(settings);
    return MaterialApp(
      title: title,
      debugShowCheckedModeBanner: false,
      theme: HinterTheme.material(tokens),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(settings.textScale),
          disableAnimations: settings.reduceMotion,
        ),
        child: HinterTheme(
          tokens: tokens,
          child: DesignScale(child: child!),
        ),
      ),
      home: home,
    );
  }
}
