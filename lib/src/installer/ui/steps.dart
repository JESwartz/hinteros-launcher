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

Widget scrolling(Widget pane) => ClipRect(
  clipper: const _SideBleed(),
  child: SingleChildScrollView(
    clipBehavior: Clip.none,
    padding: const EdgeInsets.all(HinterTokens.s2),
    child: pane,
  ),
);

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
    p.add(
      Text(
        'The installer asks before it erases a disk.',
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
                        ? "Connected, but can't reach the internet."
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
        p.buttons('actions', [
          if (net != null && net.wifiAvailable)
            btn('Search again', () async {
              final scan = f.scanWifi();
              await f.refreshNetwork(force: true, plugWait: true);
              await scan;
              env.console.refocus();
            }, enabled: !f.scanning && !f.connecting && !f.checking)
          else
            btn(
              linkComing && f.checking ? 'Connecting…' : 'Check again',
              () => f.refreshNetwork(force: true, plugWait: true),
              enabled: !f.checking,
            ),
          btn(
            f.online ? 'Continue' : 'Continue without internet',
            f.next,
            primary: true,
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
        if (disks != null && disks.isNotEmpty && !disks.any((d) => d.usable)) {
          p.add(
            const StatusLine(
              'No disk can be used. HinterOS needs an internal disk of at '
              'least 16 GB.',
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
          btn('Look again', f.loadDisks, enabled: !f.loadingDisks),
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
        // A keepData plan keeps the computer name and SSH of the install.
        final keep = f.keepData;
        if (!keep) {
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
        }
        p.item(
          'channel',
          onSelect: f.toggleChannel,
          builder: (focused) => SettingRow(
            title: 'Update channel',
            focused: focused,
            trailing: Text(f.channel.label, style: t.body),
          ),
        );
        final problem = keep ? null : f.hostnameProblem;
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
        final action = keep ? 'Keep data and install' : 'Erase and install';
        final mark = keep ? t.accent : t.danger;
        final appNames = [
          for (final a in f.apps?.selectedApps ?? const []) a.name,
        ];
        // The danger does not rely on colour alone: a heading and a border.
        // Keeping the data looks different, and says so in the same place.
        p.add(
          Container(
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
                const SizedBox(height: HinterTokens.s1),
                Text(
                  keep
                      ? 'Your files stay on this disk. HinterOS is installed '
                            'again.'
                      : 'Everything on this disk is deleted. You cannot undo '
                            'this.',
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
              if (!keep) ...[
                line('Admin user', f.username),
                line('Computer name', f.hostname),
                line('SSH', f.ssh ? 'On' : 'Off'),
              ],
              line('Update channel', f.channel.label),
              if (!keep)
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
          gap: HinterTokens.s3,
        );
        p.row(
          'actions',
          2,
          Wrap(
            spacing: HinterTokens.s2,
            runSpacing: HinterTokens.s1,
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
