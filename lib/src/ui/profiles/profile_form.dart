/// Creating a profile, step by step on one page: name and colour, PIN
/// (twice), "Lock this profile". The same page serves the picker's Add profile,
/// Settings -> Profiles -> Add profile and first-boot mode's "Create your
/// profile" (with the admin wording), and then the "Getting things ready"
/// page follows a create job.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../nav/nav_controller.dart';
import '../../nav/nav_model.dart';
import '../../system/models.dart';
import '../../system/profiles.dart';
import '../../system/repositories.dart' show JobsRepository;
import '../../theme/hinter_theme.dart';
import '../focus_frame.dart';
import '../modal_host.dart';
import '../nav_focusable.dart';
import '../pages.dart' show FullPage;
import '../widgets.dart';
import 'profile_ui.dart';

/// What the form collected.
class ProfileFormResult {
  const ProfileFormResult({
    required this.name,
    required this.color,
    required this.pin,
    required this.locked,
  });

  final String name;
  final ProfileColor color;
  final String pin;
  final bool locked;
}

/// Asks for a line of text (the profile's name): the session's dialog with
/// the daemon's keyboard, or the picker's own keyboard. Null: cancelled.
typedef EditText = Future<String?> Function({
  required String title,
  required String initial,
  String? hint,
});

enum _Step { name, pin, pinAgain, lock }

/// Shows the form. [admin]: first-boot mode's wording. [taken]: names
/// already on the box (a duplicate is allowed, with a note). Null:
/// cancelled with Back on the first step.
Future<ProfileFormResult?> showProfileForm(
  BuildContext context, {
  required EditText editText,
  bool admin = false,
  List<String> taken = const [],
  ProfileColor? suggestedColor,
}) => ModalScope.of(context).show<ProfileFormResult>(
  (context, modal) => ProfileFormPage(
    modal: modal,
    editText: editText,
    admin: admin,
    taken: taken,
    suggestedColor: suggestedColor,
  ),
);

class ProfileFormPage extends StatefulWidget {
  const ProfileFormPage({
    super.key,
    required this.modal,
    required this.editText,
    this.admin = false,
    this.taken = const [],
    this.suggestedColor,
    this.initialName = '',
  });

  final ModalHandle<ProfileFormResult> modal;
  final EditText editText;
  final bool admin;
  final List<String> taken;
  final ProfileColor? suggestedColor;
  final String initialName;

  @override
  State<ProfileFormPage> createState() => _ProfileFormPageState();
}

class _ProfileFormPageState extends State<ProfileFormPage> {
  _Step _step = _Step.name;
  late String _name = widget.initialName;
  late ProfileColor _color = widget.suggestedColor ?? _firstFree();
  final _pin = PinController();
  String _firstPin = '';
  bool _locked = false;
  String? _error;

  NavRegion get _region => widget.modal.region;

  ProfileColor _firstFree() => ProfileColor.values.first;

  @override
  void initState() {
    super.initState();
    _region.onBack = _back;
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  bool _back() {
    if (_step == _Step.pin || _step == _Step.pinAgain) {
      if (_pin.delete()) return true;
    }
    if (_step == _Step.name) {
      widget.modal.close();
      return true;
    }
    _go(_Step.values[_step.index - 1]);
    return true;
  }

  void _go(_Step s) {
    setState(() {
      _step = s;
      _error = null;
      if (s == _Step.pin) {
        _pin.clear();
        _firstPin = '';
      }
      if (s == _Step.pinAgain) _pin.clear();
    });
    _region.reset();
    // A new step's items are built this frame; focus the first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_region.focusCurrent());
    });
  }

  Future<void> _editName() async {
    final v = await widget.editText(
      title: widget.admin ? 'Your name' : 'Name of the profile',
      initial: _name,
      hint: '1 to 32 characters.',
    );
    if (v == null || !mounted) return;
    setState(() {
      _name = v.trim();
      _error = nameProblem(_name);
    });
  }

  void _nameNext() {
    final p = nameProblem(_name);
    if (p != null) {
      setState(() => _error = p);
      return;
    }
    _go(_Step.pin);
  }

  void _pinNext() {
    if (!validPin(_pin.pin)) return;
    if (_step == _Step.pin) {
      _firstPin = _pin.pin;
      _go(_Step.pinAgain);
      return;
    }
    if (_pin.pin != _firstPin) {
      _go(_Step.pin);
      setState(() => _error = "The PINs don't match. Try again.");
      return;
    }
    _go(_Step.lock);
  }

  void _finish() => widget.modal.close(
    ProfileFormResult(
      name: _name.trim(),
      color: _color,
      pin: _firstPin,
      locked: _locked,
    ),
  );

  String get _initial => _name.trim().isEmpty
      ? '?'
      : String.fromCharCode(_name.trim().runes.first).toUpperCase();

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final title = widget.admin ? 'Create your profile' : 'Add profile';
    final stepText = 'Step ${_step.index + 1} of ${_Step.values.length}';
    final avatar = ProfileAvatar(
      initial: _initial,
      color: _color,
      locked: _locked,
      size: 200,
    );
    final Widget body;
    switch (_step) {
      case _Step.name:
        _region.setRows([
          const NavRow('name', 1),
          NavRow('colors', ProfileColor.values.length),
          const NavRow('next', 1),
        ]);
        final dup = widget.taken.any(
          (n) => n.trim().toLowerCase() == _name.trim().toLowerCase(),
        );
        body = _column([
          if (widget.admin)
            Text(
              'This is the admin profile. Its PIN is needed to manage other '
              'profiles and this box.',
              style: t.body,
            ),
          Text('What should the profile be called?', style: t.title),
          NavFocusable(
            region: _region,
            rowKey: 'name',
            col: 0,
            scrollIntoView: false,
            onSelect: () => unawaited(_editName()),
            builder: (_, f) => SettingRow(
              title: _name.isEmpty ? 'Choose a name' : _name,
              focused: f,
              dim: _name.isEmpty,
            ),
          ),
          if (_error != null) StatusLine(_error!, error: true),
          if (_error == null && dup)
            const StatusLine('Another profile has this name.'),
          Text('Pick a colour', style: t.label),
          Wrap(
            spacing: HinterTokens.s2,
            runSpacing: HinterTokens.s2,
            children: [
              for (var i = 0; i < ProfileColor.values.length; i++)
                NavFocusable(
                  region: _region,
                  rowKey: 'colors',
                  col: i,
                  scrollIntoView: false,
                  onFocused: () =>
                      setState(() => _color = ProfileColor.values[i]),
                  onSelect: _nameNext,
                  builder: (_, f) => _Swatch(
                    color: ProfileColor.values[i],
                    focused: f,
                    selected: _color == ProfileColor.values[i],
                  ),
                ),
            ],
          ),
          Text(_color.label, style: t.bodyDim),
          _buttons('next', [btn('Continue', _nameNext, primary: true)]),
        ]);
      case _Step.pin:
      case _Step.pinAgain:
        _region.setRows(PinPad.rows);
        body = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _column([
                Text(
                  _step == _Step.pin
                      ? 'Choose a PIN for $_name: 4 to 8 digits.'
                      : 'Type the PIN again.',
                  style: t.title,
                ),
                if (_error != null) StatusLine(_error!, error: true),
                Text(pinDisclaimer, style: t.bodyDim),
                if (widget.admin)
                  Text(
                    'If you forget the admin PIN, reset it with the admin '
                    "account's password.",
                    style: t.caption,
                  ),
              ]),
            ),
            const SizedBox(width: HinterTokens.s5),
            PinPad(
              region: _region,
              controller: _pin,
              submitLabel: 'Next',
              onSubmit: _pinNext,
            ),
          ],
        );
        // The pad set the region's Back to its own; deleting then going
        // back a step is ours.
        _region.onBack = _back;
      case _Step.lock:
        _region.setRows([const NavRow('lock', 1), const NavRow('next', 1)]);
        body = _column([
          Text('Should $_name\'s profile ask for the PIN?', style: t.title),
          NavFocusable(
            region: _region,
            rowKey: 'lock',
            col: 0,
            scrollIntoView: false,
            onSelect: () => setState(() => _locked = !_locked),
            builder: (_, f) => SettingRow(
              title: 'Lock this profile',
              focused: f,
              trailing: ToggleMark(on: _locked),
            ),
          ),
          Text(
            'Changing or removing the profile always needs the PIN.',
            style: t.bodyDim,
          ),
          _buttons('next', [
            btn(
              widget.admin ? 'Create my profile' : 'Create profile',
              _finish,
              primary: true,
            ),
          ]),
        ]);
    }
    return FullPage(
      title: title,
      subtitle: stepText,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          avatar,
          const SizedBox(width: HinterTokens.s5),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _column(List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(height: HinterTokens.s3),
        children[i],
      ],
    ],
  );

  Widget _buttons(
    String key,
    List<
      ({
        String label,
        VoidCallback? onSelect,
        bool primary,
        bool enabled,
        bool danger,
      })
    >
    b,
  ) => DialogButtonsRow(region: _region, rowKey: key, buttons: b);
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.focused,
    required this.selected,
  });

  final ProfileColor color;
  final bool focused;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return FocusFrame(
      focused: focused,
      radius: HinterTokens.radiusPill,
      scale: 1.1,
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: profileColor(color),
          border: Border.all(
            color: selected ? t.text : t.background,
            width: selected ? 6 : 2,
          ),
        ),
        child: Semantics(label: color.label),
      ),
    );
  }
}

// ---------------------------------------------------------------- progress

/// Follows a profile job on the "Getting things ready" page (creating an
/// account is a rebuild of about a minute; removing one is a job too).
/// Resolves with whether it finished well. Back works only once it is over.
Future<bool> showProfileJob(
  BuildContext context, {
  required JobsRepository jobs,
  required JobHandle job,
  required String what,
  String title = 'Getting things ready',
  ValueChanged<JobSnapshot>? onFinished,
}) async {
  final r = await ModalScope.of(context).show<bool>(
    (context, modal) => ProfileJobPage(
      modal: modal,
      jobs: jobs,
      job: job,
      title: title,
      what: what,
      onFinished: onFinished,
    ),
  );
  return r ?? false;
}

class ProfileJobPage extends StatefulWidget {
  const ProfileJobPage({
    super.key,
    required this.modal,
    required this.jobs,
    required this.job,
    required this.what,
    this.title = 'Getting things ready',
    this.onFinished,
  });

  final ModalHandle<bool> modal;
  final JobsRepository jobs;
  final JobHandle job;

  /// "Creating Sam's profile... (about a minute)".
  final String what;
  final String title;

  /// The job finished (`job_finished`, not a lost connection).
  final ValueChanged<JobSnapshot>? onFinished;

  @override
  State<ProfileJobPage> createState() => _ProfileJobPageState();
}

class _ProfileJobPageState extends State<ProfileJobPage> {
  late JobSnapshot _snap = JobSnapshot(
    jobId: widget.job.jobId,
    kind: widget.job.kind,
  );
  StreamSubscription<JobSnapshot>? _sub;

  @override
  void initState() {
    super.initState();
    widget.modal.canBack = () => _snap.finished;
    _sub = widget.jobs
        .watch(widget.job.jobId)
        .listen(
          (s) {
            if (!mounted) return;
            setState(() => _snap = s);
            if (s.finished) widget.onFinished?.call(s);
          },
          onError: (Object e) {
            if (!mounted) return;
            setState(
              () => _snap = _snap.copyWith(
                finished: true,
                error: JobError(
                  message: e is SystemException
                      ? e.message
                      : 'Lost contact with the service.',
                ),
              ),
            );
          },
        );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final s = _snap;
    final region = widget.modal.region;
    // Always one button, so the page holds the focus while it works.
    region.setRows([const NavRow('buttons', 1)]);
    final stages = s.kind.stages;
    final i = stages.indexOf(s.stage);
    final fraction = s.finished
        ? 1.0
        : (i < 0 ? null : (i + 0.5) / stages.length);
    return FullPage(
      title: s.finished ? (s.ok ? 'Ready' : "That didn't work") : widget.title,
      subtitle: widget.what,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 900, child: HBar(fraction: fraction)),
          const SizedBox(height: HinterTokens.s2),
          if (!s.finished)
            StatusLine('${s.stage.label}...', busy: true)
          else if (s.ok)
            const StatusLine('Done.', ok: true)
          else ...[
            StatusLine(
              s.error?.message ?? 'It stopped before it finished.',
              error: true,
            ),
            const SizedBox(height: HinterTokens.s2),
            Text('Nothing was changed. Try again.', style: t.body),
          ],
          const SizedBox(height: HinterTokens.s4),
          DialogButtonsRow(
            region: region,
            rowKey: 'buttons',
            buttons: [
              if (s.finished)
                btn(
                  s.ok ? 'Continue' : 'Close',
                  () => widget.modal.close(s.ok),
                  primary: true,
                )
              else
                btn('Please wait', null, enabled: false),
            ],
          ),
        ],
      ),
    );
  }
}
