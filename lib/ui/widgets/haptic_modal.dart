import 'package:flutter/material.dart' hide showDialog, showModalBottomSheet;
import 'package:flutter/material.dart' as material show showDialog, showModalBottomSheet;
import 'package:flutter/services.dart';

/// A utility class that provides haptic feedback when modals are opened.
/// 
/// This class wraps Flutter's `showDialog` and `showModalBottomSheet` functions
/// to automatically trigger haptic feedback when modals are displayed.
/// 
/// Usage:
/// ```dart
/// // Instead of showDialog
/// await HapticModal.showDialog(
///   context: context,
///   builder: (context) => MyDialog(),
/// );
/// 
/// // Instead of showModalBottomSheet
/// await HapticModal.showModalBottomSheet(
///   context: context,
///   builder: (context) => MyBottomSheet(),
/// );
/// ```
class HapticModal {
  /// Shows a dialog with haptic feedback.
  /// 
  /// This is a drop-in replacement for `showDialog` that automatically
  /// triggers haptic feedback when the dialog is displayed.
  static Future<T?> showDialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    Color? barrierColor,
    String? barrierLabel,
    bool useSafeArea = true,
    bool useRootNavigator = false,
    RouteSettings? routeSettings,
    Offset? anchorPoint,
    TraversalEdgeBehavior? traversalEdgeBehavior,
    bool fullscreenDialog = false,
  }) {
    // Trigger haptic feedback when modal opens
    HapticFeedback.mediumImpact();
    
    return material.showDialog<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      barrierLabel: barrierLabel,
      useSafeArea: useSafeArea,
      useRootNavigator: useRootNavigator,
      routeSettings: routeSettings,
      anchorPoint: anchorPoint,
      traversalEdgeBehavior: traversalEdgeBehavior,
      fullscreenDialog: fullscreenDialog,
    );
  }

  /// Shows a modal bottom sheet with haptic feedback.
  /// 
  /// This is a drop-in replacement for `showModalBottomSheet` that automatically
  /// triggers haptic feedback when the bottom sheet is displayed.
  static Future<T?> showModalBottomSheet<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    Color? backgroundColor,
    double? elevation,
    ShapeBorder? shape,
    Clip? clipBehavior,
    BoxConstraints? constraints,
    Color? barrierColor,
    bool isScrollControlled = false,
    bool useRootNavigator = false,
    bool isDismissible = true,
    bool enableDrag = true,
    bool useSafeArea = false,
    bool showDragHandle = false,
    AnimationController? transitionAnimationController,
    Offset? anchorPoint,
    String? barrierLabel,
    RouteSettings? routeSettings,
  }) {
    // Trigger haptic feedback when modal opens
    HapticFeedback.mediumImpact();
    
    return material.showModalBottomSheet<T>(
      context: context,
      builder: builder,
      backgroundColor: backgroundColor,
      elevation: elevation,
      shape: shape,
      clipBehavior: clipBehavior,
      constraints: constraints,
      barrierColor: barrierColor,
      isScrollControlled: isScrollControlled,
      useRootNavigator: useRootNavigator,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      useSafeArea: useSafeArea,
      showDragHandle: showDragHandle,
      transitionAnimationController: transitionAnimationController,
      anchorPoint: anchorPoint,
      barrierLabel: barrierLabel,
      routeSettings: routeSettings,
    );
  }
}

