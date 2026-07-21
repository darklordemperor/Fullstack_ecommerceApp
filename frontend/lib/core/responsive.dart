import 'package:flutter/widgets.dart';

/// Material 3 window size classes (compact / medium / expanded).
///
/// The important idea for split view / multi-window: **you never "detect split
/// view"**. When the OS puts the app in an Android split-screen pane, an iPad
/// Split View / Slide Over / Stage Manager slot, or a resized desktop window /
/// browser, Flutter reports the *window* size (the pane) through `MediaQuery`
/// and rebuilds on every resize. So any layout that branches on the window size
/// below adapts to split view automatically — the pane width *is* the width the
/// app sees.
enum WindowClass { compact, medium, expanded }

extension Responsive on BuildContext {
  /// The current window size — in split view this is the pane, not the device.
  Size get windowSize => MediaQuery.sizeOf(this);

  WindowClass get windowClass {
    final width = windowSize.width;
    if (width < 600) return WindowClass.compact; // phones, narrow panes
    if (width < 840) return WindowClass.medium; // large phones, small tablets
    return WindowClass.expanded; // tablets, desktop, wide windows
  }

  bool get isCompact => windowClass == WindowClass.compact;
  bool get isMedium => windowClass == WindowClass.medium;
  bool get isExpanded => windowClass == WindowClass.expanded;

  /// A comfortable centered content width per window class, so a very wide
  /// window (large monitor, ultra-wide) neither stretches long lines of text
  /// edge to edge nor fans a grid into too many tiny columns. Compact panes are
  /// effectively uncapped (any phone/narrow pane is already below 600).
  double get contentMaxWidth => switch (windowClass) {
        WindowClass.compact => 600,
        WindowClass.medium => 840,
        WindowClass.expanded => 1100,
      };
}

/// Top-aligns, centers, and width-caps [child] at [Responsive.contentMaxWidth],
/// so a scrollable page fills a narrow pane but doesn't stretch edge to edge on
/// a wide window / the wide half of a split view. Drop it around a screen body.
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
        child: child,
      ),
    );
  }
}
