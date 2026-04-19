import 'package:flutter/material.dart';

enum AdminThemeMode {
  classic,
  worldcup,
}

class AdminThemeController extends ChangeNotifier {
  AdminThemeController({
    required AdminThemeMode initialMode,
  }) : _mode = initialMode;

  AdminThemeMode _mode;

  AdminThemeMode get mode => _mode;
  bool get isWorldcup => _mode == AdminThemeMode.worldcup;

  static AdminThemeController fromUri(Uri uri) {
    final raw =
        (uri.queryParameters['tema'] ?? uri.queryParameters['theme'] ?? '')
            .trim()
            .toLowerCase();
    final isWorldcup = raw == 'mundialista' || raw == 'worldcup';
    return AdminThemeController(
      initialMode:
          isWorldcup ? AdminThemeMode.worldcup : AdminThemeMode.classic,
    );
  }

  void toggle() {
    _mode = isWorldcup ? AdminThemeMode.classic : AdminThemeMode.worldcup;
    notifyListeners();
  }

  void setMode(AdminThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }
}

class AdminThemeScope extends InheritedNotifier<AdminThemeController> {
  const AdminThemeScope({
    super.key,
    required AdminThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static AdminThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AdminThemeScope>();
    assert(scope != null, 'AdminThemeScope no encontrado en el árbol.');
    return scope!.notifier!;
  }

  static AdminThemeController? maybeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AdminThemeScope>();
    return scope?.notifier;
  }
}
