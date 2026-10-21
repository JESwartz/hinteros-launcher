import 'dart:async';

import 'package:flutter/material.dart';

import '../../system/repositories.dart';
import '../../theme/hinter_theme.dart';
import '../dialogs.dart';
import '../modal_host.dart';
import '../pages.dart';
import '../system/common.dart' show runAdminJob, describeError;
import '../widgets.dart';

/// "Add library" for Jellyfin: a folder in `/srv/media` ([FolderPicker]),
/// a name (the folder's, until one is typed), a kind; then the admin PIN and
/// the job. The page stays open when the service refuses (a name taken), so
/// it can be changed.
class AddLibraryPage extends StatefulWidget {
  const AddLibraryPage({
    super.key,
    required this.modal,
    required this.services,
  });

  final ModalHandle<void> modal;
  final SystemServices services;

  @override
  State<AddLibraryPage> createState() => _AddLibraryPageState();
}

class _AddLibraryPageState extends State<AddLibraryPage> {
  final _name = TextEditingController();
  MediaFolder? _folder;
  LibraryKind _kind = LibraryKind.movies;
  String? _error;

  /// The name came from the folder (a new folder replaces it).
  bool _nameFromFolder = true;

  @override
  void initState() {
    super.initState();
    _name.addListener(_typed);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _typed() {
    if (_name.text != _folder?.name) _nameFromFolder = false;
    if (mounted) setState(() {});
  }

  Future<void> _chooseFolder() async {
    final f = await ModalScope.of(context).show<MediaFolder>(
      (c, modal) => FolderPicker(modal: modal, server: widget.services.server),
    );
    if (f == null || !mounted) return;
    setState(() {
      _folder = f;
      _error = null;
      if (_nameFromFolder || _name.text.trim().isEmpty) {
        _name.text = f.name;
        _nameFromFolder = true;
      }
    });
  }

  Future<void> _add() async {
    final folder = _folder;
    final name = _name.text.trim();
    if (folder == null) {
      setState(() => _error = 'Choose a folder.');
      return;
    }
    if (name.isEmpty) {
      setState(() => _error = 'Type a name.');
      return;
    }
    setState(() => _error = null);
    final ok = await runAdminJob(
      context,
      widget.services,
      title: 'Add the library $name',
      start: (pin) => widget.services.server.addLibrary(
        name: name,
        kind: _kind,
        folder: folder.id,
        pin: pin,
      ),
    );
    if (ok && mounted) widget.modal.close();
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final p = Pane(widget.modal.region)
      ..item(
        'folder',
        onSelect: _chooseFolder,
        builder: (f) => SettingRow(
          title: 'Folder',
          subtitle: _folder == null ? 'Choose a folder' : _folder!.id,
          focused: f,
          trailing: Text('>', style: t.label),
        ),
      )
      ..add(Text('Name', style: t.title), gap: HinterTokens.s3)
      ..row(
        'name',
        1,
        NavTextField(
          region: widget.modal.region,
          rowKey: 'name',
          controller: _name,
          hint: 'Name',
        ),
      )
      ..add(Text('Kind', style: t.title), gap: HinterTokens.s3)
      ..buttons('kind', [
        for (final k in LibraryKind.choices)
          btn(k.label, () => setState(() => _kind = k), primary: k == _kind),
      ]);
    if (_error != null) p.add(StatusLine(_error!, error: true));
    p.buttons('actions', [
      btn('Cancel', widget.modal.close),
      btn('Add', _add, primary: true),
    ], gap: HinterTokens.s4);
    return FullPage(
      title: 'Add library',
      child: SingleChildScrollView(
        clipBehavior: Clip.none,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: p.build(),
        ),
      ),
    );
  }
}

/// A folder in `/srv/media`, one level at a time (`media.folders`). A on a
/// folder with folders in it opens it, on one without chooses it; inside a
/// folder, "Use this folder" chooses that one. Back goes one level up, and
/// at the top closes the picker.
class FolderPicker extends StatefulWidget {
  const FolderPicker({super.key, required this.modal, required this.server});

  final ModalHandle<MediaFolder> modal;
  final ServerRepository server;

  @override
  State<FolderPicker> createState() => _FolderPickerState();
}

class _FolderPickerState extends State<FolderPicker> {
  /// The folders opened, top first; empty: `/srv/media` itself.
  final _path = <MediaFolder>[];
  List<MediaFolder>? _folders;
  Object? _error;
  int _seq = 0;

  MediaFolder? get _here => _path.isEmpty ? null : _path.last;

  @override
  void initState() {
    super.initState();
    widget.modal.canBack = () {
      if (_path.isEmpty) return true;
      _path.removeLast();
      unawaited(_load());
      return false;
    };
    unawaited(_load());
  }

  Future<void> _load() async {
    final seq = ++_seq;
    setState(() {
      _folders = null;
      _error = null;
    });
    try {
      final f = await widget.server.folders(_here?.id);
      if (!mounted || seq != _seq) return;
      setState(() => _folders = f);
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() => _error = e);
    }
    // Focus on the first row of the new level, once it is built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final r = widget.modal.region;
      r.model.goTo(0, 0);
      r.changed();
      unawaited(r.focusCurrent());
    });
  }

  void _open(MediaFolder f) {
    if (f.hasChildren) {
      _path.add(f);
      unawaited(_load());
    } else {
      widget.modal.close(f);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final region = widget.modal.region;
    final here = _here;
    final folders = _folders;
    final p = Pane(region);
    if (here != null) {
      p.buttons('use', [
        btn('Use this folder', () => widget.modal.close(here), primary: true),
      ]);
    }
    if (_error != null) {
      p
        ..add(StatusLine(describeError(_error!), error: true))
        ..buttons('retry', [btn('Try again', () => unawaited(_load()))]);
    } else if (folders == null) {
      p.add(const StatusLine('Loading...'));
    } else if (folders.isEmpty) {
      p.add(
        Text(
          here == null ? 'No folders in /srv/media.' : 'No folders here.',
          style: t.bodyDim,
        ),
      );
    } else {
      for (final (i, f) in folders.indexed) {
        p.item(
          'f$i',
          onSelect: () => _open(f),
          builder: (focused) => SettingRow(
            title: f.name,
            focused: focused,
            trailing: f.hasChildren ? Text('>', style: t.label) : null,
          ),
        );
      }
    }
    // Always one item, so the page keeps the focus (and Back) while it loads.
    p.buttons('cancel', [
      btn('Cancel', () => widget.modal.close()),
    ], gap: HinterTokens.s4);
    return FullPage(
      title: 'Choose a folder',
      subtitle: here == null ? '/srv/media' : '/srv/media/${here.id}',
      child: SingleChildScrollView(
        clipBehavior: Clip.none,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: p.build(),
        ),
      ),
    );
  }
}
