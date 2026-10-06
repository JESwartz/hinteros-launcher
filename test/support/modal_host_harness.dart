import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/api/api.dart';
import 'package:hinteros_launcher/src/nav/nav_controller.dart';
import 'package:hinteros_launcher/src/settings/launcher_settings.dart';
import 'package:hinteros_launcher/src/theme/hinter_theme.dart';
import 'package:hinteros_launcher/src/ui/modal_host.dart';

/// A bare host for screens that live outside the launcher shell (the
/// installer's app selection, a modal on its own): theme, nav controller and
/// modal host, with actions sent straight to the nav layer.
class ModalTestHost {
  ModalTestHost({LauncherSettings settings = const LauncherSettings()})
    : tokens = HinterTokens.fromSettings(settings),
      settings = settings {
    modals = ModalController(nav);
  }

  final HinterTokens tokens;
  final LauncherSettings settings;
  final nav = NavController();
  late final ModalController modals;

  Future<void> pump(WidgetTester t, Widget Function(BuildContext) body) async {
    await t.pumpWidget(
      MaterialApp(
        theme: HinterTheme.material(tokens),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(settings.textScale)),
          child: HinterTheme(tokens: tokens, child: child!),
        ),
        home: Scaffold(
          body: ModalHost(
            controller: modals,
            child: Builder(builder: body),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  /// One controller action (press), then settle.
  Future<void> act(WidgetTester t, NavAction a) async {
    nav.dispatch(a, NavPhase.press);
    await t.pumpAndSettle();
  }
}
