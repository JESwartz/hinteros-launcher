import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;

import '../theme/hinter_theme.dart';

/// An upstream README (GitHub Markdown) as read-only text in the launcher's
/// style. Links are plain text (the launcher opens no web pages from here);
/// images and raw HTML are left out, so badges and logos do not show.
class MarkdownView extends StatelessWidget {
  const MarkdownView(this.source, {super.key});

  final String source;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final nodes = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
    ).parseLines(source.replaceAll('\r\n', '\n').split('\n'));
    final blocks = _Blocks(t).build(nodes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: HinterTokens.s2),
          blocks[i],
        ],
      ],
    );
  }
}

/// Turns block nodes into widgets; inline nodes become [TextSpan]s.
class _Blocks {
  _Blocks(this.t);

  final HinterTokens t;

  List<Widget> build(List<md.Node> nodes) => [
    for (final n in nodes) ?_block(n),
  ];

  Widget? _block(md.Node n) {
    if (n is md.Text) return _paragraph([n], t.body);
    if (n is! md.Element) return null;
    final kids = n.children ?? const <md.Node>[];
    switch (n.tag) {
      case 'h1':
        return _paragraph(kids, t.title);
      case 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
        return _paragraph(kids, t.label);
      case 'p':
        return _paragraph(kids, t.body);
      case 'ul' || 'ol':
        return _list(n);
      case 'pre':
        return _code(n.textContent);
      case 'blockquote':
        final inner = build(kids);
        if (inner.isEmpty) return null;
        return Container(
          padding: const EdgeInsets.only(left: HinterTokens.s2),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: t.textDim, width: 4)),
          ),
          child: _column(inner),
        );
      case 'hr':
        return Divider(color: t.textDim, thickness: 2);
      case 'table':
        return _table(n);
      default:
        // Other containers (div from an HTML block, details): their content.
        final inner = build(kids);
        return inner.isEmpty ? null : _column(inner);
    }
  }

  Widget _column(List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(height: HinterTokens.s1),
        children[i],
      ],
    ],
  );

  /// Null when nothing readable is left (a paragraph of badges).
  Widget? _paragraph(List<md.Node> nodes, TextStyle style) {
    final spans = _inline(nodes, style);
    final plain = spans.map((s) => s.text ?? '').join();
    if (plain.trim().isEmpty) return null;
    return Text.rich(TextSpan(children: _trim(spans)), style: style);
  }

  Widget? _list(md.Element list) {
    final ordered = list.tag == 'ol';
    var number = int.tryParse(list.attributes['start'] ?? '') ?? 1;
    final items = <Widget>[];
    for (final li in list.children ?? const <md.Node>[]) {
      if (li is! md.Element || li.tag != 'li') continue;
      final body = _listItem(li);
      final marker = ordered ? '${number++}.' : '•';
      if (body == null) continue;
      items.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: HinterTokens.s5,
              child: Text(marker, style: t.body, textAlign: TextAlign.center),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }
    return items.isEmpty ? null : _column(items);
  }

  /// A list item's text, then its nested blocks (lists, paragraphs).
  Widget? _listItem(md.Element li) {
    final inline = <md.Node>[];
    final blocks = <Widget>[];
    for (final c in li.children ?? const <md.Node>[]) {
      final isBlock =
          c is md.Element &&
          const {'p', 'ul', 'ol', 'pre', 'blockquote', 'table'}.contains(c.tag);
      if (isBlock) {
        final w = _block(c);
        if (w != null) blocks.add(w);
      } else {
        inline.add(c);
      }
    }
    final head = inline.isEmpty ? null : _paragraph(inline, t.body);
    final all = [?head, ...blocks];
    return all.isEmpty ? null : _column(all);
  }

  Widget _code(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(HinterTokens.s2),
    decoration: BoxDecoration(
      color: t.surfaceHigh,
      borderRadius: BorderRadius.circular(HinterTokens.radiusSmall),
    ),
    child: Text(text.trimRight(), style: t.bodyDim),
  );

  Widget? _table(md.Element table) {
    final rows = <TableRow>[];
    void addRows(md.Node section, {required bool head}) {
      if (section is! md.Element) return;
      for (final tr in section.children ?? const <md.Node>[]) {
        if (tr is! md.Element || tr.tag != 'tr') continue;
        rows.add(
          TableRow(
            children: [
              for (final cell in tr.children ?? const <md.Node>[])
                if (cell is md.Element)
                  Padding(
                    padding: const EdgeInsets.all(HinterTokens.s1),
                    child:
                        _paragraph(
                          cell.children ?? const [],
                          head ? t.label : t.body,
                        ) ??
                        const SizedBox.shrink(),
                  ),
            ],
          ),
        );
      }
    }

    for (final s in table.children ?? const <md.Node>[]) {
      if (s is md.Element) addRows(s, head: s.tag == 'thead');
    }
    if (rows.isEmpty) return null;
    final width = rows.first.children.length;
    // Rows with a different number of cells than the head would throw.
    rows.removeWhere((r) => r.children.length != width);
    return Table(
      border: TableBorder.all(color: t.textDim, width: 1),
      defaultColumnWidth: const IntrinsicColumnWidth(),
      children: rows,
    );
  }

  List<TextSpan> _inline(List<md.Node> nodes, TextStyle style) {
    final out = <TextSpan>[];
    for (final n in nodes) {
      if (n is md.Text) {
        final text = _plain(n.text);
        if (text.isNotEmpty) out.add(TextSpan(text: text, style: style));
        continue;
      }
      if (n is! md.Element) continue;
      final kids = n.children ?? const <md.Node>[];
      switch (n.tag) {
        case 'strong':
          out.addAll(
            _inline(kids, style.copyWith(fontWeight: FontWeight.w700)),
          );
        case 'em':
          out.addAll(
            _inline(kids, style.copyWith(fontStyle: FontStyle.italic)),
          );
        case 'del':
          out.addAll(
            _inline(
              kids,
              style.copyWith(decoration: TextDecoration.lineThrough),
            ),
          );
        case 'code':
          out.add(
            TextSpan(
              text: n.textContent,
              style: style.copyWith(backgroundColor: t.surfaceHigh),
            ),
          );
        case 'br':
          out.add(TextSpan(text: '\n', style: style));
        case 'img':
          break;
        default:
          // a (plain text), and anything else: its content.
          out.addAll(_inline(kids, style));
      }
    }
    return out;
  }

  /// Leading and trailing white space of the whole paragraph removed (left
  /// over from images and HTML that were dropped).
  static List<TextSpan> _trim(List<TextSpan> spans) {
    final out = [...spans];
    while (out.isNotEmpty && (out.first.text ?? '').trim().isEmpty) {
      out.removeAt(0);
    }
    while (out.isNotEmpty && (out.last.text ?? '').trim().isEmpty) {
      out.removeLast();
    }
    if (out.isEmpty) return out;
    TextSpan with_(TextSpan s, String text) =>
        TextSpan(text: text, style: s.style);
    out[0] = with_(out.first, (out.first.text ?? '').trimLeft());
    out[out.length - 1] = with_(out.last, (out.last.text ?? '').trimRight());
    return out;
  }

  static final _tag = RegExp(r'<[^>]*>');
  static final _entity = RegExp(r'&(#x?[0-9a-fA-F]+|[a-z]+);');
  static const _named = {
    'amp': '&',
    'lt': '<',
    'gt': '>',
    'quot': '"',
    'apos': "'",
    'nbsp': ' ',
    'reg': '®',
    'copy': '©',
    'trade': '™',
  };

  /// Raw text without HTML tags, entities decoded.
  static String _plain(String s) {
    final noTags = s.replaceAll(_tag, '');
    return noTags.replaceAllMapped(_entity, (m) {
      final e = m[1]!;
      if (e.startsWith('#')) {
        final code = e.startsWith('#x') || e.startsWith('#X')
            ? int.tryParse(e.substring(2), radix: 16)
            : int.tryParse(e.substring(1));
        return code == null ? m[0]! : String.fromCharCode(code);
      }
      return _named[e] ?? m[0]!;
    });
  }
}
