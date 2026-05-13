import 'package:flutter/material.dart';
import 'dart:math' as math;

class Responsive {
  static const double refWidth = 390.0; // Reference width (iPhone 13/14)
  static const double refHeight = 844.0; // Reference height

  static double screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double screenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  static double scaleW(BuildContext context, double size) {
    return (screenWidth(context) / refWidth) * size;
  }

  static double scaleH(BuildContext context, double size) {
    return (screenHeight(context) / refHeight) * size;
  }

  static double scaleText(BuildContext context, double size) {
    // Scale text based on width but with a cap to avoid massive text on tablets
    final scale = screenWidth(context) / refWidth;
    return size * math.min(scale, 1.2);
  }
}

extension ResponsiveExtension on num {
  double w(BuildContext context) => Responsive.scaleW(context, toDouble());
  double h(BuildContext context) => Responsive.scaleH(context, toDouble());
  double sp(BuildContext context) => Responsive.scaleText(context, toDouble());
}
