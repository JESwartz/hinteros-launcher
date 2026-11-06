import 'dart:async';

import 'package:flutter/material.dart';

import '../../nav/nav_controller.dart';
import '../../nav/nav_model.dart';
import '../../system/repositories.dart';
import '../../theme/hinter_theme.dart';
import '../app_icon_view.dart';
import '../common.dart';
import '../focus_frame.dart';
import '../modal_host.dart';
import '../nav_focusable.dart';
import '../system/common.dart' show describeError;
import '../visible_box.dart';
import 'server_model.dart';
import 'service_page.dart';

/// The Server tab (session API 0.19): one row per
/// box-wide service with its state. Every profile sees it; A opens the
/// service's page, where each change asks for the admin PIN.
class ServerScreen extends StatefulWidget {
  const ServerScreen({
    super.key,
    required this.model,
    required this.services,
    required this.region,
    this.onPopulated,
  });

  final ServerModel model;
  final SystemServices services;
  final NavRegion region;

  /// The rows are in the region (the shell may move focus in then).
  final VoidCallback? onPopulated;

  @override
  State<ServerScreen> createState() => _ServerScreenState();
}

class _ServerScreenState extends State<ServerScreen> {
  Timer? _retry;

  @override
  void initState() {
    super.initState();
    widget.model.addListener(_changed);
    widget.model.start();
    if (widget.model.list != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onPopulated?.call();
      });
    }
  }

  @override
  void dispose() {
    _retry?.cancel();
    widget.model.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    final m = widget.model;
    if (m.list != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onPopulated?.call();
      });
    } else if (m.error != null) {
      // The system service may only be late: look again.
      _retry?.cancel();
      _retry = Timer(const Duration(seconds: 5), () {
        if (mounted && widget.model.list == null) {
          unawaited(widget.model.reload());
        }
      });
    }
  }

  void _open(BuildContext context, ServerService s) {
    unawaited(
      ModalScope.of(context)
          .show<void>(
            (c, modal) => ServicePage(
              modal: modal,
              model: widget.model,
              services: widget.services,
              id: s.id,
            ),
          )
          .then((_) => widget.model.reload()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.model;
    final list = m.list;
    if (list == null) {
      widget.region.setRows(const []);
      return Notice(
        title: m.error == null
            ? 'Loading...'
            : "The Server section isn't "
                  'available',
        detail: m.error == null ? '' : describeError(m.error!),
      );
    }
    final services = list.services;
    widget.region.setRows([
      for (var i = 0; i < services.length; i++) NavRow('s$i', 1),
    ]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const RowHeader('Server'),
        Expanded(
          child: SingleChildScrollView(
            clipBehavior: Clip.none,
            padding: const EdgeInsets.fromLTRB(
              HinterTokens.margin,
              HinterTokens.s2,
              HinterTokens.margin,
              HinterTokens.s4,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (services.isEmpty)
                    Text(
                      'No services in this version of HinterOS.',
                      style: HinterTheme.of(context).bodyDim,
                    ),
                  for (var i = 0; i < services.length; i++) ...[
                    if (i > 0) const SizedBox(height: HinterTokens.s2),
                    NavFocusable(
                      region: widget.region,
                      rowKey: 's$i',
                      col: 0,
                      onSelect: () => _open(context, services[i]),
                      builder: (_, f) =>
                          ServiceRow(service: services[i], focused: f),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A service in the list: icon, name, state.
class ServiceRow extends StatelessWidget {
  const ServiceRow({super.key, required this.service, required this.focused});

  final ServerService service;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return FocusFrame(
      focused: focused,
      radius: HinterTokens.radiusCard,
      scale: 1.02,
      child: VisibleDecoratedBox(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(HinterTokens.radiusCard),
          border: t.highContrast
              ? Border.all(color: t.textDim, width: 2)
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(HinterTokens.s2),
          child: Row(
            children: [
              AppIconBadge(
                name: service.name,
                iconPath: service.iconPath,
                size: 88,
              ),
              const SizedBox(width: HinterTokens.s3),
              Expanded(
                child: Text(
                  service.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.label,
                ),
              ),
              const SizedBox(width: HinterTokens.s2),
              ServiceStateMark(state: service.state),
            ],
          ),
        ),
      ),
    );
  }
}

/// The state in words, with a colour that only adds to them.
class ServiceStateMark extends StatelessWidget {
  const ServiceStateMark({super.key, required this.state});

  final ServiceState state;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final color = switch (state) {
      ServiceState.running => t.positive,
      ServiceState.error => t.danger,
      ServiceState.needsSetup => t.accent,
      ServiceState.starting || ServiceState.off => t.textDim,
    };
    return Text(
      state.label,
      key: const ValueKey('service-state'),
      style: t.label.copyWith(
        color: color,
        fontWeight: state == ServiceState.off
            ? FontWeight.w400
            : FontWeight.w700,
      ),
    );
  }
}
