/// The in-process [ControllerRepository] (`--mock`, tests): the wire mock's
/// [MockInputSettings] (the daemon's rules) behind the repository. A test
/// answers a capture with [MockController.press]; with [autoAnswer] (`--mock`)
/// each capture is answered by itself after a moment, with the buttons in
/// turn.
library;

import 'dart:async';

import '../api/api.dart' as api;
import 'controller.dart';
import 'daemon_controller.dart';
import 'models.dart';

class MockController implements ControllerRepository {
  MockController({this.autoAnswer = false}) {
    input = api.MockInputSettings(
      emit: (name, params) {
        if (name != 'input_captured') return;
        final c = _capture;
        _capture = null;
        if (c != null && !c.isCompleted) {
          c.complete(api.InputCapturedEvent.fromJson(params).button);
        }
      },
    );
  }

  /// The settings, the apps and the capture, as the daemon has them.
  late final api.MockInputSettings input;

  /// `--mock`: each capture answers itself after a second.
  final bool autoAnswer;
  int _auto = 0;

  /// The next call fails with this.
  SystemException? failNext;

  final _changes = StreamController<ControllerState>.broadcast();
  Completer<String?>? _capture;

  /// Whether a capture waits for a press.
  bool get capturing => input.capturing;

  /// What was stored last.
  StoredController get stored => controllerStateFrom(input.state()).stored;

  /// A press during a capture: a button id, a direction, or null (Guide, the
  /// timeout).
  void press(String? button) => input.press(button);

  void _fail() {
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw f;
    }
  }

  @override
  Stream<ControllerState> get changes => _changes.stream;

  @override
  Future<ControllerState> get() async {
    _fail();
    return controllerStateFrom(input.state());
  }

  @override
  Future<ControllerState> set(StoredController settings) async {
    _fail();
    try {
      await input.call(
        'input.settings.set',
        api.InputSettingsSetParams(settings: controllerSettingsOf(settings))
            .toJson(),
      );
    } on api.ApiException catch (e) {
      throw SystemException(SystemErrorKind.invalidParams, e.message);
    }
    final s = controllerStateFrom(input.state());
    _changes.add(s);
    return s;
  }

  @override
  Future<String?> capture() async {
    _fail();
    final old = _capture;
    if (old != null && !old.isCompleted) old.complete(null);
    final c = _capture = Completer<String?>();
    if (autoAnswer && input.script.isEmpty) {
      input
        ..scriptDelay = const Duration(seconds: 1)
        ..script.add(
          api.mockControllerButtons[_auto++ % api.mockControllerButtons.length],
        );
    }
    await input.call('input.capture', const {});
    return c.future;
  }
}
