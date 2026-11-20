import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_radius.dart';

/// Komponen Skeleton loading dengan animasi denyut halus mandiri (tanpa package shimmer)
/// sesuai PRD §7.9 & §9.1.
class Skeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final bool isCircle;

  const Skeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.isCircle = false,
  });

  factory Skeleton.circle({Key? key, required double size}) {
    return Skeleton(key: key, width: size, height: size, isCircle: true);
  }

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final colorAnimation = ColorTween(
      begin: palette.photo,
      end: palette.chip,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    return AnimatedBuilder(
      animation: colorAnimation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: colorAnimation.value,
            shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: widget.isCircle
                ? null
                : (widget.borderRadius ?? AppRadius.card),
          ),
        );
      },
    );
  }
}
