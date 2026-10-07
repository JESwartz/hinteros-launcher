import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/api.dart' hide Key;
import '../../api/api.dart' as api show Key;
import '../../osk/osk_backend.dart';
import '../../osk/osk_screen.dart';
import '../../osk/osk_state.dart' show oskMaskChar;
import '../../theme/hinter_theme.dart';
import '../../ui/pages.dart';

/// The on-screen keyboard's backend for a keyboard that lives in this
/// process: on the ISO there is no session daemon to type for us, so the
/// keys go into [text] instead. The layouts and widgets are the ones of the
/// daemon-backed keyboard ([OskScreen]).
class InProcessKeyboard implements OskBackend {
  InProcessKeyboard(String initial, {this.maxLength = 128})
    : text = ValueNotifier(initial);

  /// What has been typed (the field's value).
  final ValueNotifier<String> text;
  final int maxLength;

  /// Done or Enter: the person is finished.
  void Function(String text)? onDone;

  /// The View button: throw the edit away.
  VoidCallback? onCancel;

  final _nav = StreamController<InputNavEvent>.broadcast();
  final _visibility = StreamController<bool>.broadcast();

  /// Controller input for the keyboard (the host sends it while it is up).
  void emitNav(NavAction action, NavPhase phase) =>
      _nav.add(InputNavEvent(action: action, phase: phase));

  @override
  Stream<InputNavEvent> get nav => _nav.stream;

  @override
  Stream<bool> get visibility => _visibility.stream;

  @override
  Future<List<String>> type(String s) async {
    if (text.value.runes.length + s.runes.length <= maxLength) {
      text.value += s;
    }
    return const [];
  }

  @override
  Future<void> action(OskAction a) async {
    switch (a) {
      case OskAction.backspace:
        final r = text.value.runes.toList();
        if (r.isNotEmpty) text.value = String.fromCharCodes(r..removeLast());
      case OskAction.enter:
        onDone?.call(text.value);
      case OskAction.tab:
        break;
    }
  }

  @override
  Future<void> key(api.Key key, {List<Modifier> modifiers = const []}) async {}

  @override
  Future<void> hide() async => onDone?.call(text.value);

  @override
  Future<void> dispose() async {
    await _nav.close();
    await _visibility.close();
    text.dispose();
  }
}

/// A full-screen page with the field being edited at the top and the
/// keyboard docked at the bottom.
class TextEntryScreen extends StatelessWidget {
  const TextEntryScreen({
    super.key,
    required this.keyboard,
    required this.title,
    required this.secret,
    this.hint,
  });

  final InProcessKeyboard keyboard;
  final String title;
  final bool secret;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return Stack(
      children: [
        FullPage(
          title: title,
          subtitle: hint,
          child: Align(
            alignment: Alignment.topLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ValueListenableBuilder<String>(
                  valueListenable: keyboard.text,
                  builder: (context, v, _) => Container(
                    key: const ValueKey('text-field'),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: HinterTokens.s3,
                      vertical: HinterTokens.s2,
                    ),
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(
                        HinterTokens.radiusSmall,
                      ),
                      border: Border.all(color: t.accent, width: 3),
                    ),
                    child: Text(
                      secret ? oskMaskChar * v.runes.length : v,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.title,
                    ),
                  ),
                ),
                const SizedBox(height: HinterTokens.s2),
                Text(
                  secret
                      ? 'Characters are hidden. Done saves; View cancels.'
                      : 'Done saves; View cancels.',
                  style: t.caption,
                ),
              ],
            ),
          ),
        ),
        OskScreen(
          backend: keyboard,
          showTyped: !secret,
          initialText: keyboard.text.value,
        ),
      ],
    );
  }
}
