import 'dart:ui';
import 'package:flutter/material.dart';

/// Responsive utilities for adaptive layouts across different device types
/// including foldable devices like Samsung Galaxy Z Fold series.
class Responsive {
  // Breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  /// Returns true if the screen is in mobile mode (width < 600)
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreakpoint;

  /// Returns true if the screen is in tablet mode (600 <= width < 1200)
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < desktopBreakpoint;
  }

  /// Returns true if the screen is in desktop mode (width >= 1200)
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktopBreakpoint;

  /// Detects if the device is a foldable in unfolded state with a visible hinge
  static bool isFoldableOpen(BuildContext context) {
    final features = MediaQuery.of(context).displayFeatures;
    return features.any((f) =>
        f.type == DisplayFeatureType.hinge ||
        f.type == DisplayFeatureType.fold);
  }

  /// Gets the bounds of the hinge/fold for layout avoidance
  /// Returns null if no hinge is detected
  static Rect? getHingeBounds(BuildContext context) {
    final features = MediaQuery.of(context).displayFeatures;
    for (final f in features) {
      if (f.type == DisplayFeatureType.hinge ||
          f.type == DisplayFeatureType.fold) {
        return f.bounds;
      }
    }
    return null;
  }

  /// Gets the hinge width (for adding spacing between panes)
  static double getHingeWidth(BuildContext context) {
    final bounds = getHingeBounds(context);
    return bounds?.width ?? 0;
  }

  /// Determines the current device form factor
  static DeviceFormFactor getFormFactor(BuildContext context) {
    if (isFoldableOpen(context)) {
      return DeviceFormFactor.foldableOpen;
    }
    if (isMobile(context)) {
      return DeviceFormFactor.mobile;
    }
    if (isTablet(context)) {
      return DeviceFormFactor.tablet;
    }
    return DeviceFormFactor.desktop;
  }

  /// Returns optimal sidebar width based on device form factor
  static double getSidebarWidth(BuildContext context) {
    final formFactor = getFormFactor(context);
    switch (formFactor) {
      case DeviceFormFactor.mobile:
        return MediaQuery.of(context).size.width * 0.8; // For drawer mode
      case DeviceFormFactor.tablet:
        return 280;
      case DeviceFormFactor.foldableOpen:
        final hingeBounds = getHingeBounds(context);
        if (hingeBounds != null) {
          // Use left pane (before hinge) for sidebar
          return hingeBounds.left - 8;
        }
        return 300;
      case DeviceFormFactor.desktop:
        return 300;
    }
  }

  /// Detects if device is in Flex Mode (half-opened posture)
  /// This is when the foldable is partially folded like a laptop
  static bool isFlexMode(BuildContext context) {
    final features = MediaQuery.of(context).displayFeatures;
    for (final f in features) {
      if (f.type == DisplayFeatureType.fold &&
          f.state == DisplayFeatureState.postureHalfOpened) {
        return true;
      }
    }
    return false;
  }

  /// Gets the Flex Mode split position (Y coordinate of the fold)
  /// Returns null if not in Flex Mode
  static double? getFlexModeSplitPosition(BuildContext context) {
    final features = MediaQuery.of(context).displayFeatures;
    for (final f in features) {
      if (f.type == DisplayFeatureType.fold) {
        return f.bounds.top;
      }
    }
    return null;
  }

  /// Detects if device is showing the Cover Screen (narrow tall screen)
  /// Galaxy Z Fold 7 Cover: 1080x2520 (aspect ratio ~2.33)
  static bool isCoverScreen(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Cover Screen: aspect ratio > 2.0 and relatively narrow
    final aspectRatio = size.height / size.width;
    return aspectRatio > 2.0 && size.width < 500;
  }

  /// Gets the fold height for Flex Mode layouts
  static double getFoldHeight(BuildContext context) {
    final features = MediaQuery.of(context).displayFeatures;
    for (final f in features) {
      if (f.type == DisplayFeatureType.fold) {
        return f.bounds.height;
      }
    }
    return 0;
  }
}

/// Device form factors for responsive design
enum DeviceFormFactor {
  mobile,
  tablet,
  foldableOpen,
  desktop,
}
