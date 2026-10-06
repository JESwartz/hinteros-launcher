import 'dart:async';

import 'package:flutter/material.dart';

import 'api/api.dart';
import 'fps_overlay.dart';

const _cardWidth = 280.0;
const _cardHeight = 380.0;
const _cardGap = 32.0;

/// Home screen: a title and one horizontally scrolling row of focusable cards,
/// one per app the daemon lists. Arrow keys move focus (stand-in for the
/// D-pad). When the daemon is unreachable or speaks another API version, a
/// message replaces the row.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.connection, this.showFps = false});

  final DaemonConnection connection;
  final bool showFps;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _rowKey = GlobalKey<_CardRowState>();
  late ConnectionStatus _status;
  List<App>? _apps;
  Object? _appsError;
  StreamSubscription<ConnectionStatus>? _statusSub;
  StreamSubscription<SessionEvent>? _eventSub;

  @override
  void initState() {
    super.initState();
    final c = widget.connection;
    _status = c.status;
    _statusSub = c.statusChanges.listen(_onStatus);
    _eventSub = c.events.listen((e) {
      // Home resets the launcher to its first card.
      if (e is HomePressedEvent) _rowKey.currentState?.focusFirst();
    });
    c.start();
    unawaited(c.subscribeTo([EventName.homePressed]).catchError((_) {}));
    if (_status is Connected) _refresh();
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _eventSub?.cancel();
    super.dispose();
  }

  void _onStatus(ConnectionStatus s) {
    if (!mounted) return;
    final wasConnected = _status is Connected;
    setState(() => _status = s);
    // Events are not replayed and state is not kept across reconnects, so
    // re-query what we show.
    if (s is Connected && !wasConnected) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final r = await widget.connection.appsList();
      if (!mounted) return;
      setState(() {
        _apps = r.apps;
        _appsError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _appsError = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(96, 72, 96, 0),
                child: Text(
                  'HinterOS',
                  style: TextStyle(
                    fontSize: 96,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const Spacer(),
              _body(),
              const Spacer(flex: 2),
            ],
          ),
          if (widget.showFps) const FpsOverlay(),
        ],
      ),
    );
  }

  Widget _body() {
    final s = _status;
    switch (s) {
      case Connected():
        final apps = _apps;
        if (_appsError != null && apps == null) {
          return const _Notice(
            title: "Couldn't load apps",
            detail:
                'The HinterOS service did not answer. Retrying on reconnect.',
          );
        }
        if (apps == null) return const SizedBox(height: _cardHeight + 80);
        if (apps.isEmpty) {
          return const _Notice(title: 'No apps yet', detail: '');
        }
        return CardRow(key: _rowKey, apps: apps);
      case VersionMismatch():
        return _Notice(
          title: "Launcher and system service versions don't match",
          detail:
              'This launcher speaks API ${s.clientApiVersion}, the service '
              'speaks ${s.serverApiVersion}. Retrying; an update may be half applied.',
        );
      case Unreachable():
        return _Notice(
          title: "Can't reach the HinterOS service",
          detail: '${s.reason}. Retrying.',
        );
      case Connecting():
        return const _Notice(
          title: 'Connecting to the HinterOS service',
          detail: '',
        );
    }
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _cardHeight + 80,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 96),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w600),
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              detail,
              style: const TextStyle(fontSize: 28, color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }
}

class CardRow extends StatefulWidget {
  const CardRow({super.key, required this.apps});

  final List<App> apps;

  @override
  State<CardRow> createState() => _CardRowState();
}

class _CardRowState extends State<CardRow> {
  late List<FocusNode> _nodes = _makeNodes();

  List<FocusNode> _makeNodes() => List.generate(
    widget.apps.length,
    (i) => FocusNode(debugLabel: 'card $i'),
  );

  void focusFirst() {
    if (_nodes.isNotEmpty) _nodes.first.requestFocus();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) focusFirst();
    });
  }

  @override
  void didUpdateWidget(CardRow old) {
    super.didUpdateWidget(old);
    if (old.apps.length != widget.apps.length) {
      final old = _nodes;
      _nodes = _makeNodes();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final n in old) {
          n.dispose();
        }
        if (mounted) focusFirst();
      });
    }
  }

  @override
  void dispose() {
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: SizedBox(
        height: _cardHeight + 80, // room for the focus scale-up
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 96, vertical: 40),
          itemCount: widget.apps.length,
          separatorBuilder: (_, _) => const SizedBox(width: _cardGap),
          itemBuilder: (context, i) => FocusTraversalOrder(
            order: NumericFocusOrder(i.toDouble()),
            child: LauncherCard(
              index: i,
              app: widget.apps[i],
              focusNode: _nodes[i],
            ),
          ),
        ),
      ),
    );
  }
}

class LauncherCard extends StatefulWidget {
  const LauncherCard({
    super.key,
    required this.index,
    required this.app,
    required this.focusNode,
  });

  final int index;
  final App app;
  final FocusNode focusNode;

  @override
  State<LauncherCard> createState() => _LauncherCardState();
}

class _LauncherCardState extends State<LauncherCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final hue = (widget.index * 30.0) % 360;
    final base = HSLColor.fromAHSL(1, hue, 0.45, 0.28).toColor();
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (focused) {
        setState(() => _focused = focused);
        if (focused) {
          Scrollable.ensureVisible(
            context,
            alignment: 0.5,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
          );
        }
      },
      child: AnimatedScale(
        scale: _focused ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: _cardWidth,
          height: _cardHeight,
          alignment: Alignment.bottomLeft,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _focused ? Colors.white : Colors.transparent,
              width: 6,
            ),
            boxShadow: _focused
                ? const [BoxShadow(color: Colors.black87, blurRadius: 32)]
                : const [],
          ),
          child: Text(
            widget.app.name,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
