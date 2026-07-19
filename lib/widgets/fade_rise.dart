import 'package:flutter/material.dart';

// index only staggers the delay, plays once per mount
class FadeRise extends StatefulWidget {
  final int index;
  final Widget child;

  const FadeRise({super.key, required this.index, required this.child});

  @override
  State<FadeRise> createState() => _FadeRiseState();
}

class _FadeRiseState extends State<FadeRise> {
  bool _in = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(Duration(milliseconds: 60 * widget.index.clamp(0, 5)), () {
        if (mounted) setState(() => _in = true);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return AnimatedSlide(
      offset: _in ? Offset.zero : const Offset(0, 0.03),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _in ? 1 : 0,
        duration: const Duration(milliseconds: 280),
        child: widget.child,
      ),
    );
  }
}
