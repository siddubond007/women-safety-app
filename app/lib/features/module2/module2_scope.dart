import 'package:flutter/widgets.dart';

import 'module2_state.dart';

class Module2Scope extends InheritedWidget {
  const Module2Scope({
    super.key,
    required this.state,
    required this.route,
    required this.onNavigate,
    required this.onOpenCreatePost,
    required super.child,
  });

  final Module2State state;
  final String route;
  final ValueChanged<String> onNavigate;
  final VoidCallback onOpenCreatePost;

  static Module2Scope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<Module2Scope>();
    assert(scope != null, 'Module2Scope is missing above this widget.');
    return scope!;
  }

  @override
  bool updateShouldNotify(Module2Scope oldWidget) =>
      state != oldWidget.state ||
      route != oldWidget.route ||
      onNavigate != oldWidget.onNavigate ||
      onOpenCreatePost != oldWidget.onOpenCreatePost;
}
