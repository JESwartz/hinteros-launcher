import 'dart:async';

import 'package:flutter/material.dart';

import '../../system/models.dart';
import '../../system/repositories.dart';
import '../../theme/hinter_theme.dart';
import '../app_icon_view.dart';
import '../dialogs.dart';
import '../modal_host.dart';
import '../pages.dart';
import '../profiles/profile_ui.dart' show withBoxAdminPin;
import '../qr_code.dart';
import '../system/common.dart' show runAdminJob;
import '../widgets.dart';
import 'library_pages.dart';
import 'server_model.dart';

/// A service's page on the Server tab: its state and setup. Every change
/// asks for the admin PIN and runs as a job on the job page; the page then
/// shows the new state.
class ServicePage extends StatefulWidget {
  const ServicePage({
    super.key,
    required this.modal,
    required this.model,
    required this.services,
    required this.id,
  });

  final ModalHandle<void> modal;
  final ServerModel model;
  final SystemServices services;

  /// The service's catalog id.
  final String id;

  @override
  State<ServicePage> createState() => _ServicePageState();
}

class _ServicePageState extends State<ServicePage> {
  final _code = TextEditingController(text: 'claim-');
  final _token = TextEditingController();
  String? _codeError;
  String? _tokenError;
  bool _revealToken = false;

  ServerRepository get _repo => widget.services.server;

  @override
  void initState() {
    super.initState();
    widget.model.addListener(_changed);
  }

  @override
  void dispose() {
    widget.model.removeListener(_changed);
    _code.dispose();
    _token.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  /// [start] with the admin PIN, then its job page; the list is read again
  /// after. Returns whether the job finished well.
  Future<bool> _job(
    String title,
    Future<JobHandle> Function(String? pin) start,
  ) async {
    final ok = await runAdminJob(
      context,
      widget.services,
      title: title,
      start: start,
    );
    await widget.model.reload();
    return ok;
  }

  Future<void> _turnOn(ServerService s) async {
    final accepted = <String, String>{};
    final terms = s.terms;
    if (terms != null) {
      if (!await showServiceTerms(context, name: s.name, terms: terms) ||
          !mounted) {
        return;
      }
      accepted[s.id] = terms.version;
    }
    await _job(
      'Turn on ${s.name}',
      (pin) => _repo.enable(s.id, pin: pin, acceptedTerms: accepted),
    );
  }

  Future<void> _turnOff(ServerService s) async {
    // A service keeps its data when it is off (`stateDirs`): it can go too.
    final data = s.hasData;
    final first = await showConfirm(
      context,
      title: 'Turn off ${s.name}?',
      checkbox: data ? 'Delete server data' : null,
      checkboxHint: data ? _dataHint(s) : null,
      confirmLabel: 'Turn off',
      danger: true,
    );
    if (first == null || !mounted) return;
    if (first.checked) {
      final second = await showConfirm(
        context,
        title: 'Delete all data of ${s.name}?',
        body:
            s.setup == ServiceSetup.jellyfinServer ||
                s.setup == ServiceSetup.plexMediaServer
            ? "The media files stay. You can't undo this."
            : "You can't undo this.",
        confirmLabel: 'Delete data and turn off',
        danger: true,
      );
      if (second == null || !mounted) return;
    }
    await _job(
      'Turn off ${s.name}',
      (pin) => _repo.disable(s.id, pin: pin, deleteData: first.checked),
    );
  }

  Future<void> _removeLibrary(JellyfinLibrary l) async {
    final ok = await showConfirm(
      context,
      title: 'Remove the library ${l.name}?',
      body: 'The media files stay.',
      confirmLabel: 'Remove',
      danger: true,
    );
    if (ok == null || !mounted) return;
    await _job(
      'Remove the library ${l.name}',
      (pin) => _repo.removeLibrary(l.id, pin: pin),
    );
  }

  Future<void> _addLibrary() async {
    await ModalScope.of(context).show<void>(
      (c, modal) => AddLibraryPage(modal: modal, services: widget.services),
    );
    await widget.model.reload();
  }

  Future<void> _showAccounts() async {
    final JellyfinAccounts? accounts;
    try {
      accounts = await withBoxAdminPin(
        context,
        widget.services.profiles,
        title: 'Show accounts',
        action: (pin) => _repo.revealAccounts(pin: pin),
      );
    } on SystemException catch (e) {
      if (mounted) {
        await showMessage(context, title: "That didn't work", body: e.message);
      }
      return;
    }
    if (accounts == null || !mounted) return;
    await ModalScope.of(
      context,
    ).show<void>((c, modal) => AccountsPage(modal: modal, accounts: accounts!));
  }

  Future<void> _link() async {
    final code = _code.text.trim();
    if (!plexClaimCode.hasMatch(code)) {
      setState(() => _codeError = 'The code is not correct.');
      return;
    }
    setState(() => _codeError = null);
    if (await _job('Link Plex', (pin) => _repo.claimPlex(code, pin: pin))) {
      _code.text = 'claim-';
    }
  }

  Future<void> _saveToken() async {
    final token = _token.text.trim();
    if (token.isEmpty) {
      setState(() => _tokenError = 'Type the token.');
      return;
    }
    setState(() => _tokenError = null);
    if (await _job(
      'Save the token',
      (pin) => _repo.setCloudflareToken(token, pin: pin),
    )) {
      _token.clear();
      if (mounted) setState(() => _revealToken = false);
    }
  }

  Future<void> _removeToken() async {
    final ok = await showConfirm(
      context,
      title: 'Remove the token?',
      body: 'The tunnel stops.',
      confirmLabel: 'Remove',
      danger: true,
    );
    if (ok == null || !mounted) return;
    await _job(
      'Remove the token',
      (pin) => _repo.clearCloudflareToken(pin: pin),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.model.byId(widget.id);
    final region = widget.modal.region;
    if (s == null) {
      final p = Pane(region)
        ..add(const StatusLine('This service is not there any more.'))
        ..buttons('actions', [btn('Back', widget.modal.close, primary: true)]);
      return FullPage(title: 'Server', child: p.build());
    }
    final p = Pane(region);
    Widget? side;
    if (!s.enabled) {
      // Its terms must be read in full first.
      if (s.termsMissing) {
        p.add(const StatusLine('The terms are not on this box.', error: true));
      }
      p.buttons('actions', [
        btn(
          'Turn on',
          () => _turnOn(s),
          primary: true,
          enabled: !s.termsMissing,
        ),
      ]);
    } else {
      switch (s.detail) {
        case final JellyfinDetail d:
          _jellyfin(p, s, d);
        case final PlexDetail d:
          _plex(p, s, d);
          if (!d.claimed) side = const _ClaimCode();
        case final TailscaleDetail d:
          _tailscale(p, s, d);
        case final CloudflareDetail d:
          _cloudflare(p, s, d);
        case null:
          if (!s.available) {
            p.add(
              const StatusLine('This version of HinterOS no longer has it.'),
            );
          }
          p.buttons('actions', [
            btn('Turn off', () => _turnOff(s), danger: true),
          ]);
      }
    }
    return FullPage(
      title: s.name,
      subtitle: s.state.label,
      leading: AppIconBadge(name: s.name, iconPath: s.iconPath, size: 128),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              clipBehavior: Clip.none,
              child: p.build(),
            ),
          ),
          if (side != null) ...[const SizedBox(width: HinterTokens.s5), side],
        ],
      ),
    );
  }

  void _turnOffButton(Pane p, ServerService s) => p.buttons('actions', [
    btn('Turn off', () => _turnOff(s), danger: true),
  ], gap: HinterTokens.s4);

  void _jellyfin(Pane p, ServerService s, JellyfinDetail d) {
    final t = HinterTheme.of(context);
    if (!d.setupDone) p.add(const StatusLine('Setting up...'));
    if (d.url != null) p.add(InfoLine('Address', d.url!));
    p.add(Text('Libraries', style: t.title), gap: HinterTokens.s4);
    if (d.libraries.isEmpty) p.add(Text('No libraries.', style: t.bodyDim));
    for (final l in d.libraries) {
      p.item(
        'lib-${l.id}',
        // A library made in Jellyfin's dashboard can be removed too.
        onSelect: d.setupDone ? () => _removeLibrary(l) : null,
        builder: (f) => SettingRow(
          title: l.name,
          subtitle: librarySubtitle(l),
          focused: f,
          trailing: Text('Remove', style: t.label.copyWith(color: t.danger)),
        ),
      );
    }
    p.buttons('add', [
      btn('Add library', _addLibrary, primary: true, enabled: d.setupDone),
    ]);
    p.buttons('actions', [
      btn('Show accounts', _showAccounts, enabled: d.setupDone),
      btn('Turn off', () => _turnOff(s), danger: true),
    ], gap: HinterTokens.s4);
  }

  void _plex(Pane p, ServerService s, PlexDetail d) {
    final t = HinterTheme.of(context);
    p.add(
      d.claimed
          ? const StatusLine('Linked to a Plex account.', ok: true)
          : const StatusLine('Not linked to a Plex account.'),
    );
    if (d.serverName != null) p.add(InfoLine('Name', d.serverName!));
    if (d.url != null) p.add(InfoLine('Address', d.url!));
    if (!d.claimed) {
      p.add(Text('Claim code', style: t.title), gap: HinterTokens.s4);
      p.row(
        'code',
        1,
        NavTextField(
          region: p.region,
          rowKey: 'code',
          controller: _code,
          hint: 'claim-',
          onSubmit: _link,
        ),
      );
      if (_codeError != null) p.add(StatusLine(_codeError!, error: true));
      p.buttons('link', [btn('Link', _link, primary: true)]);
    }
    _turnOffButton(p, s);
  }

  void _tailscale(Pane p, ServerService s, TailscaleDetail d) {
    final running = d.state == TailscaleState.running;
    p.add(switch (d.state) {
      TailscaleState.running => const StatusLine('Signed in.', ok: true),
      TailscaleState.needsLogin => const StatusLine('Not signed in.'),
      TailscaleState.needsApproval => const StatusLine(
        'The tailnet admin must approve this box.',
      ),
      TailscaleState.starting => const StatusLine('Starting...'),
      TailscaleState.stopped => const StatusLine('Stopped.'),
      TailscaleState.unavailable => const StatusLine(
        'Tailscale does not answer.',
        error: true,
      ),
    });
    if (d.name != null) p.add(InfoLine('Name', d.name!));
    if (d.ip4 != null) p.add(InfoLine('Address', d.ip4!));
    if (d.dnsName != null) p.add(InfoLine('DNS name', d.dnsName!));
    if (d.tailnet != null) p.add(InfoLine('Tailnet', d.tailnet!));
    if (running) {
      p.add(
        InfoLine(
          'Key expires',
          d.keyExpiry == null ? 'Never' : _date(d.keyExpiry!),
        ),
      );
    }
    p.buttons('actions', [
      if (running)
        btn(
          'Sign out',
          () => _job('Sign out', (pin) => _repo.tailscaleLogout(pin: pin)),
        )
      else
        btn(
          'Sign in',
          () => _job('Sign in', (pin) => _repo.tailscaleLogin(pin: pin)),
          primary: true,
        ),
      btn('Turn off', () => _turnOff(s), danger: true),
    ], gap: HinterTokens.s4);
  }

  void _cloudflare(Pane p, ServerService s, CloudflareDetail d) {
    final t = HinterTheme.of(context);
    p.add(
      d.connected
          ? const StatusLine('Connected.', ok: true)
          : d.tokenSet
          ? const StatusLine('Not connected.', error: true)
          : const StatusLine('No token.'),
    );
    p.add(
      d.localIp == null
          ? const StatusLine('No local network address.', error: true)
          : InfoLine('Route this address in Zero Trust', d.localIp!),
    );
    p.add(Text('Tunnel token', style: t.title), gap: HinterTokens.s4);
    // The token runs the tunnel: hidden like a password, the eye shows it.
    p.row(
      'token',
      2,
      NavTextField(
        region: p.region,
        rowKey: 'token',
        controller: _token,
        obscure: !_revealToken,
        hint: d.tokenSet ? 'New token' : 'Token',
        onSubmit: _saveToken,
        onReveal: () => setState(() => _revealToken = !_revealToken),
      ),
    );
    if (_tokenError != null) p.add(StatusLine(_tokenError!, error: true));
    p.buttons('token-actions', [
      btn('Save token', _saveToken, primary: true),
      btn('Remove token', _removeToken, enabled: d.tokenSet),
    ]);
    _turnOffButton(p, s);
  }

  /// The day [d] is in the box's zone (the top bar clock's).
  String _date(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final z = widget.model.zone;
    final l = z == null ? d.toLocal() : z.wallClock(d);
    return '${l.year}-${two(l.month)}-${two(l.day)}';
  }
}

/// A library row's subtitle: its kind, then its folder under /srv/media
/// ("Movies · /srv/media/Movies"); only the kind when it has no folder there.
String librarySubtitle(JellyfinLibrary l) {
  final f = l.folder;
  return f == null ? l.kind.label : '${l.kind.label} · /srv/media/$f';
}

/// What "Delete server data" removes, by setup.
String _dataHint(ServerService s) => switch (s.setup) {
  ServiceSetup.jellyfinServer => 'Libraries, accounts and settings.',
  ServiceSetup.plexMediaServer => 'Libraries, account link and settings.',
  ServiceSetup.tailscale => 'Sign-in and settings.',
  ServiceSetup.cloudflareTunnel => 'The tunnel token.',
  ServiceSetup.none => 'All settings of the service.',
};

/// "Address: http://192.168.1.42:8096": a name and its value.
class InfoLine extends StatelessWidget {
  const InfoLine(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$label: ', style: t.bodyDim),
          TextSpan(text: value, style: t.body),
        ],
      ),
    );
  }
}

/// Where a Plex claim code comes from: plex.tv/claim as a QR code.
class _ClaimCode extends StatelessWidget {
  const _ClaimCode();

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return Column(
      key: const ValueKey('plex-claim-qr'),
      children: [
        const QrCodeView(data: plexClaimUrl, size: 320),
        const SizedBox(height: HinterTokens.s2),
        Text('plex.tv/claim', style: t.title),
      ],
    );
  }
}

/// The Jellyfin accounts and passwords for other devices
/// (`jellyfin.users.reveal`). Nothing is kept when the page closes.
class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key, required this.modal, required this.accounts});

  final ModalHandle<void> modal;
  final JellyfinAccounts accounts;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final rows = [
      if (accounts.admin case final a?) ('Admin', a.name, a.password),
      for (final u in accounts.users) (u.profileName ?? '', u.name, u.password),
    ];
    TableRow row(List<String> cells, TextStyle style) => TableRow(
      children: [
        for (final c in cells)
          Padding(
            padding: const EdgeInsets.only(
              right: HinterTokens.s4,
              bottom: HinterTokens.s2,
            ),
            child: Text(c, style: style),
          ),
      ],
    );
    final p = Pane(modal.region)
      ..add(
        Table(
          key: const ValueKey('jellyfin-accounts'),
          defaultColumnWidth: const IntrinsicColumnWidth(),
          children: [
            row(const ['Profile', 'User', 'Password'], t.bodyDim),
            for (final (who, name, password) in rows)
              row([who, name, password], t.label),
          ],
        ),
      )
      ..buttons('actions', [
        btn('Close', modal.close, primary: true),
      ], gap: HinterTokens.s4);
    return FullPage(
      title: 'Jellyfin accounts',
      child: PageScroll(child: p.build()),
    );
  }
}
