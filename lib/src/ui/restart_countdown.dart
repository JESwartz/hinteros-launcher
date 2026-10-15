import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../nav/nav_model.dart';
import '../theme/hinter_theme.dart';
import 'dialogs.dart';
import 'modal_host.dart';
import 'widgets.dart';

/// How long the restart offer waits before it restarts the session.
const restartCountdown = 30;

/// Whether the launcher is in front (no app has focus, none is starting).
/// The shell gives it; without one the launcher counts as in front.
class FrontScope extends InheritedNotifier<ValueListenable<bool>> {
  const FrontScope({
    super.key,
    required ValueListenable<bool> inFront,
    required super.child,
  }) : super(notifier: inFront);

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<FrontScope>()
          ?.notifier
          ?.value ??
      true;
}

/// "The session restarts in 30 seconds.", counting down once a second
/// while the launcher is in front, then [onEnd]. When an app comes to the
/// front it stops (and shows nothing); back in front it starts again from
/// [restartCountdown]. Taking it out of the tree cancels it.
class RestartCountdown extends StatefulWidget {
  const RestartCountdown({super.key, required this.onEnd});

  final VoidCallback onEnd;

  @override
  State<RestartCountdown> createState() => _RestartCountdownState();
}

class _RestartCountdownState extends State<RestartCountdown> {
  Timer? _timer;
  int? _left;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!FrontScope.of(context)) {
      _stop();
    } else if (_timer == null) {
      _left = restartCountdown;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  void _tick() {
    if (!mounted) return;
    final left = _left! - 1;
    if (left > 0) {
      setState(() => _left = left);
      return;
    }
    _stop();
    widget.onEnd();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _left = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = _left;
    if (left == null) return const SizedBox.shrink();
    return Text(
      'The session restarts in $left ${left == 1 ? 'second' : 'seconds'}.',
      key: const ValueKey('restart-countdown'),
      style: HinterTheme.of(context).label,
    );
  }
}

/// A job the person left needs a new session: [title], what to do, the
/// countdown, "Later" (focused first, and Back) and "Restart session".
/// True: restart now (chosen, or the countdown ended).
Future<bool> showRestartOffer(BuildContext context, {required String title}) =>
    ModalScope.of(context)
        .show<bool>(
          (context, modal) => _RestartOffer(modal: modal, title: title),
        )
        .then((r) => r ?? false);

class _RestartOffer extends StatelessWidget {
  const _RestartOffer({required this.modal, required this.title});

  final ModalHandle<bool> modal;
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final region = modal.region;
    region.setRows([const NavRow('buttons', 2)]);
    return DialogCard(
      title: title,
      children: [
        Text(
          'Restart the session to use the change. Open games and apps close.',
          style: t.bodyDim,
        ),
        const SizedBox(height: HinterTokens.s2),
        RestartCountdown(onEnd: () => modal.close(true)),
        const SizedBox(height: HinterTokens.s4),
        DialogButtons(
          region: region,
          rowKey: 'buttons',
          buttons: [
            btn('Later', modal.close),
            btn('Restart session', () => modal.close(true), primary: true),
          ],
        ),
      ],
    );
  }
}
