import 'dart:async';

import 'package:flutter/material.dart';

import '../../log.dart';
import '../../nav/nav_controller.dart';
import '../../system/models.dart';
import '../../system/repositories.dart';
import '../dialogs.dart';
import '../pages.dart';
import '../profiles/profile_ui.dart' show withBoxAdminPin;
import '../widgets.dart';

/// A readable line for whatever went wrong.
String describeError(Object e) => switch (e) {
  SystemException(:final message) => message,
  _ => _unexpected(e),
};

String _unexpected(Object e) {
  logFailure('a settings section', e);
  return 'Something went wrong. Try again.';
}

/// The title of the message that explains a refused change.
String refusalTitle(SystemException e) => switch (e.kind) {
  SystemErrorKind.powerInhibited => 'Not right now',
  _ => "That didn't work",
};

/// What a section needs: the services and its pane's region.
class SectionEnv {
  const SectionEnv({required this.services, required this.region});

  final SystemServices services;
  final NavRegion region;
}

/// Loads [load] once and again on [reload]; shows "Loading", or the error with
/// a Try again button, or [builder]'s pane. The pane's rows go to the region.
class Loaded<T> extends StatefulWidget {
  const Loaded({
    super.key,
    required this.region,
    required this.load,
    required this.builder,
    this.updates = const [],
  });

  final NavRegion region;
  final Future<T> Function() load;

  /// Live changes (daemon events): each one turns the data shown into the
  /// new data. Ignored until the first load has finished.
  final List<Stream<T Function(T)>> updates;
  final Widget Function(
    BuildContext context,
    T data,
    Future<void> Function() reload,
  )
  builder;

  @override
  State<Loaded<T>> createState() => _LoadedState<T>();
}

class _LoadedState<T> extends State<Loaded<T>> {
  T? _data;
  bool _has = false;
  Object? _error;
  final _subs = <StreamSubscription<T Function(T)>>[];

  @override
  void initState() {
    super.initState();
    for (final s in widget.updates) {
      _subs.add(
        s.listen((f) {
          if (!mounted || !_has) return;
          setState(() => _data = f(_data as T));
        }),
      );
    }
    unawaited(_reload());
  }

  @override
  void dispose() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final d = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = d;
        _has = true;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _has = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      final p = Pane(widget.region)
        ..add(StatusLine(describeError(_error!), error: true))
        ..buttons('retry', [
          btn('Try again', () {
            setState(() => _error = null);
            unawaited(_reload());
          }),
        ]);
      return p.build();
    }
    if (!_has) {
      widget.region.setRows(const []);
      return const StatusLine('Loading...');
    }
    return widget.builder(context, _data as T, _reload);
  }
}

/// Starts a job (`start`), shows its progress page, and returns whether it
/// finished well. A refused start (busy, wrong password, ...) is shown as a
/// message and returns false.
Future<bool> runJob(
  BuildContext context,
  SystemServices services,
  Future<JobHandle> Function() start, {
  String? subtitle,
}) async {
  final JobHandle h;
  try {
    h = await start();
  } on SystemException catch (e) {
    if (context.mounted) {
      await showMessage(context, title: "That didn't work", body: e.message);
    }
    return false;
  }
  if (!context.mounted) return false;
  final r = await showJobProgress(context, services, h, subtitle: subtitle);
  return r?.ok ?? false;
}

/// [runJob] for a box-wide action that takes the admin profile's PIN
/// (rollback, channel, base, hardware; [withBoxAdminPin]). Back on the pad:
/// nothing runs, false.
Future<bool> runAdminJob(
  BuildContext context,
  SystemServices services, {
  required String title,
  required Future<JobHandle> Function(String? adminPin) start,
}) async {
  final JobHandle? h;
  try {
    h = await withBoxAdminPin(
      context,
      services.profiles,
      title: title,
      action: start,
    );
  } on SystemException catch (e) {
    if (context.mounted) {
      await showMessage(context, title: "That didn't work", body: e.message);
    }
    return false;
  }
  if (h == null || !context.mounted) return false;
  final r = await showJobProgress(context, services, h);
  return r?.ok ?? false;
}
