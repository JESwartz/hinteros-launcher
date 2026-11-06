import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Goldens may differ by at most this fraction (0.0005 = 0.05%) of pixels (anti-aliasing noise
/// across Mesa/CPU variants).
const goldenTolerance = 0.0005;

/// Compares like [LocalFileComparator] but accepts a tiny difference.
class TolerantComparator extends LocalFileComparator {
  TolerantComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (!result.passed && result.diffPercent > goldenTolerance) {
      final error = await generateFailureOutput(result, golden, basedir);
      throw FlutterError(error);
    }
    return true;
  }
}

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    final bytes = File(f).readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

/// Applies to every test under test/golden: the bundled font is loaded
/// explicitly (the default test font is Ahem boxes) and the comparator is
/// the tolerant one.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadFont('AtkinsonHyperlegible', [
    'assets/fonts/AtkinsonHyperlegible-Regular.otf',
    'assets/fonts/AtkinsonHyperlegible-Bold.otf',
  ]);
  final base = goldenFileComparator as LocalFileComparator;
  goldenFileComparator = TolerantComparator(
    Uri.parse('${base.basedir}golden_test.dart'),
  );
  await testMain();
}
