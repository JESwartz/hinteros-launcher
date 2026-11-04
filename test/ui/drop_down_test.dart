import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/nav/nav_controller.dart';
import 'package:hinteros_launcher/src/nav/nav_model.dart';
import 'package:hinteros_launcher/src/ui/drop_down.dart';

import '../support/modal_host_harness.dart';

void main() {
  testWidgets('an open list closes when its field goes', (t) async {
    final host = ModalTestHost();
    final region = NavRegion('pane');
    host.nav.adopt(region);
    region.setRows(const [NavRow('mode', 1)]);
    final show = ValueNotifier(true);
    addTearDown(show.dispose);
    final chosen = <int>[];
    await host.pump(
      t,
      (_) => ValueListenableBuilder(
        valueListenable: show,
        builder: (_, on, _) => on
            ? Center(
                child: DropDown<int>(
                  region: region,
                  rowKey: 'mode',
                  field: const Text('One'),
                  groups: () => [
                    DropDownGroup(null, [
                      for (final i in [1, 2, 3])
                        DropDownChoice(
                          value: i,
                          current: i == 1,
                          build: (_) => Text('Choice $i'),
                        ),
                    ]),
                  ],
                  onChoose: chosen.add,
                ),
              )
            : const SizedBox(),
      ),
    );
    host.nav.focusRegion(region);
    await t.pumpAndSettle();
    await host.act(t, NavAction.accept);
    expect(find.byKey(const ValueKey('drop-down-list')), findsOneWidget);
    expect(host.modals.isOpen, isTrue);
    // The pane is rebuilt without the field (a reload, a hotplug).
    show.value = false;
    await t.pumpAndSettle();
    expect(host.modals.isOpen, isFalse);
    expect(find.byKey(const ValueKey('drop-down-list')), findsNothing);
    expect(chosen, isEmpty);
  });
}
