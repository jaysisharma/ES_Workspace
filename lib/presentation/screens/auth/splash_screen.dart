import 'package:flutter/material.dart';
import 'package:order_app/core/utils/route_transitions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:order_app/presentation/widgets/common/role_based_router.dart';
import 'package:order_app/presentation/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );
    _progressController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    // Check if session check is already done or wait for it
    try {
      while (ref.read(authNotifierProvider).isLoading) {
        await Future.delayed(const Duration(milliseconds: 50));
        if (!mounted) return;
      }
    } catch (e) {
      debugPrint('Auth initialization delay: $e');
    }

    // Wait for progress animation to complete
    await Future.delayed(const Duration(milliseconds: 1300));

    if (!mounted) return;

    // Immediate transition
    Navigator.of(
      context,
    ).pushReplacement(SlidePageRoute(page: const RoleBasedRouter()));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelColor = colorScheme.onSurfaceVariant;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo - Static
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/event_solution_logo.jpeg',
                width: 110,
                height: 110,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Icons.event, size: 80, color: colorScheme.primary),
              ),
            ),
            const SizedBox(height: 28),

            // Title - Static
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                  fontFamily: 'Manrope',
                  letterSpacing: -0.5,
                ),
                children: [const TextSpan(text: 'ES Workspace ')],
              ),
            ),
            const SizedBox(height: 8),

            // Tagline
            Text(
              'Event Order & Revenue Management',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: labelColor,
                fontFamily: 'Manrope',
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 60),

            // Progress Bar
            AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) {
                return Container(
                  width: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _progressAnimation.value,
                      minHeight: 4,
                      backgroundColor: colorScheme.primary.withValues(
                        alpha: 0.05,
                      ),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.primary.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
