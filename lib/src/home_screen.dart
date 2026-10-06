import 'package:flutter/material.dart';

import 'fps_overlay.dart';

const cardCount = 12;
const _cardWidth = 280.0;
const _cardHeight = 380.0;
const _cardGap = 32.0;

/// Hello-world home screen: a title and one horizontally scrolling row of
/// focusable cards. Arrow keys move focus (stand-in for the D-pad).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.showFps = false});

  final bool showFps;

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
              const CardRow(),
              const Spacer(flex: 2),
            ],
          ),
          if (showFps) const FpsOverlay(),
        ],
      ),
    );
  }
}

class CardRow extends StatefulWidget {
  const CardRow({super.key});

  @override
  State<CardRow> createState() => _CardRowState();
}

class _CardRowState extends State<CardRow> {
  final _nodes = List.generate(
    cardCount,
    (i) => FocusNode(debugLabel: 'card $i'),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nodes.first.requestFocus();
    });
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
          itemCount: cardCount,
          separatorBuilder: (_, _) => const SizedBox(width: _cardGap),
          itemBuilder: (context, i) => FocusTraversalOrder(
            order: NumericFocusOrder(i.toDouble()),
            child: LauncherCard(index: i, focusNode: _nodes[i]),
          ),
        ),
      ),
    );
  }
}

class LauncherCard extends StatefulWidget {
  const LauncherCard({super.key, required this.index, required this.focusNode});

  final int index;
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
            'Card ${widget.index + 1}',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
