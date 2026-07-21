import 'package:flutter/widgets.dart';

/// Design tokens: the single source of spacing, radius, and sizing values.
///
/// Screens reference these instead of magic numbers so the whole app shares one
/// rhythm. Colors and typography come from the Material theme (`colorScheme` /
/// `textTheme`) — these tokens deliberately carry no color.

/// 4/8-based spacing scale.
abstract final class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Square gaps usable in both Column and Row (the cross-axis size is ignored
  /// by the parent), so `AppSpace.gapMd` replaces `SizedBox(height: 12)`.
  static const gapXs = SizedBox(height: xs, width: xs);
  static const gapSm = SizedBox(height: sm, width: sm);
  static const gapMd = SizedBox(height: md, width: md);
  static const gapLg = SizedBox(height: lg, width: lg);
  static const gapXl = SizedBox(height: xl, width: xl);
}

/// Corner-radius scale. Keeping these in one place stops the 14/16/18/20 drift
/// that had accumulated across the theme and screens.
abstract final class AppRadius {
  static const double sm = 14;
  static const double md = 16;
  static const double lg = 18;
  static const double xl = 20;
  static const double pill = 999;

  static const brSm = BorderRadius.all(Radius.circular(sm));
  static const brMd = BorderRadius.all(Radius.circular(md));
  static const brLg = BorderRadius.all(Radius.circular(lg));
  static const brXl = BorderRadius.all(Radius.circular(xl));
  static const brPill = BorderRadius.all(Radius.circular(pill));
}

/// Icon sizing tokens (avoid arbitrary 14/20/24/56 values scattered around).
abstract final class AppIconSize {
  static const double sm = 14;
  static const double md = 20;
  static const double lg = 24;
  static const double xxl = 56;
}
