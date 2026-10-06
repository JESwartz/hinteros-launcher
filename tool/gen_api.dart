// Generates lib/src/api/generated.dart from schema/session-api.json.
//
//   dart tool/gen_api.dart            # regenerate
//   dart tool/gen_api.dart --check    # exit 1 if the committed file is stale
//
// Dependency-free on purpose (dart:core/convert/io only) so it runs without
// `pub get`, inside the Nix sandbox and from the update-schema app.
//
// It walks `$defs`, `methods`, `events` and `errors` of the API document
// (format: hinteros-daemon/schema/api-doc.schema.json) and emits:
//   * a class per object schema (`$defs`, method params/results, event params,
//     error data, nested inline objects), with fromJson/toJson/==
//   * an enum per string enum, each with an `unknown` fallback for values from
//     a newer daemon (api.md: clients map unknown enum values to a fallback)
//   * `SessionApiMethods`: a typed stub per method on top of an abstract `rpc`
//   * `SessionEvent`: a sealed class with one subclass per event + unknown
//   * error code constants and the API version
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  var schemaPath = 'schema/session-api.json';
  var outPath = 'lib/src/api/generated.dart';
  var check = false;
  for (final a in args) {
    if (a == '--check') {
      check = true;
    } else if (a.startsWith('--schema=')) {
      schemaPath = a.substring(9);
    } else if (a.startsWith('--out=')) {
      outPath = a.substring(6);
    } else {
      stderr.writeln(
        'usage: dart tool/gen_api.dart [--check] [--schema=F] [--out=F]',
      );
      exit(64);
    }
  }

  final doc =
      jsonDecode(File(schemaPath).readAsStringSync()) as Map<String, dynamic>;
  final source = Generator(doc, schemaPath).generate();

  // Format through `dart format` so the committed file passes the format hook.
  final tmp = Directory.systemTemp.createTempSync('gen_api');
  try {
    final tmpFile = File('${tmp.path}/generated.dart')
      ..writeAsStringSync(source);
    final r = Process.runSync(Platform.resolvedExecutable, [
      'format',
      tmpFile.path,
    ]);
    if (r.exitCode != 0) {
      stderr.writeln('dart format failed:\n${r.stdout}\n${r.stderr}');
      exit(1);
    }
    final formatted = tmpFile.readAsStringSync();
    final out = File(outPath);
    if (check) {
      final current = out.existsSync() ? out.readAsStringSync() : '';
      if (current != formatted) {
        stderr.writeln(
          '$outPath is out of date with $schemaPath.\n'
          'Regenerate with: dart tool/gen_api.dart  (or: nix run .#update-schema)',
        );
        exit(1);
      }
      stdout.writeln('$outPath is up to date.');
    } else {
      out.createSync(recursive: true);
      out.writeAsStringSync(formatted);
      stdout.writeln('wrote $outPath');
    }
  } finally {
    tmp.deleteSync(recursive: true);
  }
}

const _reserved = {
  'abstract',
  'as',
  'assert',
  'async',
  'await',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'default',
  'do',
  'else',
  'enum',
  'extends',
  'false',
  'final',
  'finally',
  'for',
  'if',
  'in',
  'is',
  'new',
  'null',
  'on',
  'rethrow',
  'return',
  'super',
  'switch',
  'this',
  'throw',
  'true',
  'try',
  'var',
  'void',
  'while',
  'with',
  'values',
  'hashCode',
  'runtimeType',
  'toString',
  'toJson',
};

/// Extra names taken on event classes (they implement SessionEvent).
const _eventReserved = {'name', 'params'};

enum Kind { prim, enumeration, object, list, map, dynamic }

class Shape {
  Shape(this.kind, this.type, {this.inner, this.nullable = false});
  final Kind kind;
  final String type; // Dart type, non-nullable
  final Shape? inner;
  final bool nullable;
  Shape asNullable() => Shape(kind, type, inner: inner, nullable: true);
}

class Generator {
  Generator(this.doc, this.schemaPath);

  final Map<String, dynamic> doc;
  final String schemaPath;
  late final Map<String, dynamic> defs =
      (doc['\$defs'] as Map<String, dynamic>?) ?? {};
  final _emitted = <String, String>{};
  final _order = <String>[];

  // ---- naming -------------------------------------------------------------

  static List<String> _words(String s) =>
      s.split(RegExp(r'[^A-Za-z0-9]+')).where((w) => w.isNotEmpty).toList();

  static String pascal(String s) =>
      _words(s).map((w) => w[0].toUpperCase() + w.substring(1)).join();

  static String camel(String s, {Set<String> extra = const {}}) {
    final p = pascal(s);
    var r = p.isEmpty ? 'value' : p[0].toLowerCase() + p.substring(1);
    if (RegExp(r'^[0-9]').hasMatch(r)) r = 'v$r';
    return _reserved.contains(r) || extra.contains(r) ? '${r}_' : r;
  }

  /// Doc comments are markdown: keep `<n>` from reading as HTML.
  static String _escapeDoc(String s) =>
      s.replaceAll("<", "&lt;").replaceAll(">", "&gt;");

  static String doc_(String? text, [String indent = '']) {
    if (text == null || text.trim().isEmpty) return '';
    final lines = text
        .trim()
        .split('\n')
        .map((l) => '$indent/// ${_escapeDoc(l.trim())}'.trimRight())
        .join('\n');
    return '$lines\n';
  }

  // ---- schema -> Shape ----------------------------------------------------

  Map<String, dynamic> _deref(Map<String, dynamic> s) {
    final ref = s[r'$ref'] as String?;
    if (ref == null) return s;
    return defs[ref.split('/').last] as Map<String, dynamic>;
  }

  /// Resolves [s] to a Dart shape, emitting any types it needs under [hint].
  Shape shapeOf(Map<String, dynamic> s, String hint) {
    final ref = s[r'$ref'] as String?;
    if (ref != null) {
      final name = ref.split('/').last;
      final target = defs[name] as Map<String, dynamic>;
      return _namedShape(target, name);
    }
    // Nullable via `type: [x, "null"]` or anyOf/oneOf with a null branch.
    final type = s['type'];
    if (type is List) {
      final rest = type.where((t) => t != 'null').toList();
      final nullable = rest.length != type.length;
      if (rest.length == 1) {
        final inner = shapeOf({...s, 'type': rest.first}, hint);
        return nullable ? inner.asNullable() : inner;
      }
      return Shape(Kind.dynamic, 'Object', nullable: true);
    }
    for (final key in ['anyOf', 'oneOf']) {
      final alts = s[key] as List?;
      if (alts == null) continue;
      final nonNull = alts
          .cast<Map<String, dynamic>>()
          .where((a) => a['type'] != 'null')
          .toList();
      final hasNull = nonNull.length != alts.length;
      if (nonNull.length == 1) {
        final inner = shapeOf(nonNull.first, hint);
        return hasNull ? inner.asNullable() : inner;
      }
      return Shape(Kind.dynamic, 'Object', nullable: hasNull);
    }
    return _namedShape(s, hint);
  }

  Shape _namedShape(Map<String, dynamic> s, String name) {
    if (s[r'$ref'] != null) return shapeOf(s, name);
    // A named alias for a union, e.g. FocusTarget = oneOf [AppId, null].
    if (s['type'] == null && (s['oneOf'] != null || s['anyOf'] != null)) {
      return shapeOf(s, name);
    }
    var type = s['type'];
    // An `enum` of strings without an explicit `type` is a string enum too.
    if (type == null &&
        s['enum'] is List &&
        (s['enum'] as List).every((v) => v is String)) {
      type = 'string';
    }
    if (s['enum'] is List && type == 'string') {
      _emitEnum(name, s);
      return Shape(Kind.enumeration, name);
    }
    switch (type) {
      case 'string':
        return Shape(Kind.prim, 'String');
      case 'integer':
        return Shape(Kind.prim, 'int');
      case 'number':
        return Shape(Kind.prim, 'num');
      case 'boolean':
        return Shape(Kind.prim, 'bool');
      case 'array':
        final items = (s['items'] as Map<String, dynamic>?) ?? {};
        final inner = shapeOf(items, '${name}Item');
        final it = inner.nullable ? '${inner.type}?' : inner.type;
        return Shape(Kind.list, 'List<$it>', inner: inner);
      case 'object':
        if (s['properties'] is Map) {
          _emitClass(name, s);
          return Shape(Kind.object, name);
        }
        return Shape(Kind.map, 'Map<String, Object?>');
    }
    return Shape(Kind.dynamic, 'Object', nullable: true);
  }

  String _t(Shape s) => s.nullable ? '${s.type}?' : s.type;

  String decode(Shape s, String e) {
    switch (s.kind) {
      case Kind.prim:
        return '$e as ${s.type}';
      case Kind.enumeration:
        return '${s.type}.fromJson($e as String)';
      case Kind.object:
        return '${s.type}.fromJson(($e as Map).cast<String, dynamic>())';
      case Kind.list:
        final inner = s.inner!;
        final item = inner.nullable
            ? '(x) => x == null ? null : ${decode(inner, 'x')}'
            : '(x) => ${decode(inner, 'x')}';
        return '($e as List).map($item).toList()';
      case Kind.map:
        return '($e as Map).cast<String, Object?>()';
      case Kind.dynamic:
        return e;
    }
  }

  String encode(Shape s, String e) {
    switch (s.kind) {
      case Kind.prim:
      case Kind.dynamic:
      case Kind.map:
        return e;
      case Kind.enumeration:
      case Kind.object:
        return '$e.toJson()';
      case Kind.list:
        final inner = s.inner!;
        if (inner.kind == Kind.prim ||
            inner.kind == Kind.dynamic ||
            inner.kind == Kind.map) {
          return e;
        }
        return '$e.map((x) => ${inner.nullable ? 'x == null ? null : ' : ''}${encode(inner, 'x')}).toList()';
    }
  }

  // ---- emitters -----------------------------------------------------------

  void _register(String name, String Function() build) {
    if (_emitted.containsKey(name)) return;
    _emitted[name] = ''; // reserve to stop recursion
    final code = build();
    _emitted[name] = code;
    _order.add(name);
  }

  void _emitEnum(String name, Map<String, dynamic> s) {
    _register(name, () {
      final values = (s['enum'] as List).cast<String>();
      final used = <String>{};
      final variants = <String>[];
      for (final v in values) {
        var id = camel(v);
        while (!used.add(id)) {
          id = '${id}_';
        }
        variants.add("$id('${v.replaceAll("'", r"\'")}')");
      }
      var unknown = 'unknown';
      while (used.contains(unknown)) {
        unknown = '${unknown}_';
      }
      final b = StringBuffer()
        ..write(doc_(s['description'] as String?))
        ..writeln('enum $name {')
        ..writeln('  ${variants.join(',\n  ')},')
        ..writeln("  /// A value this client does not know (newer daemon).")
        ..writeln("  $unknown('unknown');")
        ..writeln()
        ..writeln('  const $name(this.value);')
        ..writeln('  final String value;')
        ..writeln()
        ..writeln(
          '  factory $name.fromJson(String value) => values.firstWhere(',
        )
        ..writeln('    (e) => e != $unknown && e.value == value,')
        ..writeln('    orElse: () => $unknown,')
        ..writeln('  );')
        ..writeln()
        ..writeln('  String toJson() => value;')
        ..writeln('}');
      return b.toString();
    });
  }

  /// Emits a class for an object schema. [extendsEvent] makes it an event.
  void _emitClass(String name, Map<String, dynamic> s0, {String? eventName}) {
    // A params/result schema may be a `$ref` (with a redundant `type`).
    final s = s0[r'$ref'] == null ? s0 : {...s0, ..._deref(s0)};
    _register(name, () {
      final props = (s['properties'] as Map<String, dynamic>?) ?? {};
      final required = ((s['required'] as List?) ?? []).cast<String>().toSet();
      final fields = <_Field>[];
      for (final e in props.entries) {
        final fname = camel(
          e.key,
          extra: eventName != null ? _eventReserved : const {},
        );
        var shape = shapeOf(
          e.value as Map<String, dynamic>,
          '$name${pascal(e.key)}',
        );
        final req = required.contains(e.key);
        if (!req) shape = shape.asNullable();
        fields.add(
          _Field(
            e.key,
            fname,
            shape,
            req,
            (e.value as Map<String, dynamic>)['description'] as String? ??
                _deref(e.value as Map<String, dynamic>)['description']
                    as String?,
          ),
        );
      }
      final b = StringBuffer();
      b.write(doc_(s['description'] as String? ?? s['summary'] as String?));
      final head = eventName != null
          ? 'final class $name extends SessionEvent'
          : 'class $name';
      b.writeln('$head {');
      // constructor
      if (fields.isEmpty) {
        b.writeln('  const $name();');
      } else {
        b.writeln('  const $name({');
        for (final f in fields) {
          final isRequired = f.required;
          b.writeln('    ${isRequired ? 'required ' : ''}this.${f.dart},');
        }
        b.writeln('  });');
      }
      b.writeln();
      for (final f in fields) {
        b.write(doc_(f.doc, '  '));
        b.writeln('  final ${_t(f.shape)} ${f.dart};');
      }
      if (fields.isNotEmpty) b.writeln();
      // fromJson
      b.writeln(
        '  factory $name.fromJson(Map<String, dynamic> json) => $name(',
      );
      for (final f in fields) {
        final raw = "json['${f.json}']";
        final d = decode(f.shape, raw);
        final expr = f.shape.nullable ? "$raw == null ? null : $d" : d;
        b.writeln('    ${f.dart}: $expr,');
      }
      b.writeln('  );');
      b.writeln();
      // toJson
      b.writeln('  Map<String, dynamic> toJson() => {');
      for (final f in fields) {
        if (f.shape.nullable && f.required) {
          // Required but nullable: null goes on the wire explicitly.
          final plain = encode(f.shape, f.dart) == f.dart;
          b.writeln(
            plain
                ? "    '${f.json}': ${f.dart},"
                : "    '${f.json}': ${f.dart} == null ? null : ${encode(f.shape, '${f.dart}!')},",
          );
        } else if (f.shape.nullable) {
          final plain = encode(f.shape, f.dart) == f.dart;
          b.writeln(
            plain
                ? "    '${f.json}': ?${f.dart},"
                : "    if (${f.dart} != null) '${f.json}': ${encode(f.shape, '${f.dart}!')},",
          );
        } else {
          b.writeln("    '${f.json}': ${encode(f.shape, f.dart)},");
        }
      }
      b.writeln('  };');
      b.writeln();
      if (eventName != null) {
        b.writeln('  @override');
        b.writeln("  String get name => '$eventName';");
        b.writeln();
        b.writeln('  @override');
        b.writeln('  Map<String, dynamic> get params => toJson();');
        b.writeln();
      }
      b.writeln('  @override');
      b.writeln('  bool operator ==(Object other) =>');
      b.writeln(
        '      other is $name && jsonEncode(toJson()) == jsonEncode(other.toJson());',
      );
      b.writeln();
      b.writeln('  @override');
      b.writeln('  int get hashCode => jsonEncode(toJson()).hashCode;');
      b.writeln();
      b.writeln('  @override');
      b.writeln("  String toString() => '$name(\${jsonEncode(toJson())})';");
      b.writeln('}');
      return b.toString();
    });
  }

  // ---- document -----------------------------------------------------------

  String generate() {
    final api = doc['api'] as String;
    final version = doc['version'] as String;
    final apiPascal = pascal(api);
    final methods = (doc['methods'] as Map<String, dynamic>?) ?? {};
    final events = (doc['events'] as Map<String, dynamic>?) ?? {};
    final errors = (doc['errors'] as Map<String, dynamic>?) ?? {};

    // $defs: classes, enums; plain aliases (ApiVersion = String) as typedefs.
    final typedefs = StringBuffer();
    for (final e in defs.entries) {
      final shape = _namedShape(e.value as Map<String, dynamic>, e.key);
      if (shape.kind == Kind.prim ||
          shape.kind == Kind.list ||
          shape.kind == Kind.map) {
        typedefs.write(doc_((e.value as Map)['description'] as String?));
        typedefs.writeln('typedef ${e.key} = ${shape.type};');
      }
    }

    // Methods: params/result classes first (also registers nested types).
    final stubs = StringBuffer();
    final methodNames = <String>[];
    for (final e in methods.entries) {
      final m = e.value as Map<String, dynamic>;
      final base = pascal(e.key);
      final pName = '${base}Params';
      final rName = '${base}Result';
      _emitClass(
        pName,
        (m['params'] as Map<String, dynamic>?) ?? {'properties': {}},
      );
      _emitClass(
        rName,
        (m['result'] as Map<String, dynamic>?) ?? {'properties': {}},
      );
      methodNames.add(e.key);
      // A `$ref` params schema (display.set_mode) keeps `required` on its target.
      final params = _deref((m['params'] as Map<String, dynamic>?) ?? {});
      final anyRequired = ((params['required'] as List?) ?? []).isNotEmpty;
      final arg = anyRequired
          ? '$pName params'
          : '[$pName params = const $pName()]';
      stubs.write(doc_(m['summary'] as String?, '  '));
      if (m['description'] != null) {
        stubs.writeln('  ///');
        stubs.write(doc_(m['description'] as String?, '  '));
      }
      stubs.writeln('  Future<$rName> ${camel(e.key)}($arg) async =>');
      stubs.writeln(
        "      $rName.fromJson(await rpc('${e.key}', params.toJson()));",
      );
      stubs.writeln();
    }

    // Events.
    final eventClasses = <String>[];
    final eventCases = StringBuffer();
    for (final e in events.entries) {
      final ev = e.value as Map<String, dynamic>;
      final cls = '${pascal(e.key)}Event';
      _emitClass(cls, {
        ...((ev['params'] as Map<String, dynamic>?) ?? {'properties': {}}),
        'description': ev['summary'],
      }, eventName: e.key);
      eventClasses.add(cls);
      eventCases.writeln("      '${e.key}' => $cls.fromJson(params),");
    }

    // Errors.
    final codes = StringBuffer();
    for (final e in errors.entries) {
      final er = e.value as Map<String, dynamic>;
      codes.write(doc_(er['summary'] as String?, '  '));
      codes.writeln('  static const ${camel(e.key)} = ${er['code']};');
      if (er['data'] is Map) {
        _emitClass('${pascal(e.key)}Data', er['data'] as Map<String, dynamic>);
      }
    }
    final codeMap = errors.entries
        .map((e) => "  '${e.key}': ${(e.value as Map)['code']},")
        .join('\n');

    final b = StringBuffer()
      ..writeln('// GENERATED CODE - DO NOT EDIT.')
      ..writeln('// Source: $schemaPath ($api API $version).')
      ..writeln(
        '// Regenerate: dart tool/gen_api.dart  (or: nix run .#update-schema)',
      )
      ..writeln('//')
      ..writeln(
        '// ignore_for_file: unnecessary_this, unnecessary_cast, '
        'prefer_null_aware_operators, prefer_if_null_operators',
      )
      ..writeln()
      ..writeln("import 'dart:convert';")
      ..writeln()
      ..writeln(
        '/// API version this client was generated for (sent in `hello`).',
      )
      ..writeln("const apiVersion = '$version';")
      ..writeln()
      ..writeln('/// Method names in the schema.')
      ..writeln(
        'const apiMethodNames = <String>[${methodNames.map((n) => "'$n'").join(', ')}];',
      )
      ..writeln()
      ..writeln('/// Event names in the schema.')
      ..writeln(
        'const apiEventNames = <String>[${events.keys.map((n) => "'$n'").join(', ')}];',
      )
      ..writeln()
      ..writeln('/// Error name to JSON-RPC code.')
      ..writeln('const apiErrorCodesByName = <String, int>{\n$codeMap\n};')
      ..writeln()
      ..writeln('/// JSON-RPC error codes of the $api API.')
      ..writeln('abstract final class ApiErrorCode {')
      ..write(codes)
      ..writeln('}')
      ..writeln()
      ..write(typedefs)
      ..writeln();
    for (final n in _order) {
      b
        ..writeln(_emitted[n])
        ..writeln();
    }
    b
      ..writeln('/// Typed calls for every method of the $api API.')
      ..writeln('///')
      ..writeln(
        '/// Implementors provide [rpc], which sends one request and returns its',
      )
      ..writeln('/// result object (or throws).')
      ..writeln('mixin ${apiPascal}ApiMethods {')
      ..writeln(
        '  Future<Map<String, dynamic>> rpc(String method, Map<String, dynamic> params);',
      )
      ..writeln()
      ..write(stubs)
      ..writeln('}')
      ..writeln()
      ..writeln('/// A server-pushed notification of the $api API.')
      ..writeln('sealed class SessionEvent {')
      ..writeln('  const SessionEvent();')
      ..writeln()
      ..writeln('  /// Wire name, e.g. `home_pressed`.')
      ..writeln('  String get name;')
      ..writeln()
      ..writeln('  Map<String, dynamic> get params;')
      ..writeln()
      ..writeln(
        '  /// Builds the typed event; names this client does not know become',
      )
      ..writeln('  /// [UnknownSessionEvent].')
      ..writeln(
        '  static SessionEvent fromNotification(String name, Map<String, dynamic> params) =>',
      )
      ..writeln('      switch (name) {')
      ..write(eventCases)
      ..writeln('        _ => UnknownSessionEvent(name, params),')
      ..writeln('      };')
      ..writeln('}')
      ..writeln()
      ..writeln('/// An event from a newer daemon than this client knows.')
      ..writeln('final class UnknownSessionEvent extends SessionEvent {')
      ..writeln('  const UnknownSessionEvent(this.name, this.params);')
      ..writeln()
      ..writeln('  @override')
      ..writeln('  final String name;')
      ..writeln()
      ..writeln('  @override')
      ..writeln('  final Map<String, dynamic> params;')
      ..writeln('}');
    return b.toString();
  }
}

class _Field {
  _Field(this.json, this.dart, this.shape, this.required, this.doc);
  final String json;
  final String dart;
  final Shape shape;
  final bool required;
  final String? doc;
}
