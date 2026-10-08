/// Settings -> Profiles: every profile with its storage, Add profile, and per
/// profile Rename, Colour, PIN, Locked, App history and Remove. Actions on
/// another profile ask for the admin PIN on the same pad. The admin profile
/// also gets Starter apps and Guest on/off. In the guest's session only
/// Switch profile and End guest session.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../system/models.dart';
import '../../system/repositories.dart';
import '../../theme/hinter_theme.dart';
import '../dialogs.dart';
import '../modal_host.dart';
import '../pages.dart' show FullPage, showJobProgress;
import '../system/common.dart';
import '../widgets.dart';
import 'profile_form.dart';
import 'profile_ui.dart';
import 'session_profile.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "3 Oct".
String shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

class ProfilesSection extends StatefulWidget {
  const ProfilesSection(this.env, {super.key, this.session});

  final SectionEnv env;

  /// The shell's profile session (switching, ending the guest session);
  /// null in tests that show the section alone.
  final ProfileSession? session;

  @override
  State<ProfilesSection> createState() => _ProfilesSectionState();
}

typedef _Data = (ProfilesState, CurrentProfile);

class _ProfilesSectionState extends State<ProfilesSection> {
  SystemServices get _s => widget.env.services;
  ProfilesRepository get _p => _s.profiles;

  Future<_Data> _load() async {
    final me = widget.session?.current ?? await _p.current();
    return (await _p.list(), me);
  }

  /// `profiles_changed` turns the list shown into the new one.
  late final Stream<_Data Function(_Data)> _updates = _p.changes.map(
    (list) =>
        (d) => (
          ProfilesState(
            profiles: list,
            guestEnabled: d.$1.guestEnabled,
            guestUsage: d.$1.guestUsage,
            max: d.$1.max,
            firstBoot: d.$1.firstBoot,
          ),
          d.$2,
        ),
  );

  Future<void> _message(String title, String body) =>
      showMessage(context, title: title, body: body);

  Future<void> _failed(Object e) => _message(
    "That didn't work",
    e is SystemException ? e.message : 'Something went wrong ($e).',
  );

  // ---- actions

  Future<void> _add(ProfilesState s, Future<void> Function() reload) async {
    final form = await showProfileForm(
      context,
      editText: sessionEditText(context),
      taken: [for (final p in s.profiles) p.name],
    );
    if (form == null || !mounted) return;
    final ProfileJob job;
    try {
      job = await _p.create(
        name: form.name,
        color: form.color,
        pin: form.pin,
        locked: form.locked,
      );
    } catch (e) {
      if (mounted) {
        await _message(
          "Couldn't add the profile",
          e is SystemException && e.kind == SystemErrorKind.profileLimit
              ? 'This box has as many profiles as it can have.'
              : (e is SystemException ? e.message : '$e'),
        );
      }
      return;
    }
    if (!mounted) return;
    await showProfileJob(
      context,
      jobs: _s.jobs,
      job: job.job,
      what: "Creating ${form.name}'s profile... (about a minute)",
    );
    await reload();
  }

  Future<void> _actions(
    ProfileInfo p,
    CurrentProfile me,
    Future<void> Function() reload,
  ) async {
    final own = p.id == me.id;
    final choice = await showChoice<String>(
      context,
      title: p.name,
      body: own
          ? 'Your profile.'
          : "Changing another profile needs the admin profile's PIN.",
      choices: [
        const Choice('Rename', 'rename'),
        if (own) const Choice('Colour', 'color'),
        if (own) const Choice('Change PIN', 'pin'),
        if (!own) const Choice('Give it a new PIN', 'reset'),
        if (own)
          Choice(
            p.locked ? 'Stop asking for the PIN' : 'Lock this profile',
            'lock',
          ),
        if (own) const Choice('App history', 'history'),
        if (!p.admin) const Choice('Remove', 'remove', danger: true),
      ],
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case 'rename':
        await _rename(p, own);
      case 'color':
        await _color(p);
      case 'pin':
        await _changePin();
      case 'reset':
        await _resetPin(p);
      case 'lock':
        await _lock(p);
      case 'history':
        await _history();
      case 'remove':
        await _remove(p, own);
    }
    await reload();
  }

  Future<void> _rename(ProfileInfo p, bool own) async {
    final name = await sessionEditText(context)(
      title: 'Rename ${p.name}',
      initial: p.name,
      hint: 'Shown on the profile picker. 1 to 32 characters.',
    );
    if (name == null || name.trim() == p.name || !mounted) return;
    if (own) {
      try {
        await _p.rename(p.id, name);
      } catch (e) {
        if (mounted) await _failed(e);
      }
      return;
    }
    await withAdminPin(
      context,
      title: 'Rename ${p.name}',
      action: (pin) => _p.rename(p.id, name, adminPin: pin),
    );
  }

  Future<void> _color(ProfileInfo p) async {
    final c = await showChoice<ProfileColor>(
      context,
      title: 'Colour',
      choices: [
        for (final c in ProfileColor.values)
          Choice('${c.label}${c == p.color ? ' (now)' : ''}', c),
      ],
    );
    if (c == null || c == p.color || !mounted) return;
    try {
      await _p.setColor(c);
    } catch (e) {
      if (mounted) await _failed(e);
    }
  }

  /// A new PIN, typed twice. Null: given up.
  Future<String?> _newPin(String who) async {
    final first = await showPinEntry(
      context,
      title: 'New PIN',
      body: 'Choose a new PIN for $who: 4 to 8 digits.',
      disclaimer: true,
      submitLabel: 'Next',
      check: (_) async => const PinAccepted(),
    );
    if (first == null || !mounted) return null;
    final again = await showPinEntry(
      context,
      title: 'New PIN',
      body: 'Type the new PIN again.',
      check: (pin) async => pin == first
          ? const PinAccepted()
          : const PinFailed("The two PINs didn't match."),
    );
    return again;
  }

  Future<void> _changePin() async {
    final current = await showPinEntry(
      context,
      title: 'Change PIN',
      body: 'First your current PIN.',
      submitLabel: 'Next',
      check: (_) async => const PinAccepted(),
    );
    if (current == null || !mounted) return;
    final next = await _newPin('your profile');
    if (next == null || !mounted) return;
    try {
      await _p.setPin(next, currentPin: current);
      if (mounted) await _message('PIN changed', 'Your new PIN works now.');
    } catch (e) {
      if (!mounted) return;
      final r = PinRefusal.of(e);
      if (r != null) {
        await _message(
          'PIN not changed',
          r.retryAt == null
              ? "Your current PIN didn't match. Nothing was changed."
              : 'Too many tries. ${retryText(r.retryAt!.difference(DateTime.now()))}',
        );
      } else {
        await _failed(e);
      }
    }
  }

  Future<void> _resetPin(ProfileInfo p) async {
    final next = await _newPin(p.name);
    if (next == null || !mounted) return;
    await withAdminPin(
      context,
      title: "New PIN for ${p.name}",
      action: (pin) => _p.resetPin(p.id, next, adminPin: pin),
    );
  }

  Future<void> _lock(ProfileInfo p) async {
    await showPinEntry(
      context,
      title: p.locked ? 'Stop asking for the PIN' : 'Lock this profile',
      body: p.locked
          ? 'Your profile will open without the PIN. Type your PIN to '
                'confirm.'
          : 'Your profile will ask for its PIN to open, also after sleep. '
                'Type your PIN to confirm.',
      disclaimer: true,
      check: (pin) async {
        try {
          await _p.setLocked(!p.locked, pin);
          return const PinAccepted();
        } catch (e) {
          return PinAttempt.fromError(e);
        }
      },
    );
  }

  Future<void> _remove(ProfileInfo p, bool own) async {
    final size = p.usage == null
        ? ''
        : ' (${bytesLabel(p.usage!.steamGamesBytes)})';
    final ok = await showConfirm(
      context,
      title: 'Remove ${p.name}?',
      body:
          "This deletes ${p.name}'s games$size, game saves that aren't in the "
          "cloud, and all of ${p.name}'s sign-ins (Steam, YouTube, Plex...)."
          '${own ? ' Your session ends first.' : ''}',
      confirmLabel: 'Remove',
      danger: true,
    );
    if (ok == null || !mounted) return;
    final held = await showHoldToConfirm(
      context,
      title: 'Remove ${p.name}',
      body: 'Hold A for 3 seconds to remove ${p.name}.',
    );
    if (!held || !mounted) return;
    JobHandle? job;
    await showPinEntry(
      context,
      title: 'Remove ${p.name}',
      body: own
          ? 'Type your PIN to remove your profile.'
          : "Type the admin profile's PIN to remove ${p.name}.",
      check: (pin) async {
        try {
          job = await _p.remove(p.id, pin);
          return const PinAccepted();
        } catch (e) {
          return PinAttempt.fromError(e);
        }
      },
    );
    final j = job;
    if (j == null || !mounted) return;
    await showProfileJob(
      context,
      jobs: _s.jobs,
      job: j,
      title: 'Removing the profile',
      what: "Removing ${p.name}'s profile",
    );
  }

  Future<void> _history() async {
    final List<AppGeneration> gens;
    try {
      gens = await _s.store.appGenerations();
    } catch (e) {
      if (mounted) await _failed(e);
      return;
    }
    if (!mounted) return;
    final names = {for (final a in _s.store.apps) a.id: a.name};
    final g = await ModalScope.of(context).show<AppGeneration>(
      (context, modal) =>
          _AppHistoryPage(modal: modal, generations: gens, names: names),
    );
    if (g == null || !mounted) return;
    final ok = await showConfirm(
      context,
      title: 'Put your apps back?',
      body:
          'Your apps go back to how they were on ${shortDate(g.date)}: '
          '${g.ids.map((i) => names[i] ?? i).join(', ')}. Other profiles '
          'are not changed. Your data in the apps stays.',
      confirmLabel: 'Put them back',
    );
    if (ok == null || !mounted) return;
    await runJob(context, _s, () => _s.store.rollbackApps(g.generation));
  }

  Future<void> _starter() async {
    final StarterSet set;
    try {
      set = await _p.starterSet();
    } catch (e) {
      if (mounted) await _failed(e);
      return;
    }
    if (!mounted) return;
    final apps = [
      for (final a in _s.store.apps)
        if (a.state.isInstalled) a,
    ];
    final ids = await ModalScope.of(context).show<List<String>>(
      (context, modal) =>
          _StarterPage(modal: modal, apps: apps, chosen: set.ids.toSet()),
    );
    if (ids == null || !mounted) return;
    JobHandle? job;
    var nothing = false;
    final ran = await withAdminPin(
      context,
      title: 'Starter apps',
      action: (pin) async {
        job = await _p.setStarterSet(ids, pin);
        nothing = job == null;
      },
    );
    if (!ran || !mounted) return;
    if (nothing) {
      await _message('Starter apps', 'Those already are the starter apps.');
      return;
    }
    await showJobProgress(context, _s, job!);
  }

  Future<void> _guest(bool enabled) async {
    JobHandle? job;
    final ran = await withAdminPin(
      context,
      title: enabled ? 'Turn the guest off' : 'Turn the guest on',
      body: enabled
          ? 'The picker stops offering Guest. This takes about a minute.'
          : 'The picker offers Guest again. This takes about a minute.',
      action: (pin) async => job = await _p.setGuest(!enabled, pin),
    );
    if (!ran || job == null || !mounted) return;
    await showJobProgress(context, _s, job!);
  }

  // ---- the pane

  @override
  Widget build(BuildContext context) {
    final env = widget.env;
    return Loaded<_Data>(
      region: env.region,
      load: _load,
      updates: [_updates],
      builder: (context, data, reload) {
        final (state, me) = data;
        final t = HinterTheme.of(context);
        final p = Pane(env.region);
        final session = widget.session;
        if (me.guest) {
          p.add(
            Text(
              'You are using the guest profile. Everything in it is cleared '
              'when the box restarts.',
              style: t.body,
            ),
          );
          p.item(
            'switch',
            onSelect: session == null
                ? null
                : () => unawaited(session.switchProfile(context)),
            builder: (f) => SettingRow(title: 'Switch profile', focused: f),
            gap: HinterTokens.s3,
          );
          p.item(
            'end',
            onSelect: session == null
                ? null
                : () => unawaited(session.endGuest(context)),
            builder: (f) => SettingRow(
              title: 'End guest session',
              focused: f,
              danger: true,
            ),
          );
          return p.build();
        }
        for (final x in state.profiles) {
          final bits = [
            if (x.id == me.id) 'You',
            if (x.admin) 'Admin',
            if (x.locked) 'Locked',
            x.usage == null
                ? 'Storage not measured yet'
                : '${bytesLabel(x.usage!.totalBytes)} used',
          ];
          p.item(
            'p-${x.id}',
            onSelect: () => unawaited(_actions(x, me, reload)),
            builder: (f) => SettingRow(
              title: x.name,
              subtitle: bits.join(' · '),
              focused: f,
              leading: ProfileAvatar(
                initial: x.initial,
                color: x.color,
                locked: x.locked,
                size: 64,
              ),
            ),
          );
        }
        p.item(
          'add',
          onSelect: state.full ? null : () => unawaited(_add(state, reload)),
          builder: (f) => SettingRow(
            title: 'Add profile',
            focused: f,
            dim: state.full,
            subtitle: state.full
                ? 'This box has ${state.max} profiles, the most it can have.'
                : 'A name, a colour and a PIN. Takes about a minute.',
          ),
          gap: HinterTokens.s3,
        );
        p.item(
          'switch',
          onSelect: session == null
              ? null
              : () => unawaited(session.switchProfile(context)),
          builder: (f) => SettingRow(
            title: 'Switch profile',
            focused: f,
            subtitle: 'Everything running in your profile closes first.',
          ),
        );
        if (me.admin) {
          p.add(
            Text('For the whole box (admin PIN)', style: t.label),
            gap: HinterTokens.s3,
          );
          p.item(
            'starter',
            onSelect: () => unawaited(_starter()),
            builder: (f) => SettingRow(
              title: 'Starter apps',
              subtitle:
                  'The apps new profiles and the guest start with, chosen '
                  'from your apps.',
              focused: f,
            ),
          );
          p.item(
            'guest',
            onSelect: () =>
                unawaited(_guest(state.guestEnabled).then((_) => reload())),
            builder: (f) => SettingRow(
              title: 'Guest',
              subtitle: state.guestEnabled
                  ? 'Anyone can use the box as a guest; cleared at every '
                        'restart.${state.guestUsage == null ? '' : ' Now ${bytesLabel(state.guestUsage!.totalBytes)}.'}'
                  : 'The picker does not offer Guest.',
              focused: f,
              trailing: ToggleMark(on: state.guestEnabled),
            ),
          );
        }
        p.add(Text(pinDisclaimer, style: t.caption), gap: HinterTokens.s3);
        return p.build();
      },
    );
  }
}

// ---------------------------------------------------------------- history

/// What changed after generation [older] (in [newer]), for the history list:
/// "Before installing Plex", "Before removing Kodi", "Before the update".
String historyLabel(
  AppGeneration older,
  AppGeneration newer,
  Map<String, String> names,
) {
  String n(Iterable<String> ids) => ids.map((i) => names[i] ?? i).join(', ');
  final added = newer.ids.where((i) => !older.ids.contains(i));
  final removed = older.ids.where((i) => !newer.ids.contains(i));
  if (added.isNotEmpty && removed.isEmpty) {
    return 'Before installing ${n(added)}';
  }
  if (removed.isNotEmpty && added.isEmpty) {
    return 'Before removing ${n(removed)}';
  }
  if (added.isEmpty && removed.isEmpty) return 'Before the update';
  return 'Before installing ${n(added)} and removing ${n(removed)}';
}

class _AppHistoryPage extends StatelessWidget {
  const _AppHistoryPage({
    required this.modal,
    required this.generations,
    required this.names,
  });

  final ModalHandle<AppGeneration> modal;
  final List<AppGeneration> generations;
  final Map<String, String> names;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final p = Pane(modal.region);
    p.add(
      Text(
        'Your apps as they were before a change. Only your profile changes; '
        'your data in the apps stays.',
        style: t.body,
      ),
    );
    var any = false;
    for (var i = 1; i < generations.length; i++) {
      final g = generations[i];
      if (g.current) continue;
      any = true;
      final label = historyLabel(g, generations[i - 1], names);
      p.item(
        'g${g.generation}',
        onSelect: () => modal.close(g),
        builder: (f) => SettingRow(
          title: '$label, ${shortDate(generations[i - 1].date)}',
          subtitle: g.ids.map((x) => names[x] ?? x).join(', '),
          focused: f,
        ),
      );
    }
    if (!any) {
      p.add(const StatusLine('There is no earlier state of your apps yet.'));
    }
    p.buttons('close', [btn('Close', modal.close)], gap: HinterTokens.s4);
    return FullPage(
      title: 'App history',
      subtitle: 'B goes back.',
      child: SingleChildScrollView(child: p.build()),
    );
  }
}

// ---------------------------------------------------------------- starter set

class _StarterPage extends StatefulWidget {
  const _StarterPage({
    required this.modal,
    required this.apps,
    required this.chosen,
  });

  final ModalHandle<List<String>> modal;
  final List<StoreApp> apps;
  final Set<String> chosen;

  @override
  State<_StarterPage> createState() => _StarterPageState();
}

class _StarterPageState extends State<_StarterPage> {
  late final Set<String> _chosen = {...widget.chosen};

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final region = widget.modal.region;
    final p = Pane(region);
    p.add(
      Text(
        'New profiles and guest sessions start with these apps. Profiles '
        'that exist now keep their own apps. You can choose from the apps '
        'in your profile.',
        style: t.body,
      ),
    );
    for (final a in widget.apps) {
      p.item(
        'a-${a.id}',
        onSelect: () => setState(
          () =>
              _chosen.contains(a.id) ? _chosen.remove(a.id) : _chosen.add(a.id),
        ),
        builder: (f) => SettingRow(
          title: a.name,
          subtitle: a.hasTerms
              ? 'Each profile accepts its terms the first time it opens it.'
              : null,
          focused: f,
          leading: CheckMark(checked: _chosen.contains(a.id)),
        ),
      );
    }
    p.buttons('save', [
      btn('Cancel', widget.modal.close),
      btn(
        'Save',
        () => widget.modal.close([
          for (final a in widget.apps)
            if (_chosen.contains(a.id)) a.id,
        ]),
        primary: true,
      ),
    ], gap: HinterTokens.s4);
    return FullPage(
      title: 'Starter apps',
      subtitle: '${_chosen.length} chosen',
      child: SingleChildScrollView(child: p.build()),
    );
  }
}
