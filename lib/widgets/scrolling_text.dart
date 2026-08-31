import 'package:flutter/material.dart';

class ScrollingText extends StatefulWidget {
  const ScrollingText({super.key, required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  State<ScrollingText> createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<ScrollingText> {
  final _controller = ScrollController();
  bool _looping = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStart());
  }

  @override
  void didUpdateWidget(ScrollingText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _looping = false;
      if (_controller.hasClients) _controller.jumpTo(0);
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStart());
    }
  }

  @override
  void dispose() {
    _looping = false;
    _controller.dispose();
    super.dispose();
  }

  void _maybeStart() {
    if (!mounted || _looping || !_controller.hasClients) return;
    if (_controller.position.maxScrollExtent <= 0) return;
    _looping = true;
    _loop();
  }

  Future<void> _loop() async {
    while (mounted && _looping && _controller.hasClients) {
      final extent = _controller.position.maxScrollExtent;
      if (extent <= 0) break;
      await _controller.animateTo(
        extent,
        duration: Duration(milliseconds: (extent * 40).toInt() + 1500),
        curve: Curves.linear,
      );
      await Future.delayed(const Duration(milliseconds: 1600));
      if (!mounted || !_controller.hasClients) break;
      _controller.jumpTo(0);
      await Future.delayed(const Duration(milliseconds: 900));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(widget.text, style: widget.style, maxLines: 1),
    );
  }
}
