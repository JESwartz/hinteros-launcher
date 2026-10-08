import 'dart:async';

import 'package:flutter/material.dart';

import '../nav/nav_controller.dart';
import '../nav/nav_model.dart';
import '../osk/osk_control.dart';
import '../theme/hinter_theme.dart';
import 'focus_frame.dart';
import 'modal_host.dart';
import 'nav_focusable.dart';
import 'widgets.dart';

/// A modal card over a dimmed screen. Content goes in [children].
class DialogCard extends StatelessWidget {
  const DialogCard({
    super.key,
    required this.title,
    required this.children,
    this.maxWidth = 960,
  });

  final String title;
  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: 960),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(HinterTokens.radiusCard),
              border: Border.all(
                color: t.highContrast ? t.text : t.surfaceHigh,
                width: t.highContrast ? 3 : 2,
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(HinterTokens.s5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.title),
                  const SizedBox(height: HinterTokens.s2),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A button row inside a dialog's [region]: [labels] side by side, the first
/// focused first (so a stray accept takes the safe choice).
class DialogButtons extends StatelessWidget {
  const DialogButtons({
    super.key,
    required this.region,
    required this.rowKey,
    required this.buttons,
  });

  final NavRegion region;
  final String rowKey;
  final List<
    ({
      String label,
      VoidCallback? onSelect,
      bool primary,
      bool enabled,
      bool danger,
    })
  >
  buttons;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: HinterTokens.s3,
      runSpacing: HinterTokens.s2,
      children: [
        for (var i = 0; i < buttons.length; i++)
          NavFocusable(
            region: region,
            rowKey: rowKey,
            col: i,
            scrollIntoView: false,
            onSelect: buttons[i].enabled ? buttons[i].onSelect : null,
            builder: (_, f) => HButton(
              label: buttons[i].label,
              focused: f,
              primary: buttons[i].primary,
              enabled: buttons[i].enabled,
              danger: buttons[i].danger,
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------ confirm

/// The answer of a confirmed [showConfirm]: whether the optional check box was
/// ticked.
class ConfirmResult {
  const ConfirmResult({this.checked = false});
  final bool checked;
}

/// Asks to confirm something. Null: cancelled (the safe choice is focused
/// first and Back cancels). With [checkbox], an option to tick comes first.
Future<ConfirmResult?> showConfirm(
  BuildContext context, {
  required String title,
  String? body,
  List<Widget> extra = const [],
  String confirmLabel = 'OK',
  String cancelLabel = 'Cancel',
  bool danger = false,
  bool showCancel = true,
  String? checkbox,
  String? checkboxHint,
}) => ModalScope.of(context).show<ConfirmResult>(
  (context, modal) => _ConfirmDialog(
    modal: modal,
    title: title,
    body: body,
    extra: extra,
    confirmLabel: confirmLabel,
    cancelLabel: cancelLabel,
    danger: danger,
    showCancel: showCancel,
    checkbox: checkbox,
    checkboxHint: checkboxHint,
  ),
);

class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({
    required this.modal,
    required this.title,
    required this.body,
    required this.extra,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.danger,
    required this.showCancel,
    required this.checkbox,
    required this.checkboxHint,
  });

  final ModalHandle<ConfirmResult> modal;
  final String title;
  final String? body;
  final List<Widget> extra;
  final String confirmLabel;
  final String cancelLabel;
  final bool danger;
  final bool showCancel;
  final String? checkbox;
  final String? checkboxHint;

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  bool _checked = false;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final region = widget.modal.region;
    region.setRows([
      if (widget.checkbox != null) const NavRow('check', 1),
      NavRow('buttons', widget.showCancel ? 2 : 1),
    ]);
    return DialogCard(
      title: widget.title,
      children: [
        if (widget.body != null) Text(widget.body!, style: t.bodyDim),
        for (final e in widget.extra) ...[
          const SizedBox(height: HinterTokens.s2),
          e,
        ],
        if (widget.checkbox != null) ...[
          const SizedBox(height: HinterTokens.s3),
          NavFocusable(
            region: region,
            rowKey: 'check',
            col: 0,
            scrollIntoView: false,
            onSelect: () => setState(() => _checked = !_checked),
            builder: (_, f) => SettingRow(
              title: widget.checkbox!,
              subtitle: widget.checkboxHint,
              focused: f,
              leading: CheckMark(checked: _checked),
            ),
          ),
        ],
        const SizedBox(height: HinterTokens.s4),
        DialogButtons(
          region: region,
          rowKey: 'buttons',
          buttons: [
            if (widget.showCancel) btn(widget.cancelLabel, widget.modal.close),
            btn(
              widget.confirmLabel,
              () => widget.modal.close(ConfirmResult(checked: _checked)),
              primary: true,
              danger: widget.danger,
            ),
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ choice

/// One option of [showChoice].
class Choice<T> {
  const Choice(this.label, this.value, {this.danger = false});

  final String label;
  final T value;
  final bool danger;
}

/// A short list of actions on something ("Disconnect", "Forget"), plus Cancel.
/// Null: cancelled.
Future<T?> showChoice<T>(
  BuildContext context, {
  required String title,
  String? body,
  required List<Choice<T>> choices,
}) => ModalScope.of(context).show<T>(
  (context, modal) => _ChoiceDialog<T>(
    modal: modal,
    title: title,
    body: body,
    choices: choices,
  ),
);

class _ChoiceDialog<T> extends StatelessWidget {
  const _ChoiceDialog({
    required this.modal,
    required this.title,
    required this.body,
    required this.choices,
  });

  final ModalHandle<T> modal;
  final String title;
  final String? body;
  final List<Choice<T>> choices;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    modal.region.setRows([
      for (var i = 0; i < choices.length; i++) NavRow('c$i', 1),
      const NavRow('cancel', 1),
    ]);
    return DialogCard(
      title: title,
      maxWidth: 760,
      children: [
        if (body != null) Text(body!, style: t.bodyDim),
        const SizedBox(height: HinterTokens.s3),
        for (var i = 0; i < choices.length; i++) ...[
          NavFocusable(
            region: modal.region,
            rowKey: 'c$i',
            col: 0,
            scrollIntoView: false,
            onSelect: () => modal.close(choices[i].value),
            builder: (_, f) => SettingRow(
              title: choices[i].label,
              focused: f,
              danger: choices[i].danger,
            ),
          ),
          const SizedBox(height: HinterTokens.s1 + 4),
        ],
        NavFocusable(
          region: modal.region,
          rowKey: 'cancel',
          col: 0,
          scrollIntoView: false,
          onSelect: modal.close,
          builder: (_, f) => SettingRow(title: 'Cancel', focused: f, dim: true),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ text entry

/// A text field that takes its focus node from a [NavRegion] row, so the nav
/// layer moves focus in and out of it like any item. Typed text reaches it
/// from the daemon's on-screen keyboard (keys typed through the compositor);
/// on the desktop the real keyboard works too. The keyboard opens by itself
/// when the field gains focus (`osk.show`) and closes when focus leaves it or
/// the text is submitted (`osk.hide`). Accept (Enter) calls [onSubmit].
class NavTextField extends StatefulWidget {
  const NavTextField({
    super.key,
    required this.region,
    required this.rowKey,
    required this.controller,
    this.obscure = false,
    this.hint = '',
    this.onSubmit,
  });

  final NavRegion region;
  final String rowKey;
  final TextEditingController controller;
  final bool obscure;
  final String hint;
  final VoidCallback? onSubmit;

  @override
  State<NavTextField> createState() => _NavTextFieldState();
}

class _NavTextFieldState extends State<NavTextField> {
  late final FocusNode _node = widget.region.nodeAt(widget.rowKey, 0);
  bool _focused = false;
  OskControl? _osk;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _osk = OskScope.maybeOf(context);
    // The field may already have focus when the scope is first found.
    if (_node.hasFocus) _osk?.fieldFocused(this);
  }

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocus);
    widget.region.registerSelect(widget.rowKey, 0, _submit);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.region.itemBuilt(widget.rowKey, 0);
    });
  }

  void _submit() {
    _osk?.submitted(this);
    widget.onSubmit?.call();
  }

  void _onFocus() {
    if (_node.hasFocus) {
      widget.region.noteFocused(widget.rowKey, 0);
      _osk?.fieldFocused(this);
    } else {
      _osk?.fieldLeft(this);
    }
    if (mounted && _focused != _node.hasFocus) {
      setState(() => _focused = _node.hasFocus);
    }
  }

  @override
  void dispose() {
    _node.removeListener(_onFocus);
    _osk?.fieldLeft(this);
    widget.region.unregisterSelect(widget.rowKey, 0);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return FocusFrame(
      focused: _focused,
      radius: HinterTokens.radiusSmall,
      scale: 1.0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.background,
          borderRadius: BorderRadius.circular(HinterTokens.radiusSmall),
          border: Border.all(color: t.textDim, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HinterTokens.s3,
            vertical: HinterTokens.s2,
          ),
          child: TextField(
            focusNode: _node,
            controller: widget.controller,
            obscureText: widget.obscure,
            autocorrect: false,
            enableSuggestions: false,
            enableInteractiveSelection: false,
            style: t.label.copyWith(fontWeight: FontWeight.w400),
            cursorColor: t.accent,
            cursorWidth: 3,
            decoration: InputDecoration.collapsed(
              hintText: widget.hint,
              hintStyle: t.label.copyWith(
                fontWeight: FontWeight.w400,
                color: t.textDim.withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks for a line of text. [submit] runs on "OK"/Enter with the text and
/// returns an error message to show (the dialog stays open, so a wrong
/// password can be retried) or null when it worked (the dialog closes with
/// the text). Null result: cancelled. [enterSubmits] false: Enter (the
/// on-screen keyboard's too) only closes the keyboard and moves to the
/// submit button; the person still chooses it or Cancel.
Future<String?> showTextEntry(
  BuildContext context, {
  required String title,
  String? body,
  String hint = '',
  bool secret = false,
  String initial = '',
  String submitLabel = 'OK',
  Future<String?> Function(String text)? submit,
  Widget? extra,
  bool enterSubmits = true,
}) => ModalScope.of(context).show<String>(
  (context, modal) => _TextEntryDialog(
    enterSubmits: enterSubmits,
    modal: modal,
    title: title,
    body: body,
    hint: hint,
    secret: secret,
    initial: initial,
    submitLabel: submitLabel,
    submit: submit,
    extra: extra,
  ),
);

class _TextEntryDialog extends StatefulWidget {
  const _TextEntryDialog({
    required this.enterSubmits,
    required this.modal,
    required this.title,
    required this.body,
    required this.hint,
    required this.secret,
    required this.initial,
    required this.submitLabel,
    required this.submit,
    required this.extra,
  });

  final ModalHandle<String> modal;
  final String title;
  final String? body;
  final String hint;
  final bool secret;
  final String initial;
  final String submitLabel;
  final Future<String?> Function(String text)? submit;
  final Widget? extra;
  final bool enterSubmits;

  @override
  State<_TextEntryDialog> createState() => _TextEntryDialogState();
}

class _TextEntryDialogState extends State<_TextEntryDialog> {
  late final _text = TextEditingController(text: widget.initial);
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
    final value = _text.text;
    final fn = widget.submit;
    if (fn == null) {
      widget.modal.close(value);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await fn(value);
    if (!mounted) return;
    if (err == null) {
      widget.modal.close(value);
    } else {
      // The text was submitted (keyboard hidden) but the field is still
      // there to retry in.
      OskScope.maybeOf(context)?.reshow();
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final region = widget.modal.region;
    region.setRows([
      const NavRow('field', 1),
      if (widget.secret) const NavRow('reveal', 1),
      const NavRow('buttons', 2),
    ]);
    return DialogCard(
      title: widget.title,
      children: [
        if (widget.body != null) Text(widget.body!, style: t.bodyDim),
        if (widget.extra != null) ...[
          const SizedBox(height: HinterTokens.s2),
          widget.extra!,
        ],
        const SizedBox(height: HinterTokens.s3),
        NavTextField(
          region: region,
          rowKey: 'field',
          controller: _text,
          obscure: widget.secret && !_reveal,
          hint: widget.hint,
          onSubmit: widget.enterSubmits
              ? _submit
              : () {
                  region.model.goTo(widget.secret ? 2 : 1, 1);
                  region.changed();
                  unawaited(region.focusCurrent());
                },
        ),
        if (widget.secret) ...[
          const SizedBox(height: HinterTokens.s2),
          NavFocusable(
            region: region,
            rowKey: 'reveal',
            col: 0,
            scrollIntoView: false,
            onSelect: () => setState(() => _reveal = !_reveal),
            builder: (_, f) => SettingRow(
              title: 'Show what I type',
              focused: f,
              leading: CheckMark(checked: _reveal),
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: HinterTokens.s2),
          StatusLine(_error!, error: true),
        ],
        if (_busy) ...[
          const SizedBox(height: HinterTokens.s2),
          const StatusLine('Working...'),
        ],
        const SizedBox(height: HinterTokens.s4),
        DialogButtons(
          region: region,
          rowKey: 'buttons',
          buttons: [
            btn('Cancel', widget.modal.close),
            btn(widget.submitLabel, _submit, primary: true, enabled: !_busy),
          ],
        ),
      ],
    );
  }
}

/// Tells the user something, with one OK button.
Future<void> showMessage(
  BuildContext context, {
  required String title,
  required String body,
}) async {
  await showConfirm(context, title: title, body: body, showCancel: false);
}

/// A failure on screen: [body] says what went wrong, [detail] (an error code
/// and message) goes below it in small type. [modals] is the shell's own
/// controller, for failures that arrive outside any widget's context.
Future<void> showFailureOn(
  ModalController modals, {
  required String title,
  required String body,
  String? detail,
}) async {
  await modals.show<ConfirmResult>(
    (context, modal) => _ConfirmDialog(
      modal: modal,
      title: title,
      body: body,
      extra: [
        if (detail != null)
          Builder(
            builder: (c) => Text(detail, style: HinterTheme.of(c).caption),
          ),
      ],
      confirmLabel: 'OK',
      cancelLabel: 'Cancel',
      danger: false,
      showCancel: false,
      checkbox: null,
      checkboxHint: null,
    ),
  );
}
