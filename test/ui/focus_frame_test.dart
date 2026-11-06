import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/settings/launcher_settings.dart';
import 'package:hinteros_launcher/src/theme/hinter_theme.dart';
import 'package:hinteros_launcher/src/ui/focus_frame.dart';
import 'package:hinteros_launcher/src/ui/visible_box.dart';

/// Three items of [size] side by side, [gap] apart, the middle one focused.
Future<void> _row(
  WidgetTester t,
  Size size, {
  double scale = HinterTokens.focusScale,
  double gap = HinterTokens.focusSpacing,
}) async {
  t.view.physicalSize = const Size(1920, 1080);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  Widget item(int i) => FocusFrame(
    key: ValueKey('item$i'),
    focused: i == 1,
    scale: scale,
    gap: gap,
    child: SizedBox.fromSize(size: size),
  );
  await t.pumpWidget(
    HinterTheme(
      tokens: HinterTokens.fromSettings(const LauncherSettings()),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              item(0),
              SizedBox(width: gap),
              item(1),
              SizedBox(width: gap),
              item(2),
            ],
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

/// The focused item's outer ring, as drawn (scaled).
Rect _ring(WidgetTester t) => t.getRect(
  find
      .descendant(
        of: find.byKey(const ValueKey('item1')),
        matching: find.byType(VisibleDecoratedBox),
      )
      .first,
);

Rect _item(WidgetTester t, int i) => t.getRect(find.byKey(ValueKey('item$i')));

void main() {
  group('grownScale', () {
    test('small items get the full scale', () {
      expect(FocusFrame.grownScale(const Size(288, 162), 1.08, 32), 1.08);
      expect(FocusFrame.grownScale(const Size(180, 64), 1.05, 24), 1.05);
    });

    test('wide items grow only as far as the gap allows', () {
      const size = Size(520, 150);
      final s = FocusFrame.grownScale(size, 1.08, 24);
      expect(s, lessThan(1.08));
      expect(s, greaterThan(1));
      final reach = size.width / 2 * (s - 1) + HinterTokens.focusReach * s;
      expect(reach, closeTo(24 - HinterTokens.focusClear, 1e-9));
    });

    test('never shrinks, and scale 1 stays 1', () {
      expect(FocusFrame.grownScale(const Size(2000, 100), 1.08, 8), 1);
      expect(FocusFrame.grownScale(const Size(100, 100), 1, 24), 1);
    });
  });

  for (final (name, size, gap) in [
    ('a Store card', const Size(520, 150), HinterTokens.s3),
    ('a button', const Size(180, 64), HinterTokens.s3),
    ('a Home tile', const Size(384, 216), HinterTokens.s4),
  ]) {
    testWidgets('the focused ring stays clear of the next item: $name', (
      t,
    ) async {
      await _row(t, size, gap: gap);
      final ring = _ring(t);
      // It did grow: the ring is past the focusReach of the bare item.
      expect(ring.width, greaterThan(size.width + 2 * HinterTokens.focusReach));
      expect(
        _item(t, 2).left - ring.right,
        greaterThanOrEqualTo(HinterTokens.focusClear - 0.01),
      );
      expect(
        ring.left - _item(t, 0).right,
        greaterThanOrEqualTo(HinterTokens.focusClear - 0.01),
      );
    });
  }
}
