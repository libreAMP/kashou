import 'package:flutter/material.dart';

RectTween albumArtRectTween(Rect? begin, Rect? end) {
  return MaterialRectArcTween(begin: begin, end: end);
}

Widget albumArtFlightShuttleBuilder(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection flightDirection,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final Widget targetWidget =
      flightDirection == HeroFlightDirection.push ? toHeroContext.widget : fromHeroContext.widget;

  final curvedAnimation = animation.drive(CurveTween(curve: Curves.easeInOut));

  return FadeTransition(
    opacity: curvedAnimation,
    child: ScaleTransition(
      scale: Tween<double>(begin: 0.95, end: 1.0).animate(curvedAnimation),
      child: targetWidget,
    ),
  );
}
