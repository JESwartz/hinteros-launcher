import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/api.dart' show NavAction, NavPhase;
import '../../app.dart' show DesignScale;
import '../../settings/launcher_settings.dart';
import '../../nav/key_map.dart';
import '../../nav/nav_controller.dart';
import '../../nav/soft_key.dart';
import '../../theme/hinter_theme.dart';
import '../../ui/modal_host.dart';
import '../gamepad.dart';
import '../keyboard_fallback.dart';
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

  /// The on-screen keyboard takes the evdev fallback keys through this.
  final softKeys = SoftKeySink();

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
          softKeys: softKeys,
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
      if (phase == NavPhase.press && a == NavAction.view) {
        kb.onCancel?.call();
      } else if (phase == NavPhase.press && a == NavAction.menu) {
        kb.onDone?.call(kb.text.value);
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
  const ConsoleHost({
    super.key,
    required this.builder,
    this.pad,
    this.keyboard,
  });

  final Widget Function(BuildContext context, ConsoleController console)
  builder;

  /// Controller presses (the gamepad). Null: keyboard only.
  final Stream<PadEvent>? pad;

  /// The evdev keyboard fallback for a window that has no keyboard focus.
  /// Null: Flutter's own key events only.
  final KeyboardFallback? keyboard;

  @override
  State<ConsoleHost> createState() => _ConsoleHostState();
}

class _ConsoleHostState extends State<ConsoleHost> {
  late final _nav = NavController();
  late final ConsoleController _console = ConsoleController(_nav);
  StreamSubscription<PadEvent>? _sub;
  StreamSubscription<SoftKey>? _softSub;
  final _hostFocus = FocusNode(debugLabel: 'console host');

  @override
  void initState() {
    super.initState();
    _nav.onBack = () => _console.onBack?.call() ?? false;
    _sub = widget.pad?.listen((e) => _console.action(e.$1, e.$2));
    _softSub = widget.keyboard?.keys.listen(_onSoftKey);
    widget.keyboard?.addListener(_onFocusChange);
    // Keys must work before any other input: once the first frame is up,
    // make sure something has primary focus (the first row, which the
    // screen focuses itself, else this host).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && FocusManager.instance.primaryFocus == null) {
        _hostFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _softSub?.cancel();
    widget.keyboard?.removeListener(_onFocusChange);
    _hostFocus.dispose();
    _console.content.dispose();
    super.dispose();
  }

  bool _hadFocus = false;

  /// The window got the compositor's keyboard focus (or a first key proved
  /// it has): make sure something is focused, the first row on a fresh
  /// screen, so that Start is highlighted and Enter reaches it.
  void _onFocusChange() {
    final has = widget.keyboard?.hasFocus ?? false;
    if (has && !_hadFocus && mounted && !_console.typing) {
      _console.refocus();
      if (FocusManager.instance.primaryFocus == null) _hostFocus.requestFocus();
    }
    _hadFocus = has;
  }

  /// A key from the evdev fallback, handled like the same key from Flutter.
  void _onSoftKey(SoftKey k) {
    if (!mounted) return;
    if (_console.typing && _console.softKeys.handler?.call(k) == true) return;
    if (k.key == LogicalKeyboardKey.tab) {
      if (k.phase == NavPhase.release) return;
      if (_console.typing) {
        _console.action(
          k.shift ? NavAction.left : NavAction.right,
          NavPhase.press,
        );
      } else if (k.shift) {
        FocusManager.instance.primaryFocus?.previousFocus();
      } else {
        FocusManager.instance.primaryFocus?.nextFocus();
      }
      return;
    }
    final a = navActionForKey(k.key, view: true, inTextField: false);
    if (a != null) _console.action(a, k.phase);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e.logicalKey == LogicalKeyboardKey.tab) {
      if (e is KeyUpEvent) return KeyEventResult.handled;
      final back = HardwareKeyboard.instance.isShiftPressed;
      if (_console.typing) {
        // The on-screen keyboard has no focus order of its own: step along it.
        _console.action(
          back ? NavAction.left : NavAction.right,
          NavPhase.press,
        );
      } else if (back) {
        FocusManager.instance.primaryFocus?.previousFocus();
      } else {
        FocusManager.instance.primaryFocus?.nextFocus();
      }
      return KeyEventResult.handled;
    }
    // F1 stands in for the View button (cancels the on-screen keyboard).
    final a = navActionForKey(e.logicalKey, view: true);
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
      focusNode: _hostFocus,
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
    this.hideCursor = true,
  });

  final LauncherSettings settings;
  final String title;
  final Widget home;

  /// Console mode: no mouse pointer (Flutter sets the cursor to `none`, which
  /// the GTK runner also blanks natively).
  final bool hideCursor;

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
      home: hideCursor
          ? MouseRegion(cursor: SystemMouseCursors.none, child: home)
          : home,
    );
  }
}
