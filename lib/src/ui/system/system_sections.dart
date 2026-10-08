import 'package:flutter/material.dart';

import '../../system/models.dart';
import '../../system/profiles.dart';
import '../../theme/hinter_theme.dart';
import '../dialogs.dart';
import '../pages.dart';
import '../widgets.dart';
import 'common.dart';

// ------------------------------------------------------------------ remote access

/// SSH on or off. SSH is plain username and password for now: you log in as
/// the admin account with its password, over the local network.
///
/// Turning it on needs the admin password (polkit `auth_admin`). This just
/// calls `ssh.set`: the session daemon is polkit's authentication agent, and
/// while the call waits it sends `authentication_requested`, which the shell
/// shows as the password prompt over this screen (`AuthPromptHost`). The call
/// then ends with a job, or with "nothing was changed" when the prompt was
/// cancelled or the password was wrong too often.
class RemoteAccessSection extends StatelessWidget {
  const RemoteAccessSection(this.env, {super.key});

  final SectionEnv env;

  @override
  Widget build(BuildContext context) {
    final sys = env.services.system;
    return Loaded<(SshState, SystemInfo)>(
      region: env.region,
      load: () async => (await sys.ssh(), await sys.info()),
      builder: (context, data, reload) {
        final (ssh, info) = data;
        final t = HinterTheme.of(context);
        final p = Pane(env.region);
        p.add(
          Text(
            'With SSH on, you can log in to this box from another computer '
            'on your home network. You log in as the admin account, with its '
            'password.',
            style: t.body,
          ),
        );
        p.item(
          'ssh',
          onSelect: () async {
            await runJob(context, env.services, () => sys.setSsh(!ssh.enabled));
            await reload();
          },
          builder: (f) => SettingRow(
            title: 'SSH',
            subtitle: ssh.enabled
                ? null
                : 'Turning it on asks for the admin password.',
            focused: f,
            trailing: ToggleMark(on: ssh.enabled),
          ),
          gap: HinterTokens.s3,
        );
        if (ssh.enabled) {
          p.add(
            StatusLine(
              'On. Log in as the admin account at ${info.hostname}.local '
              'with its password.',
              ok: true,
            ),
            gap: HinterTokens.s2,
          );
        }
        return p.build();
      },
    );
  }
}

// ------------------------------------------------------------------ updates

class UpdatesSection extends StatefulWidget {
  const UpdatesSection(this.env, {super.key});

  final SectionEnv env;

  @override
  State<UpdatesSection> createState() => _UpdatesSectionState();
}

class _UpdatesSectionState extends State<UpdatesSection> {
  /// "This update takes away Plex (reason), ...": installed apps the update
  /// removes from the catalog.
  static String _takesAway(List<CatalogChange> apps) =>
      'This update takes away ${[for (final n in apps) n.reason == null || n.reason!.isEmpty ? n.name : '${n.name} (${n.reason})'].join(', ')}.';

  bool _checking = false;
  String? _checkError;
  final _key = GlobalKey();

  SectionEnv get env => widget.env;

  Future<void> _check(Future<void> Function() reload) async {
    setState(() {
      _checking = true;
      _checkError = null;
    });
    try {
      await env.services.updates.check();
    } on SystemException catch (e) {
      _checkError = switch (e.kind) {
        SystemErrorKind.updateUnreachable =>
          "Can't reach the update server right now. Nothing else depends on "
              'it: everything keeps working. Try again later.',
        SystemErrorKind.updateVerificationFailed =>
          'The update did not pass its safety check, so it was not used. '
              'Nothing was changed.',
        _ => e.message,
      };
    }
    if (!mounted) return;
    setState(() => _checking = false);
    await reload();
  }

  /// Starts a job that may need an acknowledgement (a downgrade).
  Future<void> _withAck(
    Future<JobHandle> Function(bool ack) start,
    String ackTitle,
  ) async {
    final c = context;
    try {
      final h = await start(false);
      if (!c.mounted) return;
      await showJobProgress(c, env.services, h);
    } on SystemException catch (e) {
      if (!c.mounted) return;
      if (e.kind == SystemErrorKind.needsAcknowledgement) {
        final r = await showConfirm(
          c,
          title: ackTitle,
          body:
              '${e.message} Software on this box may go back to an older '
              'version. You can roll back afterwards.',
          confirmLabel: 'Switch anyway',
          danger: true,
        );
        if (r == null || !c.mounted) return;
        await runJob(c, env.services, () => start(true));
      } else {
        await showMessage(c, title: "That didn't work", body: e.message);
      }
    }
  }

  /// What a rollback to [target] does to the profiles (M7): accounts the
  /// target generation does not have disappear (their homes stay), and
  /// accounts it has that were removed since come back with an empty home.
  Future<List<String>> _profileChanges(Generation? target) async {
    final want = target?.profiles;
    if (want == null) return const [];
    final ProfilesState now;
    try {
      now = await env.services.profiles.list();
    } on SystemException {
      return const [];
    }
    final have = {for (final p in now.profiles) p.id};
    final gone = [
      for (final p in now.profiles)
        if (!want.any((w) => w.id == p.id)) p.name,
    ];
    final empty = [
      for (final w in want)
        if (!have.contains(w.id)) w.name ?? 'Profile ${w.id.substring(1)}',
    ];
    String list(List<String> n) => n.length == 1
        ? n.first
        : '${n.sublist(0, n.length - 1).join(', ')} and ${n.last}';
    return [
      if (gone.isNotEmpty)
        '${list(gone)} ${gone.length == 1 ? 'is' : 'are'} not in that '
            'version: ${gone.length == 1 ? 'that profile disappears' : 'those profiles disappear'} '
            'until you update again. ${gone.length == 1 ? 'Its' : 'Their'} '
            'files stay on the box.',
      if (empty.isNotEmpty)
        '${list(empty)} ${empty.length == 1 ? 'comes' : 'come'} back, but '
            'empty: ${empty.length == 1 ? 'that profile was' : 'those profiles were'} '
            'removed since, with everything in ${empty.length == 1 ? 'it' : 'them'}.',
    ];
  }

  Future<void> _rollback(
    Generation? g,
    Future<void> Function() reload, {
    List<Generation> gens = const [],
  }) async {
    final cur = gens.where((x) => x.current).firstOrNull;
    final target =
        g ??
        gens
            .where((x) => cur == null || x.generation < cur.generation)
            .firstOrNull;
    final changes = await _profileChanges(target);
    if (!mounted) return;
    final r = await showConfirm(
      context,
      title: g == null
          ? 'Roll back to the previous version?'
          : 'Roll back to generation ${g.generation}?',
      body:
          'The box switches to an earlier version of HinterOS and the '
          'session restarts. Your apps and games stay.',
      extra: [for (final c in changes) StatusLine(c, error: true)],
      confirmLabel: 'Roll back',
      danger: true,
    );
    if (r == null || !mounted) return;
    await runJob(
      context,
      env.services,
      () => env.services.updates.rollback(generation: g?.generation),
    );
    await reload();
  }

  @override
  Widget build(BuildContext context) {
    final up = env.services.updates;
    final sys = env.services.system;
    return Loaded<(SystemInfo, List<Generation>)>(
      key: _key,
      region: env.region,
      load: () async => (await sys.info(), await up.generations()),
      builder: (context, data, reload) {
        final (info, gens) = data;
        final status = up.status;
        final a = status.available;
        final t = HinterTheme.of(context);
        final p = Pane(env.region);
        p.add(
          Text(
            info.channel == null
                ? 'HinterOS ${status.currentVersion}. This box follows no update channel.'
                : 'HinterOS ${status.currentVersion}, ${info.channel!.label} channel.',
            style: t.label,
          ),
        );
        if (_checkError != null) {
          p.add(StatusLine(_checkError!, error: true));
        } else if (a != null) {
          p.add(
            StatusLine(
              'Update available: ${a.version}'
              '${a.isSecurity ? ' (security update, severity ${a.severity!.label})' : ''}. '
              '${a.summary}',
              error: a.isSecurity,
            ),
          );
        } else if (status.checkedAt != null) {
          p.add(const StatusLine('HinterOS is up to date.', ok: true));
        } else {
          p.add(const StatusLine('Not checked yet.'));
        }
        if (a != null) {
          final removed = a.removedApps;
          if (removed != null && removed.isNotEmpty) {
            p.add(StatusLine(_takesAway(removed), error: true));
          }
          final added = a.newApps;
          if (added != null && added.isNotEmpty) {
            p.add(
              Text(
                'It also adds to the Store: ${[for (final n in added) n.name].join(', ')}.',
                style: t.bodyDim,
              ),
            );
          }
        }
        p.item(
          'check',
          onSelect: _checking ? null : () => _check(reload),
          builder: (f) => SettingRow(
            title: _checking ? 'Checking...' : 'Check for updates',
            focused: f,
            subtitle: 'Nothing is ever installed without you choosing it.',
          ),
          gap: HinterTokens.s2,
        );
        if (a != null) {
          p.item(
            'apply',
            onSelect: () async {
              final r = await showConfirm(
                context,
                title: 'Update to ${a.version}?',
                body:
                    'It downloads, installs and then restarts your session. '
                    'If it fails, nothing is changed.',
                extra: [
                  if (a.removedApps?.isNotEmpty ?? false)
                    StatusLine(_takesAway(a.removedApps!), error: true),
                ],
                confirmLabel: 'Update now',
              );
              if (r == null || !context.mounted) return;
              await runJob(context, env.services, () => up.apply(a.rev));
              await reload();
            },
            builder: (f) => SettingRow(title: 'Update now', focused: f),
          );
        }
        p.item(
          'channel',
          onSelect: () async {
            final c = await showChoice<UpdateChannel>(
              context,
              title: 'Update channel',
              body: 'Which releases this box follows.',
              choices: [
                for (final c in UpdateChannel.values)
                  Choice(
                    '${c.label}${c == info.channel ? ' (current)' : ''}: ${c.blurb}',
                    c,
                  ),
              ],
            );
            if (c == null || c == info.channel) return;
            await _withAck(
              (ack) => up.setChannel(c, acknowledgeDowngrade: ack),
              'Switch to ${c.label}?',
            );
            await reload();
          },
          builder: (f) => SettingRow(
            title: 'Channel',
            focused: f,
            trailing: Text(info.channel?.label ?? 'None', style: t.bodyDim),
          ),
        );
        if (info.channel == UpdateChannel.stable) {
          p.item(
            'base',
            onSelect: () async {
              final b = await showChoice<NixBase>(
                context,
                title: 'Software base',
                choices: [
                  for (final b in NixBase.values)
                    Choice(
                      '${b.label}${b == info.base ? ' (current)' : ''}: ${b.blurb}',
                      b,
                    ),
                ],
              );
              if (b == null || b == info.base) return;
              await _withAck(
                (ack) => up.setBase(b, acknowledgeDowngrade: ack),
                'Switch to the ${b.label} base?',
              );
              await reload();
            },
            builder: (f) => SettingRow(
              title: 'Software base',
              focused: f,
              trailing: Text(info.base.label, style: t.bodyDim),
            ),
          );
        }
        final canRoll = gens.any((g) => !g.current);
        p.item(
          'rollback',
          onSelect: canRoll ? () => _rollback(null, reload, gens: gens) : null,
          builder: (f) => SettingRow(
            title: 'Roll back to the previous version',
            focused: f,
            dim: !canRoll,
            subtitle: canRoll ? null : 'There is no earlier version.',
          ),
        );
        p.add(
          Text('Versions on this box', style: t.label),
          gap: HinterTokens.s3,
        );
        for (var i = 0; i < gens.length; i++) {
          final g = gens[i];
          p.item(
            'g$i',
            onSelect: g.current ? null : () => _rollback(g, reload, gens: gens),
            builder: (f) => SettingRow(
              title: 'Generation ${g.generation}',
              focused: f,
              subtitle:
                  '${g.date.year}-${g.date.month.toString().padLeft(2, '0')}-'
                  '${g.date.day.toString().padLeft(2, '0')}'
                  '${g.rev == null ? '' : ', ${shortRev(g.rev)}'}',
              trailing: Text(
                [
                  if (g.current) 'Current',
                  if (g.booted) 'Started with',
                ].join(', '),
                style: t.bodyDim,
              ),
            ),
          );
        }
        return p.build();
      },
    );
  }
}

// ------------------------------------------------------------------ about

class AboutSection extends StatelessWidget {
  const AboutSection(this.env, {super.key});

  final SectionEnv env;

  @override
  Widget build(BuildContext context) {
    return Loaded<SystemInfo>(
      region: env.region,
      load: env.services.system.info,
      builder: (context, i, _) {
        final t = HinterTheme.of(context);
        final p = Pane(env.region);
        void line(String key, String title, String value) => p.item(
          key,
          onSelect: null,
          builder: (f) => SettingRow(
            title: title,
            focused: f,
            trailing: Text(value, style: t.bodyDim),
          ),
        );
        if (i.dev) {
          p.add(
            Row(
              children: [
                Text('Developer build', style: t.label),
                const SizedBox(width: HinterTokens.s2),
                const DevBadge(),
              ],
            ),
          );
        }
        line('version', 'Version', i.version);
        line('channel', 'Channel', i.channel?.label ?? 'None');
        line('base', 'Software base', i.base.label);
        line('rev', 'Revision', i.rev == null ? 'None' : shortRev(i.rev, 12));
        line('gen', 'Generation', i.generation?.toString() ?? 'None');
        line('host', 'Name on the network', '${i.hostname}.local');
        for (var k = 0; k < i.hostKeyFingerprints.length; k++) {
          p.item(
            'fp$k',
            onSelect: null,
            builder: (f) => SettingRow(
              title: 'SSH host key',
              subtitle: i.hostKeyFingerprints[k],
              focused: f,
            ),
          );
        }
        p.add(
          Text(
            'HinterOS is free software, licensed GPL-3.0-only.',
            style: t.caption,
          ),
        );
        return p.build();
      },
    );
  }
}
