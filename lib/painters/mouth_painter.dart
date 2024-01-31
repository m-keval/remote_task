import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

class MouthPainter extends CustomPainter {
  final ui.Image image;
  final List<Face> faces;
  final List<Rect> rects = [];

  MouthPainter(this.image, this.faces) {
    for (var i = 0; i < faces.length; i++) {
      rects.add(faces[i].boundingBox);
    }
  }

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    void drawMouth(Canvas canvas, Point point) {
      Paint paintMouth = Paint()
        ..color = Colors.green.withOpacity(0.5)
        ..style = PaintingStyle.fill;

      //mouth Offset
      Offset mouthOffset =
          Offset(point.x.toDouble() - 50, point.y.toDouble() - 35);
      Rect mouthRect = Rect.fromPoints(
          mouthOffset, Offset(mouthOffset.dx + 100, mouthOffset.dy + 40));
      canvas.drawOval(mouthRect, paintMouth);
    }

    for (var i = 0; i < faces.length; i++) {
      if (faces[i].landmarks[FaceLandmarkType.bottomMouth] != null) {
        drawMouth(
            canvas, faces[i].landmarks[FaceLandmarkType.bottomMouth]!.position);
      }
      //canvas.drawRect(rects[i], paint);
    }
  }

  @override
  bool shouldRepaint(MouthPainter oldDelegate) {
    return image != oldDelegate.image || faces != oldDelegate.faces;
  }
}
