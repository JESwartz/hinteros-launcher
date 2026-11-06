/// "Loading Sam…": the full-screen page between choosing a profile and its
/// Home. The picker shows it once greetd accepted the login (until it
/// exits), the console shows the same words on the VT while the session's
/// compositor starts (`hinteros-system pin splash`, same colours), and the
/// launcher's first frames show it again until Home has its data, so the
/// handover reads as one screen. The titles end in "…" (U+2026), as the
/// splash draws them (`splash.rs`), not "...", which the rest of the UI uses.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../system/profiles.dart';
import '../../theme/hinter_theme.dart';
import 'profile_ui.dart';

/// Who is being loaded: what the loading page shows.
class LoadingIdentity {
  const LoadingIdentity({this.name, this.color, this.guest = false});

  static const guestIdentity = LoadingIdentity(name: 'Guest', guest: true);

  /// Null: not known (the page says "Loading…").
  final String? name;
  final ProfileColor? color;
  final bool guest;

  String get initial => name == null || name!.isEmpty
      ? 'H'
      : String.fromCharCode(name!.runes.first).toUpperCase();

  /// The guest's user.
  static const guestUser = 'hinteros-guest';

  /// From the service's public view (`/run/hinteros/profiles-public.json`,
  /// world-readable) and the session's user: the profile's name and colour
  /// before the daemon answers. Anything unreadable gives an unknown name.
  static LoadingIdentity fromPublicView(String? user, {String? path}) {
    if (user == null || user.isEmpty) return const LoadingIdentity();
    if (user == guestUser) return guestIdentity;
    try {
      final text = File(path ?? '/run/hinteros/profiles-public.json')
          .readAsStringSync();
      return fromPublicJson(text, user);
    } catch (_) {
      return const LoadingIdentity();
    }
  }

  /// [fromPublicView] on the file's text.
  static LoadingIdentity fromPublicJson(String text, String user) {
    if (user == guestUser) return guestIdentity;
    try {
      final v = jsonDecode(text);
      if (v is! Map) return const LoadingIdentity();
      final list = v['profiles'];
      if (list is! List) return const LoadingIdentity();
      for (final p in list) {
        if (p is Map && p['user'] == user) {
          final name = p['name'];
          final color = p['color'];
          return LoadingIdentity(
            name: name is String && name.trim().isNotEmpty ? name : null,
            color: color is String ? ProfileColor.parse(color) : null,
          );
        }
      }
    } catch (_) {
      // Unknown.
    }
    return const LoadingIdentity();
  }
}

/// The page: the profile's avatar, "Loading Sam…", a spinner (a still ring
/// with reduce motion). Also the page of a session that is ending
/// ("Removing Sam…", with [detail] under it).
class ProfileLoadingPage extends StatelessWidget {
  const ProfileLoadingPage({
    super.key,
    required this.identity,
    this.title,
    this.detail,
  });

  final LoadingIdentity identity;

  /// Instead of "Loading Sam…".
  final String? title;

  /// A line under the title.
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    final name = identity.name;
    final title = this.title ?? (name == null ? 'Loading…' : 'Loading $name…');
    return Semantics(
      container: true,
      liveRegion: true,
      label: detail == null ? title : '$title $detail',
      child: ColoredBox(
        key: const ValueKey('profile-loading'),
        color: t.background,
        child: SizedBox.expand(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ProfileAvatar(
                  initial: identity.initial,
                  color: identity.guest ? null : identity.color,
                  guest: identity.guest,
                  size: 200,
                ),
                const SizedBox(height: HinterTokens.s4),
                Text(
                  title,
                  key: const ValueKey('profile-loading-title'),
                  style: t.headline,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (detail != null) ...[
                  const SizedBox(height: HinterTokens.s1),
                  Text(
                    detail!,
                    key: const ValueKey('profile-loading-detail'),
                    style: t.bodyDim,
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: HinterTokens.s4),
                SizedBox.square(
                  dimension: 56,
                  child: CircularProgressIndicator(
                    key: const ValueKey('profile-loading-spinner'),
                    value: t.reduceMotion ? 0.75 : null,
                    strokeWidth: 6,
                    color: t.accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
