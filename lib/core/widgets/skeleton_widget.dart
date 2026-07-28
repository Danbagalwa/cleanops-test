import 'package:flutter/material.dart';
import '../constants/app_sizes.dart';

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = AppSizes.radiusSm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE9EBF1),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class SkeletonShimmer extends StatefulWidget {
  final Widget child;

  const SkeletonShimmer({super.key, required this.child});

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final position = _controller.value * 2.4 - 0.7;
            return LinearGradient(
              begin: Alignment(position - 1, 0),
              end: Alignment(position + 1, 0),
              colors: const [
                Color(0xFFE7E9EF),
                Color(0xFFF7F8FB),
                Color(0xFFE7E9EF),
              ],
              stops: const [0.25, 0.5, 0.75],
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

class AppSkeletonList extends StatelessWidget {
  final int itemCount;
  final EdgeInsetsGeometry padding;

  const AppSkeletonList({
    super.key,
    this.itemCount = 6,
    this.padding = const EdgeInsets.all(AppSizes.md),
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Chargement du contenu',
      liveRegion: true,
      child: ExcludeSemantics(
        child: SkeletonShimmer(
          child: ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            padding: padding,
            itemCount: itemCount,
            separatorBuilder: (_, __) => const SizedBox(height: AppSizes.sm),
            itemBuilder: (_, index) => const _SkeletonListCard(),
          ),
        ),
      ),
    );
  }
}

class _SkeletonListCard extends StatelessWidget {
  const _SkeletonListCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: const Color(0xFFEEF0F4)),
      ),
      child: const Row(
        children: [
          SkeletonBox(width: 46, height: 46, radius: AppSizes.radiusMd),
          SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 180, height: 15),
                SizedBox(height: AppSizes.sm),
                SkeletonBox(width: 110, height: 11),
              ],
            ),
          ),
          SizedBox(width: AppSizes.md),
          SkeletonBox(width: 72, height: 30, radius: AppSizes.radiusMd),
        ],
      ),
    );
  }
}

class AppSkeletonForm extends StatelessWidget {
  final int fieldCount;
  final EdgeInsetsGeometry padding;

  const AppSkeletonForm({
    super.key,
    this.fieldCount = 4,
    this.padding = const EdgeInsets.all(AppSizes.lg),
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Préparation du formulaire',
      liveRegion: true,
      child: ExcludeSemantics(
        child: SkeletonShimmer(
          child: Padding(
            padding: padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SkeletonBox(width: 190, height: 22),
                const SizedBox(height: AppSizes.lg),
                for (var i = 0; i < fieldCount; i++) ...[
                  const SkeletonBox(width: 105, height: 11),
                  const SizedBox(height: AppSizes.sm),
                  const SkeletonBox(height: 52, radius: AppSizes.radiusMd),
                  const SizedBox(height: AppSizes.md),
                ],
                const Align(
                  alignment: Alignment.centerRight,
                  child: SkeletonBox(
                    width: 128,
                    height: 42,
                    radius: AppSizes.radiusMd,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppSkeletonGrid extends StatelessWidget {
  const AppSkeletonGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Chargement du planning',
      liveRegion: true,
      child: ExcludeSemantics(
        child: SkeletonShimmer(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              children: [
                const Row(
                  children: [
                    SkeletonBox(width: 150, height: 38),
                    SizedBox(width: AppSizes.sm),
                    Expanded(child: SkeletonBox(height: 38)),
                  ],
                ),
                const SizedBox(height: AppSizes.sm),
                for (var row = 0; row < 5; row++) ...[
                  Expanded(
                    child: Row(
                      children: [
                        const SkeletonBox(width: 150, height: double.infinity),
                        const SizedBox(width: AppSizes.sm),
                        for (var column = 0; column < 5; column++) ...[
                          const Expanded(
                            child: SkeletonBox(height: double.infinity),
                          ),
                          if (column < 4)
                            const SizedBox(width: AppSizes.sm),
                        ],
                      ],
                    ),
                  ),
                  if (row < 4) const SizedBox(height: AppSizes.sm),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
