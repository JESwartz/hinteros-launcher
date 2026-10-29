/// Local files the mock and the UI read (icons, cover art, the catalog
/// fixture, terms and README texts): from disk on the desktop, from the
/// bundled assets in the browser demo (`lib/web_main.dart`, on the
/// `web-demo` branch), where a path is an asset key.
library;

export 'local_files_io.dart'
    if (dart.library.js_interop) 'local_files_web.dart';
