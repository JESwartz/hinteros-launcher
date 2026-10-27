{{flutter_js}}
{{flutter_build_config}}

// Self-hosted: CanvasKit comes from the bundle (--no-web-resources-cdn), and
// fallback fonts from the bundle too, never from Google's font CDN. No
// service worker.
_flutter.loader.load({
  config: { fontFallbackBaseUrl: "assets/fonts/fallback/" },
});
