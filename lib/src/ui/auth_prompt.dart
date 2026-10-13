import 'dart:async';

import 'package:flutter/material.dart';

import '../nav/nav_model.dart';
import '../osk/osk_control.dart';
import '../system/models.dart';
import '../system/repositories.dart';
import '../theme/hinter_theme.dart';
import 'dialogs.dart';
import 'modal_host.dart';
import 'nav_focusable.dart';
import 'widgets.dart';

/// What the action is for, in the words of the sentence "Enter the password
/// for `account` to ...". Null for an action the launcher does not know: the
/// dialog then shows polkit's own message.
String? authPurpose(String action) => switch (action) {
  'org.hinteros.system.ssh' => 'turn on SSH',
  _ => null,
};

/// Shows the admin password prompt whenever polkit asks for it
/// (`authentication_requested`) and closes it when the request is over
/// (`authentication_finished`). Back or Cancel answers with `auth.cancel`.
///
/// The password only ever goes from the field to [AuthRepository.respond]:
/// the field is emptied the moment it is read, nothing is logged, and no
/// object here holds it.
class AuthPrompter {
  AuthPrompter(this.auth, this.modals) {
    _subs.add(auth.requests.listen(_onRequest));
    _subs.add(auth.finished.listen(_onFinished));
  }

  final AuthRepository auth;
  final ModalController modals;
  final _subs = <StreamSubscription<Object?>>[];
  final _open = <String, ModalHandle<bool>>{};
  final _over = <String>{};

  void _onRequest(AuthRequest r) {
    if (_open.containsKey(r.cookie)) return;
    _over.remove(r.cookie);
    final opened = modals.open<bool>(
      (context, modal) =>
          AuthPromptDialog(modal: modal, request: r, auth: auth),
    );
    _open[r.cookie] = opened.handle;
    unawaited(
      opened.result.then((answered) {
        _open.remove(r.cookie);
        // Closed by the user (Back, Cancel) while polkit still waits: say no.
        if (answered != true && !_over.remove(r.cookie)) {
          unawaited(auth.cancel(r.cookie));
        }
      }),
    );
  }

  void _onFinished(AuthFinished f) {
    final h = _open[f.cookie];
    if (h == null) return;
    _over.add(f.cookie);
    h.close(f.outcome == AuthOutcome.authorized);
  }

  void dispose() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
  }
}

/// The password dialog: what polkit wants it for, whose password, a masked
/// field (the on-screen keyboard opens with it), and what is left to try.
class AuthPromptDialog extends StatefulWidget {
  const AuthPromptDialog({
    super.key,
    required this.modal,
    required this.request,
    required this.auth,
  });

  /// Closes with true once the password was accepted, else null.
  final ModalHandle<bool> modal;
  final AuthRequest request;
  final AuthRepository auth;

  @override
  State<AuthPromptDialog> createState() => _AuthPromptDialogState();
}

class _AuthPromptDialogState extends State<AuthPromptDialog> {
  final _text = TextEditingController();
  bool _reveal = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_text.text.isEmpty) {
      setState(() => _error = 'Type the password first.');
      return;
    }
    // Read it, and empty the field at once: from here the password is only
    // the argument of the call.
    final password = _text.text;
    _text.clear();
    setState(() {
      _busy = true;
      _error = null;
      _reveal = false;
    });
    final AuthAnswer answer;
    try {
      answer = await widget.auth.respond(widget.request.cookie, password);
    } on SystemException catch (e) {
      if (!mounted) return;
      if (e.kind == SystemErrorKind.notFound) {
        // Over already (timed out, cancelled elsewhere).
        widget.modal.close();
        return;
      }
      _again(e.message);
      return;
    }
    if (!mounted) return;
    if (answer.ok) {
      widget.modal.close(true);
    } else if (answer.attemptsLeft > 0) {
      _again(
        'Wrong password. '
        '${answer.attemptsLeft == 1 ? '1 try' : '${answer.attemptsLeft} tries'}'
        ' left.',
      );
    } else {
      // Out of tries: the request fails and `authentication_finished`
      // closes this.
      setState(() {
        _busy = true;
        _error = 'Wrong password. No tries left.';
      });
    }
  }

  void _again(String error) {
    // The text went out (keyboard hidden); the field is still there to retry.
    OskScope.maybeOf(context)?.reshow();
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final region = widget.modal.region;
    final r = widget.request;
    final purpose = authPurpose(r.action);
    region.setRows(const [
      NavRow('field', 1),
      NavRow('reveal', 1),
      NavRow('buttons', 2),
    ]);
    return DialogCard(
      title: 'Admin password',
      children: [
        Text(
          purpose == null
              ? 'Enter the password for ${r.account}.'
              : 'Enter the password for ${r.account} to $purpose.',
          style: t.body,
        ),
        if (purpose == null && r.message.isNotEmpty) ...[
          const SizedBox(height: HinterTokens.s1),
          Text(r.message, style: t.bodyDim),
        ],
        const SizedBox(height: HinterTokens.s3),
        NavTextField(
          region: region,
          rowKey: 'field',
          controller: _text,
          obscure: !_reveal,
          hint: 'Password',
          onSubmit: _submit,
        ),
        const SizedBox(height: HinterTokens.s2),
        NavFocusable(
          region: region,
          rowKey: 'reveal',
          col: 0,
          scrollIntoView: false,
          onSelect: () => setState(() => _reveal = !_reveal),
          builder: (_, f) => SettingRow(
            title: 'Show password',
            focused: f,
            leading: CheckMark(checked: _reveal),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: HinterTokens.s2),
          StatusLine(_error!, error: true),
        ],
        if (_busy && _error == null) ...[
          const SizedBox(height: HinterTokens.s2),
          const StatusLine('Checking...'),
        ],
        const SizedBox(height: HinterTokens.s4),
        DialogButtons(
          region: region,
          rowKey: 'buttons',
          buttons: [
            btn('Cancel', widget.modal.close),
            btn('Submit', _submit, primary: true, enabled: !_busy),
          ],
        ),
      ],
    );
  }
}
