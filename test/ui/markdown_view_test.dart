import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/settings/launcher_settings.dart';
import 'package:hinteros_launcher/src/theme/hinter_theme.dart';
import 'package:hinteros_launcher/src/ui/markdown_view.dart';

Future<void> show(WidgetTester t, String source) => t.pumpWidget(
  MaterialApp(
    home: HinterTheme(
      tokens: HinterTokens.fromSettings(const LauncherSettings()),
      child: SingleChildScrollView(child: MarkdownView(source)),
    ),
  ),
);

void main() {
  testWidgets('headings, lists, code and tables as text', (t) async {
    await show(t, '''
# Title

Some **bold** and `code`.

- one
- two
  1. nested

```
make all
```

| A | B |
|---|---|
| 1 | 2 |
''');
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Some bold and code.'), findsOneWidget);
    expect(find.text('•'), findsNWidgets(2));
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('nested'), findsOneWidget);
    expect(find.text('make all'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('links are plain text; images and HTML are left out', (t) async {
    await show(t, '''
<p align="center">
  <a href="https://x"><img src="https://img.shields.io/b.svg" /></a>
</p>

[![Build](https://img.shields.io/x.svg)](https://ci)

See [the site](https://example.org) &amp; more.
''');
    expect(find.text('See the site & more.'), findsOneWidget);
    expect(find.textContaining('shields'), findsNothing);
    expect(find.textContaining('<'), findsNothing);
    expect(find.textContaining('Build'), findsNothing);
  });
}
