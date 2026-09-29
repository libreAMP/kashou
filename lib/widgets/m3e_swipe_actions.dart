import 'package:flutter/material.dart';

import 'pressable.dart';

class M3ESwipeActions extends StatefulWidget {
  const M3ESwipeActions({
    super.key,
    required this.child,
    required this.actions,
  });

  final Widget child;
  final List<M3ESwipeAction> actions;

  @override
  State<M3ESwipeActions> createState() => _M3ESwipeActionsState();
}

class M3ESwipeAction {
  const M3ESwipeAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool filled;
}

class _M3ESwipeActionsState extends State<M3ESwipeActions> {
  static const _buttonSize = 52.0;
  static const _gap = 6.0;

  // 0 closed, 1 revealed
  late double _fraction = 0;

  double get _revealed => widget.actions.length * (_buttonSize + _gap);

  double get _offset => -_fraction * _revealed;

  void _onUpdate(DragUpdateDetails d) {
    setState(() {
      final width = _revealed == 0 ? 1.0 : _revealed;
      _fraction = (_fraction - d.primaryDelta! / width).clamp(0.0, 1.0);
    });
  }

  void _onEnd() {
    setState(() => _fraction = _fraction > 0.5 ? 1 : 0);
  }

  void _close() => setState(() => _fraction = 0);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: (_) => _onEnd(),
      onHorizontalDragCancel: _onEnd,
      child: Stack(
        children: [
          if (_revealed > 0)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (final action in widget.actions)
                      Padding(
                        padding: const EdgeInsets.only(left: _gap),
                        child: Transform.scale(
                          scale: 0.6 + 0.4 * _fraction,
                          child: Opacity(
                            opacity: _fraction,
                            child: PressableScale(
                              child: Tooltip(
                                message: action.label,
                                child: Material(
                                  color: action.filled
                                      ? scheme.primary
                                      : scheme.surfaceContainerHigh,
                                  borderRadius:
                                      BorderRadius.circular(_buttonSize / 2),
                                  child: InkWell(
                                    borderRadius:
                                        BorderRadius.circular(_buttonSize / 2),
                                    onTap: () {
                                      _close();
                                      action.onPressed();
                                    },
                                    child: SizedBox(
                                      width: _buttonSize,
                                      height: _buttonSize,
                                      child: Icon(
                                        action.icon,
                                        size: 22,
                                        color: action.filled
                                            ? scheme.onPrimary
                                            : scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(_offset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
