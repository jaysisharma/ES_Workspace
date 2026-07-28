import 'package:flutter/material.dart';

class SlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SlidePageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Smooth, modern transition: slide from right with a subtle fade-in.
            const begin = Offset(0.15, 0.0);
            const end = Offset.zero;
            const curve = Curves.fastEaseInToSlowEaseOut;

            final slideTween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            final offsetAnimation = animation.drive(slideTween);
            
            final fadeTween = Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));
            final fadeAnimation = animation.drive(fadeTween);

            return FadeTransition(
              opacity: fadeAnimation,
              child: SlideTransition(
                position: offsetAnimation,
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 250),
        );
}

extension NavigationExtension on BuildContext {
  /// Navigates to a page using a smooth slide and fade transition.
  Future<T?> pushPage<T>(Widget page) {
    return Navigator.push<T>(
      this,
      SlidePageRoute(page: page),
    );
  }

  /// Replaces the current page with a new page using a smooth slide and fade transition.
  Future<T?> pushReplacementPage<T, TO>(Widget page) {
    return Navigator.pushReplacement<T, TO>(
      this,
      SlidePageRoute(page: page),
    );
  }
}
