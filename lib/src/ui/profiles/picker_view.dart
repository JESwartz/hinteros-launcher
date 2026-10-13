/// The profile picker's screen, shared by the greeter (`--greeter`, at boot
/// and between profiles) and the in-session picker (Switch profile): a row
/// of profile tiles (colour, initial, name, a lock on locked profiles, the
/// admin badge), then Guest and Add profile, and Power below.
library;

import 'package:flutter/material.dart';

import '../../nav/nav_controller.dart';
import '../../nav/nav_model.dart';
import '../../system/models.dart';
import '../../system/profiles.dart';
import '../../theme/hinter_theme.dart';
import '../nav_focusable.dart';
import '../pages.dart' show FullPage;
import '../widgets.dart';
import 'profile_ui.dart';

enum PickerTileKind { profile, guest, add }

/// One tile of the picker.
class PickerTile {
  const PickerTile.profile({
    required this.id,
    required this.name,
    required this.initial,
    required this.color,
    this.locked = false,
    this.admin = false,
    this.note,
    this.current = false,
  }) : kind = PickerTileKind.profile;

  const PickerTile.guest({this.current = false})
    : kind = PickerTileKind.guest,
      id = CurrentProfile.guestId,
      name = 'Guest',
      initial = 'G',
      color = null,
      locked = false,
      admin = false,
      note = 'Cleared at restart';

  const PickerTile.add()
    : kind = PickerTileKind.add,
      id = null,
      name = 'Add profile',
      initial = null,
      color = null,
      locked = false,
      admin = false,
      note = null,
      current = false;

  final PickerTileKind kind;

  /// The profile id, `guest`, or null for Add profile.
  final String? id;
  final String name;
  final String? initial;
  final ProfileColor? color;
  final bool locked;
  final bool admin;
  final String? note;

  /// The profile whose session this is (the in-session picker): it stays
  /// open, choosing it goes back to it.
  final bool current;
}

/// The tiles in order: the profiles, Guest, Add profile (while there is
/// room).
List<PickerTile> pickerTiles({
  required List<PickerTile> profiles,
  required bool guest,
  bool guestCurrent = false,
  int max = 8,
}) => [
  ...profiles,
  if (guest) PickerTile.guest(current: guestCurrent),
  if (profiles.length < max) const PickerTile.add(),
];

/// The picker's page. [region] gets the rows `tiles` and `power`; the
/// caller focuses the first tile it wants.
class ProfilePickerView extends StatelessWidget {
  const ProfilePickerView({
    super.key,
    required this.region,
    required this.tiles,
    required this.onSelect,
    this.title = 'Who is watching?',
    this.subtitle,
    this.power = const [],
    this.onPower,
    this.message,
  });

  final NavRegion region;
  final List<PickerTile> tiles;
  final void Function(PickerTile tile) onSelect;
  final String title;
  final String? subtitle;
  final List<PowerAction> power;
  final void Function(PowerAction a)? onPower;

  /// An error line under the tiles.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final t = HinterTheme.of(context);
    region.setRows([
      NavRow('tiles', tiles.length),
      if (power.isNotEmpty) NavRow('power', power.length),
    ]);
    return FullPage(
      title: title,
      subtitle: subtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: HinterTokens.s4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(vertical: HinterTokens.s3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0) const SizedBox(width: HinterTokens.s4),
                  NavFocusable(
                    region: region,
                    rowKey: 'tiles',
                    col: i,
                    onSelect: () => onSelect(tiles[i]),
                    builder: (_, f) => _tile(tiles[i], f),
                  ),
                ],
              ],
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: HinterTokens.s2),
            StatusLine(message!, error: true),
          ],
          const Spacer(),
          if (power.isNotEmpty)
            Row(
              children: [
                Text('Power', style: t.bodyDim),
                const SizedBox(width: HinterTokens.s3),
                DialogButtonsRow(
                  region: region,
                  rowKey: 'power',
                  buttons: [
                    for (final a in power) btn(a.label, () => onPower?.call(a)),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _tile(PickerTile e, bool focused) => switch (e.kind) {
    PickerTileKind.guest => ProfileTile(
      name: 'Guest',
      initial: 'G',
      guest: true,
      focused: focused,
      current: e.current,
      note: e.current ? null : e.note,
    ),
    PickerTileKind.add => ProfileTile(
      name: 'Add profile',
      add: true,
      focused: focused,
    ),
    PickerTileKind.profile => ProfileTile(
      name: e.name,
      initial: e.initial,
      color: e.color,
      locked: e.locked,
      admin: e.admin,
      focused: focused,
      current: e.current,
      note: e.note,
    ),
  };
}

/// Focus [index] of the tile row once the page is laid out.
void focusPickerTile(NavRegion region, int index, VoidCallback refocus) {
  region.model.goTo(0, index < 0 ? 0 : index);
  WidgetsBinding.instance.addPostFrameCallback((_) => refocus());
}
