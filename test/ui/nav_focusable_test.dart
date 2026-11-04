import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/nav/nav_controller.dart';
import 'package:hinteros_launcher/src/nav/nav_model.dart';
import 'package:hinteros_launcher/src/ui/nav_focusable.dart';

import '../support/modal_host_harness.dart';

void main() {
  testWidgets('an item that takes over a position keeps its close action', (
    t,
  ) async {
    final host = ModalTestHost();
    final region = NavRegion('cards');
    host.nav.adopt(region);
    region.setRows(const [NavRow('apps', 1)]);
    var backs = 0;
    host.nav.onBack = () {
      backs++;
      return true;
    };
    final running = ValueNotifier(false);
    addTearDown(running.dispose);
    final closed = <String>[];
    await host.pump(
      t,
      (_) => ValueListenableBuilder(
        valueListenable: running,
        // Keyed by state: the new card registers before the old one goes.
        builder: (_, on, _) => NavFocusable(
          key: ValueKey(on),
          region: region,
          rowKey: 'apps',
          col: 0,
          onContext: on ? () => closed.add('app') : null,
          builder: (_, _) => const SizedBox.square(dimension: 10),
        ),
      ),
    );
    host.nav.focusRegion(region);
    await t.pumpAndSettle();
    running.value = true;
    await t.pumpAndSettle();
    await host.act(t, NavAction.back);
    expect(closed, ['app']);
    expect(backs, 0);
    // And the other way: the running card's action goes with it.
    running.value = false;
    await t.pumpAndSettle();
    await host.act(t, NavAction.back);
    expect(closed, ['app']);
    expect(backs, 1);
  });
}
