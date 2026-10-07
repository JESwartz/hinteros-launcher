import 'package:flutter/material.dart';

import '../../nav/nav_controller.dart';
import '../../nav/nav_model.dart';
import '../../theme/hinter_theme.dart';
import '../../ui/app_selection.dart';
import '../../ui/dialogs.dart' show DialogButtons;
import '../../ui/modal_host.dart' show ModalHandle;
import '../../ui/pages.dart';
import '../../ui/widgets.dart';
import '../backend.dart';
import '../flow.dart';
import '../plan.dart';
import 'host.dart';

/// What every step gets.
class StepEnv {
  const StepEnv(this.flow, this.console);

  final InstallerFlow flow;
  final ConsoleController console;

  NavRegion get region => console.content;
}

/// The frame of a step: title, "Step n of 6", scrolling content.
class StepPage extends StatelessWidget {
  const StepPage({
    super.key,
    required this.step,
    required this.child,
    this.title,
    this.subtitle,
  });

  final InstallerStep step;
  final String? title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final sub = [
      if (step.isQuestion)
        'Step ${step.questionNumber} of ${InstallerStep.questionCount}',
      ?subtitle,
    ].join('. ');
    return FullPage(
      title: title ?? step.title,
      subtitle: sub.isEmpty ? null : sub,
      child: child,
    );
  }
}

Widget scrolling(Widget pane) => SingleChildScrollView(
  clipBehavior: Clip.none,
  padding: const EdgeInsets.all(HinterTokens.s2),
  child: pane,
);

// ------------------------------------------------------------------ welcome

class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key, required this.env});

  final StepEnv env;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final p = Pane(env.region);
    p.add(
      Text(
        'This installs HinterOS on this computer. You only need your '
        'controller.',
        style: t.title,
      ),
    );
    p.add(
      Text(
        'Move with the D-pad, press A to choose and B to go back. '
        'It takes a few minutes.',
        style: t.bodyDim,
      ),
      gap: HinterTokens.s3,
    );
    p.add(
      Text(
        'Before you start: anything on the disk you choose will be erased.',
        style: t.body.copyWith(color: t.danger),
      ),
      gap: HinterTokens.s3,
    );
    p.buttons('start', [
      btn('Start', env.flow.next, primary: true),
    ], gap: HinterTokens.s5);
    return StepPage(
      step: InstallerStep.welcome,
      title: 'Welcome to HinterOS',
      child: scrolling(p.build()),
    );
  }
}

// ------------------------------------------------------------------ network

class NetworkStep extends StatelessWidget {
  const NetworkStep({super.key, required this.env});

  final StepEnv env;

  Future<void> _join(WifiAp ap) async {
    String? psk;
    if (ap.secured) {
      psk = await env.console.editText(
        title: 'Password for ${ap.ssid}',
        secret: true,
        hint: 'The Wi-Fi password',
      );
      if (psk == null || psk.isEmpty) return;
    }
    await env.flow.joinWifi(ap, psk: psk);
    env.console.refocus();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: env.flow,
      builder: (context, _) {
        final f = env.flow;
        final t = HinterTheme.of(context);
        final net = f.net;
        final p = Pane(env.region);
        p.add(
          Text(
            'An internet connection lets you pick apps like Steam and Plex. '
            'Without one you can still install YouTube, Firefox, Jellyfin '
            'and Crunchyroll.',
            style: t.bodyDim,
          ),
        );
        if (f.checking) {
          p.add(const StatusLine('Network cable: Checking…', busy: true));
          p.add(
            const StatusLine('This computer: Checking…', busy: true),
            gap: HinterTokens.s1,
          );
          if (net == null || net.wifiAvailable) {
            p.add(
              const StatusLine('Wi-Fi: Checking…', busy: true),
              gap: HinterTokens.s1,
            );
          }
        } else if (net == null) {
          p.add(const StatusLine('Looking at the network...'));
        } else {
          p.add(
            StatusLine(
              net.wiredConnected
                  ? 'Network cable: connected.'
                  : 'Network cable: not connected.',
              ok: net.wiredConnected,
            ),
          );
          p.add(
            StatusLine(
              net.online
                  ? 'This computer is online.'
                  : 'This computer is not online.',
              ok: net.online,
            ),
            gap: HinterTokens.s1,
          );
          if (net.wifiAvailable) {
            final ssid = net.wifiSsid;
            p.add(
              StatusLine(
                ssid != null
                    ? 'Wi-Fi: connected to $ssid.'
                    : 'Wi-Fi: not connected.',
                ok: ssid != null,
              ),
              gap: HinterTokens.s1,
            );
          }
        }
        if (f.networkMessage != null) {
          p.add(StatusLine(f.networkMessage!, error: true));
        }
        if (f.connecting) p.add(const StatusLine('Connecting...'));
        if (f.checking && net == null) {
          // Nothing known yet: the Wi-Fi list waits for the first answer.
        } else if (net != null && !net.wifiAvailable) {
          p.add(
            Text('No Wi-Fi adapter found.', style: t.bodyDim),
            gap: HinterTokens.s3,
          );
        } else if (net != null) {
          p.add(Text('Wi-Fi networks', style: t.label), gap: HinterTokens.s3);
          if (f.wifi.isEmpty) {
            p.add(
              f.scanning
                  ? const StatusLine('Searching…', busy: true)
                  : Text(
                      'No networks found. Choose "Search again".',
                      style: t.bodyDim,
                    ),
              gap: HinterTokens.s1,
            );
          }
          for (var i = 0; i < f.wifi.length; i++) {
            final ap = f.wifi[i];
            final connected = ap.inUse || ap.ssid == net.wifiSsid;
            p.item(
              'w$i',
              onSelect: ap.supported && !f.connecting ? () => _join(ap) : null,
              builder: (focused) => SettingRow(
                title: ap.ssid,
                focused: focused,
                dim: !ap.supported,
                leading: SignalBars(bars: ap.bars),
                subtitle: !ap.supported
                    ? 'This kind of network cannot be used here.'
                    : null,
                trailing: connected
                    ? Text(
                        'Connected',
                        style: t.bodyDim.copyWith(
                          color: t.positive,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : (ap.secured
                          ? const LockMark()
                          : Text('Open', style: t.caption)),
              ),
            );
          }
        }
        p.buttons('actions', [
          if (net != null && net.wifiAvailable)
            btn('Search again', () async {
              await f.refreshNetwork();
              await f.scanWifi();
              env.console.refocus();
            }, enabled: !f.scanning && !f.connecting && !f.checking)
          else
            btn('Check again', f.refreshNetwork, enabled: !f.checking),
          btn(
            f.online ? 'Continue' : 'Continue without internet',
            f.next,
            primary: true,
          ),
        ], gap: HinterTokens.s3);
        return StepPage(
          step: InstallerStep.network,
          child: scrolling(p.build()),
        );
      },
    );
  }
}

// --------------------------------------------------------------------- disk

class DiskStep extends StatelessWidget {
  const DiskStep({super.key, required this.env});

  final StepEnv env;

  /// The big warning, then a second question. Resolves true when both were
  /// answered "erase".
  Future<bool> _confirm(BuildContext context, DiskInfo d) async {
    final m = env.console.modals;
    final first =
        await m.show<bool>(
          (c, h) => EraseConfirm(
            modal: h,
            title: 'Everything on this disk will be erased',
            lines: [
              '${d.title}, ${d.sizeLabel}',
              'All files, photos, games and programs on it will be deleted. '
                  'This cannot be undone.',
              'If anything on this disk matters to you, press "Go back" and '
                  'copy it somewhere else first.',
            ],
            backLabel: 'Go back',
            eraseLabel: 'I understand, continue',
          ),
        ) ??
        false;
    if (!first) return false;
    return await m.show<bool>(
          (c, h) => EraseConfirm(
            modal: h,
            title: 'Last check: erase ${d.title}?',
            lines: [
              'Erase ${d.title} (${d.sizeLabel}) and install HinterOS on it?',
              'Nothing is erased yet: that happens when you start the '
                  'install on the last screen.',
            ],
            backLabel: 'No, go back',
            eraseLabel: 'Yes, erase this disk',
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: env.flow,
      builder: (context, _) {
        final f = env.flow;
        final t = HinterTheme.of(context);
        final disks = f.disks;
        final p = Pane(env.region);
        p.add(
          Text(
            'Choose the disk to install HinterOS on. It will be erased.',
            style: t.body.copyWith(color: t.danger),
          ),
        );
        if (disks == null) {
          p.add(const StatusLine('Looking for disks...'));
        } else if (disks.isEmpty) {
          p.add(
            StatusLine(
              f.disksMessage ?? 'No disks found in this computer.',
              error: true,
            ),
          );
        }
        for (var i = 0; i < (disks?.length ?? 0); i++) {
          final d = disks![i];
          final reason = d.unusableReason;
          final chosen = f.disk?.path == d.path;
          p.item(
            'd$i',
            onSelect: reason == null ? () => f.chooseDisk(d) : null,
            builder: (focused) => SettingRow(
              title: '${d.title}, ${d.sizeLabel}',
              focused: focused,
              dim: reason != null,
              leading: CheckMark(checked: chosen),
              subtitle:
                  reason ??
                  '${d.path}${d.transport != null ? ', ${d.transport}' : ''}',
              trailing: reason != null
                  ? Text(
                      'Cannot be used',
                      style: t.caption.copyWith(
                        color: t.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
          );
        }
        if (disks != null && disks.isNotEmpty && !disks.any((d) => d.usable)) {
          p.add(
            const StatusLine(
              'None of the disks can be used. Check that this computer has '
              'an internal disk of at least 16 GB.',
              error: true,
            ),
          );
        }
        p.buttons('actions', [
          btn('Look again', f.loadDisks),
          btn(
            'Continue',
            f.disk == null
                ? null
                : () async {
                    if (await _confirm(context, f.disk!)) f.next();
                  },
            primary: true,
            enabled: f.disk != null,
          ),
        ], gap: HinterTokens.s3);
        return StepPage(
          step: InstallerStep.disk,
          subtitle: 'The disk is erased',
          child: scrolling(p.build()),
        );
      },
    );
  }
}

/// A full-screen question about erasing. The safe answer comes first and has
/// the focus; the danger styling does not rely on colour alone (a big
/// heading and a border).
class EraseConfirm extends StatelessWidget {
  const EraseConfirm({
    super.key,
    required this.modal,
    required this.title,
    required this.lines,
    required this.backLabel,
    required this.eraseLabel,
  });

  final ModalHandle<bool> modal;
  final String title;
  final List<String> lines;
  final String backLabel;
  final String eraseLabel;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    modal.region.setRows(const [NavRow('buttons', 2)]);
    return FullPage(
      title: 'Warning',
      child: Align(
        alignment: Alignment.topLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(HinterTokens.s4),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(HinterTokens.radiusCard),
                border: Border.all(color: t.danger, width: 6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.headline.copyWith(color: t.danger)),
                  for (final l in lines) ...[
                    const SizedBox(height: HinterTokens.s2),
                    Text(l, style: t.body),
                  ],
                ],
              ),
            ),
            const SizedBox(height: HinterTokens.s4),
            DialogButtons(
              region: modal.region,
              rowKey: 'buttons',
              buttons: [
                btn(backLabel, () => modal.close(false)),
                btn(
                  eraseLabel,
                  () => modal.close(true),
                  primary: true,
                  danger: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ account

class AccountStep extends StatelessWidget {
  const AccountStep({super.key, required this.env});

  final StepEnv env;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: env.flow,
      builder: (context, _) {
        final f = env.flow;
        final t = HinterTheme.of(context);
        final p = Pane(env.region);
        p.add(
          Text(
            'This is the admin account. It can change the system, and with '
            'SSH turned on it is the account you log in with from another '
            'computer. Use a password you can type on the keyboard on the '
            'screen.',
            style: t.bodyDim,
          ),
        );
        Widget value(String s, {bool dim = false}) =>
            Text(s, style: dim ? t.caption : t.bodyDim.copyWith(color: t.text));
        p.item(
          'user',
          onSelect: () async {
            final v = await env.console.editText(
              title: 'User name',
              initial: f.username,
              hint: 'Lowercase letters, digits, - and _',
              maxLength: 32,
            );
            if (v != null) f.setUsername(v);
          },
          builder: (focused) => SettingRow(
            title: 'User name',
            focused: focused,
            trailing: f.username.isEmpty
                ? value('Not set', dim: true)
                : value(f.username),
          ),
          gap: HinterTokens.s3,
        );
        p.item(
          'pw',
          onSelect: () async {
            final v = await env.console.editText(
              title: 'Password',
              initial: f.password,
              secret: true,
              hint: 'At least ${PlanChecks.minPassword} characters',
            );
            if (v != null) f.setPassword(v);
          },
          builder: (focused) => SettingRow(
            title: 'Password',
            focused: focused,
            trailing: f.password.isEmpty
                ? value('Not set', dim: true)
                : value('•' * f.password.runes.length.clamp(0, 24)),
          ),
        );
        p.item(
          'pw2',
          onSelect: () async {
            final v = await env.console.editText(
              title: 'Password again',
              initial: f.repeat,
              secret: true,
              hint: 'Type the same password once more',
            );
            if (v != null) f.setRepeat(v);
          },
          builder: (focused) => SettingRow(
            title: 'Password again',
            focused: focused,
            trailing: f.repeat.isEmpty
                ? value('Not set', dim: true)
                : value('•' * f.repeat.runes.length.clamp(0, 24)),
          ),
        );
        final problem = f.accountProblem;
        if (problem != null) {
          p.add(StatusLine(problem, error: true), gap: HinterTokens.s3);
        } else if (f.accountValid) {
          p.add(
            const StatusLine('The account looks good.', ok: true),
            gap: HinterTokens.s3,
          );
        }
        p.buttons('actions', [
          btn('Continue', f.next, primary: true, enabled: f.accountValid),
        ], gap: HinterTokens.s3);
        return StepPage(
          step: InstallerStep.account,
          child: scrolling(p.build()),
        );
      },
    );
  }
}

// ------------------------------------------------------------------ options

class OptionsStep extends StatelessWidget {
  const OptionsStep({super.key, required this.env});

  final StepEnv env;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: env.flow,
      builder: (context, _) {
        final f = env.flow;
        final t = HinterTheme.of(context);
        final p = Pane(env.region);
        p.item(
          'host',
          onSelect: () async {
            final v = await env.console.editText(
              title: 'Computer name',
              initial: f.hostname,
              hint: 'Lowercase letters, digits and hyphens',
              maxLength: 63,
            );
            if (v != null) f.setHostname(v);
          },
          builder: (focused) => SettingRow(
            title: 'Computer name',
            subtitle: 'How this computer shows up on your network.',
            focused: focused,
            trailing: Text(f.hostname, style: t.body),
          ),
        );
        p.item(
          'ssh',
          onSelect: f.toggleSsh,
          builder: (focused) => SettingRow(
            title: 'Enable SSH',
            subtitle:
                'Lets you log in as the admin, with the password, from '
                'another computer on your home network. Leave it off unless '
                'you know you want this.',
            focused: focused,
            trailing: ToggleMark(on: f.ssh),
          ),
        );
        p.item(
          'channel',
          onSelect: f.toggleChannel,
          builder: (focused) => SettingRow(
            title: 'Update channel',
            subtitle: f.channel.blurb,
            focused: focused,
            trailing: Text(f.channel.label, style: t.body),
          ),
        );
        final problem = f.hostnameProblem;
        if (problem != null) {
          p.add(StatusLine(problem, error: true), gap: HinterTokens.s3);
        }
        p.buttons('actions', [
          btn('Continue', f.next, primary: true, enabled: problem == null),
        ], gap: HinterTokens.s3);
        return StepPage(
          step: InstallerStep.options,
          child: scrolling(p.build()),
        );
      },
    );
  }
}

// --------------------------------------------------------------------- apps

class AppsStep extends StatelessWidget {
  const AppsStep({super.key, required this.env});

  final StepEnv env;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: env.flow,
      builder: (context, _) {
        final f = env.flow;
        final apps = f.apps;
        return StepPage(
          step: InstallerStep.apps,
          subtitle:
              'Tick what you want; more can be added later from the Store',
          child: apps == null
              ? const Align(
                  alignment: Alignment.topLeft,
                  child: StatusLine('Loading the list of apps...'),
                )
              : ClipRect(
                  clipper: const _SideBleed(),
                  child: AppSelectionView(
                    controller: apps,
                    region: env.region,
                    online: f.online,
                    onContinue: f.next,
                  ),
                ),
        );
      },
    );
  }
}

// ------------------------------------------------------------------ summary

class SummaryStep extends StatelessWidget {
  const SummaryStep({super.key, required this.env});

  final StepEnv env;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: env.flow,
      builder: (context, _) {
        final f = env.flow;
        final t = HinterTheme.of(context);
        final p = Pane(env.region);
        Widget line(String k, String v, {Color? color}) => Padding(
          padding: const EdgeInsets.only(bottom: HinterTokens.s1),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 380, child: Text(k, style: t.bodyDim)),
              Expanded(
                child: Text(v, style: t.body.copyWith(color: color)),
              ),
            ],
          ),
        );
        final d = f.disk;
        final appNames = [
          for (final a in f.apps?.selectedApps ?? const []) a.name,
        ];
        p.add(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              line('Disk', d == null ? '-' : '${d.title}, ${d.sizeLabel}'),
              line('The disk will be', 'erased completely', color: t.danger),
              line('Admin user', f.username),
              line('Computer name', f.hostname),
              line('SSH', f.ssh ? 'On (login with the password)' : 'Off'),
              line('Update channel', f.channel.label),
              line('Apps', appNames.isEmpty ? 'None' : appNames.join(', ')),
              line(
                'Internet',
                f.online
                    ? (f.joinedSsid != null
                          ? 'Wi-Fi: ${f.joinedSsid}'
                          : 'Online')
                    : 'Not used',
              ),
            ],
          ),
        );
        p.buttons('actions', [
          btn('Back', f.back),
          btn(
            'Install HinterOS',
            f.ready
                ? () {
                    f.go(InstallerStep.install);
                    f.startInstall();
                  }
                : null,
            primary: true,
            danger: true,
            enabled: f.ready,
          ),
        ], gap: HinterTokens.s4);
        return StepPage(
          step: InstallerStep.summary,
          subtitle: 'Check everything, then install',
          child: scrolling(p.build()),
        );
      },
    );
  }
}

/// Clips scrolling content at the top and bottom of its area, but lets the
/// focus marker of a row spill out sideways.
class _SideBleed extends CustomClipper<Rect> {
  const _SideBleed();

  @override
  Rect getClip(Size size) => Rect.fromLTRB(
    -HinterTokens.s5,
    0,
    size.width + HinterTokens.s5,
    size.height,
  );

  @override
  bool shouldReclip(_SideBleed old) => false;
}
