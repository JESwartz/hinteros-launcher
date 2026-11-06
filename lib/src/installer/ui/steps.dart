import 'package:flutter/material.dart';

import '../../nav/nav_controller.dart';
import '../../theme/hinter_theme.dart';
import '../../ui/app_selection.dart';
import '../../ui/hold.dart';
import '../../ui/nav_focusable.dart';
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
    this.flow,
    this.title,
    this.subtitle,
  });

  final InstallerStep step;

  /// For "Step n of N" (it depends on whether the version step is shown).
  final InstallerFlow? flow;
  final String? title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final sub = [
      if (step.isQuestion && flow != null)
        'Step ${flow!.questionNumber(step)} of ${flow!.questionCount}',
      ?subtitle,
    ].join('. ');
    return FullPage(
      title: title ?? step.title,
      subtitle: sub.isEmpty ? null : sub,
      child: child,
    );
  }
}

Widget scrolling(Widget pane) =>
    PageScroll(padding: const EdgeInsets.all(HinterTokens.s2), child: pane);

// ------------------------------------------------------------------ welcome

class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key, required this.env});

  final StepEnv env;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final p = Pane(env.region);
    p.add(Text('This installs HinterOS on this computer.', style: t.title));
    p.add(
      Text(
        'Use the D-pad to move. Press A to choose and B to go back.',
        style: t.bodyDim,
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

class NetworkStep extends StatefulWidget {
  const NetworkStep({super.key, required this.env});

  final StepEnv env;

  @override
  State<NetworkStep> createState() => _NetworkStepState();
}

class _NetworkStepState extends State<NetworkStep> {
  StepEnv get env => widget.env;

  /// Whether the Wi-Fi list was shown once on this screen.
  bool _listShown = false;

  /// The list came after the screen (a slow check or scan), when only the
  /// buttons could take the focus: the focus goes to the first network, as
  /// when the list is there at once. A focus the person moved stays.
  void _focusList() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final region = env.region;
      final m = region.model;
      if (!mounted || env.console.typing) return;
      if (m.currentRow?.key != 'actions' || m.col != 0) return;
      if (!m.rows.any((r) => r.key.startsWith('w:'))) return;
      region.reset();
      env.console.refocus();
    });
  }

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
            'Some apps, such as Steam, need the internet.',
            style: t.bodyDim,
          ),
        );
        final linkComing =
            f.waitingForLink || (net != null && !net.linkUp && net.connecting);
        if (linkComing) {
          p.add(const StatusLine('Network: Connecting…', busy: true));
          p.add(
            const StatusLine(
              'This computer: Waiting for the connection…',
              busy: true,
            ),
            gap: HinterTokens.s1,
          );
        } else if (f.checking) {
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
                  : (net.linkUp
                        ? 'Connected. No internet.'
                        : 'This computer is not online.'),
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
          // The flow scans again by itself while offline.
          if (f.wifi.isEmpty) {
            p.add(
              f.wifiSearching
                  ? const StatusLine('Searching…', busy: true)
                  : Text(
                      'No networks found. Choose "Refresh".',
                      style: t.bodyDim,
                    ),
              gap: HinterTokens.s1,
            );
          } else if (!_listShown) {
            _listShown = true;
            _focusList();
          }
          // Keyed by name: a new scan does not move the focus.
          for (final ap in f.wifi) {
            final connected = ap.inUse || ap.ssid == net.wifiSsid;
            p.item(
              'w:${ap.ssid}',
              onSelect: ap.supported && !f.connecting ? () => _join(ap) : null,
              builder: (focused) => SettingRow(
                title: ap.ssid,
                focused: focused,
                dim: !ap.supported,
                leading: SignalBars(bars: ap.bars),
                subtitle: !ap.supported ? 'Not supported.' : null,
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
        if (f.waitingForDisks) {
          p.add(
            const StatusLine('Looking for disks…', busy: true),
            gap: HinterTokens.s3,
          );
        }
        p.buttons('actions', [
          if (net != null && net.wifiAvailable)
            btn('Refresh', () async {
              final scan = f.scanWifi();
              await f.refreshNetwork(force: true, plugWait: true);
              await scan;
              env.console.refocus();
            }, enabled: !f.connecting && !f.checking)
          else
            btn(
              linkComing && f.checking ? 'Connecting…' : 'Refresh',
              () => f.refreshNetwork(force: true, plugWait: true),
              enabled: !f.checking,
            ),
          btn(
            f.online ? 'Continue' : 'Continue without internet',
            f.next,
            primary: true,
            enabled: !f.waitingForDisks,
          ),
        ], gap: HinterTokens.s3);
        return StepPage(
          step: InstallerStep.network,
          flow: env.flow,
          child: scrolling(p.build()),
        );
      },
    );
  }
}

// ------------------------------------------------------------------ version

/// Only when the installer is online and the channel has a newer HinterOS:
/// the installer's own version (focused) or the newer one.
class VersionStep extends StatelessWidget {
  const VersionStep({super.key, required this.env});

  final StepEnv env;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: env.flow,
      builder: (context, _) {
        final f = env.flow;
        final t = HinterTheme.of(context);
        final p = Pane(env.region);
        final iso = f.isoRelease;
        final newer = f.newer;
        if (f.checkingNewer || iso == null || newer == null) {
          // Nothing to press while it looks: B goes back.
          p.add(const StatusLine('Looking for a newer HinterOS…', busy: true));
        } else {
          p.add(
            Text(
              'A newer HinterOS is on the ${f.channel.label} channel.',
              style: t.title,
            ),
          );
          p.add(
            Text('Choose the version to install.', style: t.bodyDim),
            gap: HinterTokens.s1,
          );
          p.buttons('iso', [
            btn(
              'Install ${f.releaseLabel(iso)}',
              () => f.chooseVersion(newer: false),
              primary: true,
            ),
          ], gap: HinterTokens.s4);
          p.add(
            Text('This version is on the USB stick.', style: t.caption),
            gap: HinterTokens.s1,
          );
          p.buttons('newer', [
            btn(
              'Install ${f.releaseLabel(newer)}',
              () => f.chooseVersion(newer: true),
            ),
          ], gap: HinterTokens.s4);
          p.add(
            Text('The newer version needs the internet.', style: t.caption),
            gap: HinterTokens.s1,
          );
        }
        return StepPage(
          step: InstallerStep.version,
          flow: f,
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
          f.keepData
              ? Text('Choose the disk to install HinterOS on.', style: t.body)
              : Text(
                  'Choose the disk to install HinterOS on. It will be erased.',
                  style: t.body.copyWith(color: t.danger),
                ),
        );
        if (disks == null || f.loadingDisks) {
          p.add(const StatusLine('Looking for disks...', busy: true));
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
        if (!f.loadingDisks && f.disksUnchecked) {
          p.add(
            const StatusLine(
              'Cannot look for HinterOS on the disks. To keep data, select '
              'Refresh.',
            ),
          );
        }
        if (disks != null && disks.isNotEmpty && !disks.any((d) => d.usable)) {
          p.add(
            const StatusLine(
              'No disk can be used. HinterOS needs an internal disk of at '
              'least $minDiskLabel.',
              error: true,
            ),
          );
        }
        final existing = f.disk?.existing;
        if (existing != null) {
          final keepable = f.disk!.canKeep;
          final down = f.keepDowngrade;
          if (keepable) {
            p.item(
              'keep',
              onSelect: () => f.chooseKeepData(true),
              builder: (focused) => SettingRow(
                title: 'Keep data',
                focused: focused,
                leading: CheckMark(checked: f.keepData),
                subtitle: down == null
                    ? null
                    : 'This replaces HinterOS ${down.disk} with the older '
                          '${down.usb}.',
              ),
              gap: HinterTokens.s3,
            );
          }
          p.item(
            'erase',
            onSelect: () => f.chooseKeepData(false),
            builder: (focused) => SettingRow(
              title: 'Erase all',
              focused: focused,
              leading: CheckMark(checked: !f.keepData),
            ),
            gap: keepable ? HinterTokens.s1 + 4 : HinterTokens.s3,
          );
          if (!keepable) {
            p.add(const StatusLine('Cannot keep data on this disk.'));
          }
        }
        p.buttons('actions', [
          btn('Refresh', f.loadDisks, enabled: !f.loadingDisks),
          // Confirmed once, on the summary (hold to install).
          btn(
            'Continue',
            f.next,
            primary: true,
            enabled: f.disk != null && !f.loadingDisks,
          ),
        ], gap: HinterTokens.s3);
        return StepPage(
          step: InstallerStep.disk,
          flow: env.flow,
          child: scrolling(p.build()),
        );
      },
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
        Widget value(String s, {bool dim = false}) =>
            Text(s, style: dim ? t.caption : t.bodyDim.copyWith(color: t.text));
        // Keep data: an empty password keeps the one on the disk.
        final unset = f.keepsPassword ? 'Not changed' : 'Not set';
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
                ? value(unset, dim: true)
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
            );
            if (v != null) f.setRepeat(v);
          },
          builder: (focused) => SettingRow(
            title: 'Password again',
            focused: focused,
            trailing: f.repeat.isEmpty
                ? value(unset, dim: true)
                : value('•' * f.repeat.runes.length.clamp(0, 24)),
          ),
        );
        final problem = f.accountProblem;
        if (problem != null) {
          p.add(StatusLine(problem, error: true), gap: HinterTokens.s3);
        }
        p.buttons('actions', [
          btn('Continue', f.next, primary: true, enabled: f.accountValid),
        ], gap: HinterTokens.s3);
        return StepPage(
          step: InstallerStep.account,
          flow: env.flow,
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
                'Lets other computers on your network log in as the admin.',
            focused: focused,
            trailing: ToggleMark(on: f.ssh),
          ),
        );
        p.item(
          'channel',
          onSelect: f.toggleChannel,
          builder: (focused) => SettingRow(
            title: 'Update channel',
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
          flow: env.flow,
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
          flow: env.flow,
          child: apps == null
              ? const Align(
                  alignment: Alignment.topLeft,
                  child: StatusLine('Loading apps...'),
                )
              : ClipRect(
                  clipper: const SideBleed(),
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

/// How long A is held on "Erase and install" or "Keep data and install" (the
/// one confirmation of what happens to the disk).
const eraseHold = Duration(seconds: 5);

/// The answers, and the one place that starts the install: a hold of
/// [eraseHold] on the button that says what it does. Back goes back.
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
        Widget line(String k, String v) => Padding(
          padding: const EdgeInsets.only(bottom: HinterTokens.s1),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 380, child: Text(k, style: t.bodyDim)),
              Expanded(child: Text(v, style: t.body)),
            ],
          ),
        );
        final d = f.disk;
        final keep = f.keepData;
        final down = f.keepDowngrade;
        final action = keep ? 'Keep data and install' : 'Erase and install';
        final mark = keep ? t.accent : t.danger;
        final appNames = [
          for (final a in f.apps?.selectedApps ?? const []) a.name,
        ];
        // The danger does not rely on colour alone: a heading and a border.
        // Keeping the data looks different, and says so in the same place.
        // It stays out of the scroll: with large text the rest scrolls to the
        // buttons, and the disk must stay in view.
        final card = Padding(
          padding: const EdgeInsets.fromLTRB(
            HinterTokens.s2,
            HinterTokens.s2,
            HinterTokens.s2,
            0,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(HinterTokens.s3),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(HinterTokens.radiusCard),
              border: Border.all(color: mark, width: 6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d == null
                      ? 'No disk'
                      : '${keep ? 'Keep data on' : 'Erase'} '
                            '${d.title}, ${d.sizeLabel}',
                  style: t.headline.copyWith(color: keep ? t.text : t.danger),
                ),
                // Two disks of the same model and size: the path tells them
                // apart, as on the disk step.
                if (d != null)
                  Text(
                    '${d.path}${d.transport != null ? ', ${d.transport}' : ''}',
                    style: t.bodyDim,
                  ),
                const SizedBox(height: HinterTokens.s1),
                Text(
                  keep
                      ? 'Your files stay on this disk. HinterOS is installed '
                            'again.'
                      : 'Everything on this disk is deleted. You cannot undo '
                            'this.',
                  style: t.body,
                ),
                if (keep && down != null)
                  Text(
                    'This replaces HinterOS ${down.disk} with the older '
                    '${down.usb}.',
                    style: t.body,
                  ),
              ],
            ),
          ),
        );
        p.add(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              line('Version', f.planVersionLabel),
              line('Admin user', f.username),
              if (keep)
                line(
                  'Admin password',
                  f.keepsPassword ? 'Not changed' : 'Changed',
                ),
              line('Computer name', f.hostname),
              line('SSH', f.ssh ? 'On' : 'Off'),
              line('Update channel', f.channel.label),
              if (!keep)
                line('Apps', appNames.isEmpty ? 'None' : appNames.join(', ')),
              line(
                'Internet',
                f.online
                    ? (f.planWifi != null ? 'Wi-Fi: ${f.planWifi}' : 'Online')
                    : 'Not used',
              ),
            ],
          ),
          gap: HinterTokens.s3,
        );
        p.row(
          'actions',
          2,
          Wrap(
            spacing: HinterTokens.s3,
            runSpacing: HinterTokens.s2,
            children: [
              NavFocusable(
                region: env.region,
                rowKey: 'actions',
                col: 0,
                onSelect: f.back,
                builder: (_, focused) =>
                    HButton(label: 'Back', focused: focused),
              ),
              HoldButton(
                region: env.region,
                rowKey: 'actions',
                col: 1,
                label: action,
                danger: !keep,
                duration: eraseHold,
                enabled: f.ready,
                onDone: () {
                  if (!f.ready) return;
                  f.go(InstallerStep.install);
                  f.startInstall();
                },
              ),
            ],
          ),
          gap: HinterTokens.s3,
        );
        p.add(
          Text(
            'Hold A on $action for ${eraseHold.inSeconds} seconds.',
            style: t.caption,
          ),
        );
        return StepPage(
          step: InstallerStep.summary,
          flow: env.flow,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              card,
              Expanded(
                child: PageScroll(
                  padding: const EdgeInsets.fromLTRB(
                    HinterTokens.s2,
                    HinterTokens.s3,
                    HinterTokens.s2,
                    HinterTokens.s2,
                  ),
                  child: p.build(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
