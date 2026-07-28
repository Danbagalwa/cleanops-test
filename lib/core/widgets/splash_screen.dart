import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:jazz_teasdale/features/auth/domain/entities/employee.dart';
import '../constants/app_colors.dart';
import '../router/app_router.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final datasource = ref.read(authDatasourceProvider);
    final Employee? employee = await datasource.getEmployeEnSession();

    if (!mounted) return;

    if (employee != null) {
      ref.read(authNotifierProvider.notifier).setEmployee(employee);

      switch (employee.role) {
        case RoleType.employe:
          context.go(AppRoutes.employeeDashboard);
          break;
        case RoleType.superviseurMenage:
        case RoleType.admin:
        case RoleType.direction:
        case RoleType.reception:
          context.go(AppRoutes.employerDashboard);
          break;
        case RoleType.resident:
          context.go(AppRoutes.residentDashboard);
          break;
      }
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.rouge, AppColors.rougeFonce],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned(
              top: -50,
              left: -50,
              child: _CircularBackground(size: 200, opacity: 0.05),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(35),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(35),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                )
                    .animate()
                    .scale(duration: 600.ms, curve: Curves.bounceOut)
                    .fadeIn(duration: 600.ms),
                const SizedBox(height: 32),
                Text(
                  'CleanOps'.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4.0,
                  ),
                )
                    .animate(delay: 300.ms)
                    .fadeIn(duration: 500.ms)
                    .moveY(begin: 20, end: 0, curve: Curves.easeOutQuad),
                const SizedBox(height: 12),
                Text(
                  'Efficiency in Every Task',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 0.5,
                  ),
                ).animate(delay: 600.ms).fadeIn(duration: 500.ms),
                const SizedBox(height: 80),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ).animate(delay: 800.ms).fadeIn(duration: 400.ms),
              ],
            ),
            Positioned(
              bottom: 40,
              child: Text(
                "v1.0.0",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ).animate(delay: 1000.ms).fadeIn(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircularBackground extends StatelessWidget {
  final double size;
  final double opacity;
  const _CircularBackground({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}
