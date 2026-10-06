import 'package:flutter/material.dart';

import '../theme/hinter_theme.dart';

/// Small heading above a row.
class RowHeader extends StatelessWidget {
  const RowHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HinterTokens.margin,
        0,
        HinterTokens.margin,
        HinterTokens.s1,
      ),
      child: Text(text, style: t.title),
    );
  }
}

/// A message in place of content (daemon unreachable, nothing here yet).
class Notice extends StatelessWidget {
  const Notice({super.key, required this.title, this.detail = ''});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: HinterTokens.margin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: t.title),
            if (detail.isNotEmpty) ...[
              const SizedBox(height: HinterTokens.s2),
              Text(detail, style: t.bodyDim),
            ],
          ],
        ),
      ),
    );
  }
}
