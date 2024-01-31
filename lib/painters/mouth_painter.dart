import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/painting.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

class EyePainter extends CustomPainter {
  final ui.Image image;
  final List<Face> faces;
  final List<Rect> rects = [];


  EyePainter(this.image, this.faces) {
    for (var i = 0; i < faces.length; i++) {
      rects.add(faces[i].boundingBox);
    }
  }

  @override
  void paint(ui.Canvas canvas, ui.Size size) {

    void drawEye(Canvas canvas, Point point) {
      Paint paintEye = Paint()
        ..color = Colors.red.withOpacity(0.5)
        ..style = PaintingStyle.fill;

      Offset offset = Offset(point.x.toDouble() - 30, point.y.toDouble() - 15);
      Rect rect =
      Rect.fromPoints(offset, Offset(offset.dx + 60, offset.dy + 30));
      canvas.drawOval(rect, paintEye);
    }

    canvas.drawImage(image, Offset.zero, Paint());
    for (var i = 0; i < faces.length; i++) {
      if (faces[i].landmarks[FaceLandmarkType.leftEye] != null &&
          faces[i].landmarks[FaceLandmarkType.rightEye] != null) {
        drawEye(canvas, faces[i].landmarks[FaceLandmarkType.leftEye]!.position);
        drawEye(
            canvas, faces[i].landmarks[FaceLandmarkType.rightEye]!.position);
      }
    }
  }

  @override
  bool shouldRepaint(EyePainter old) {
    return image != old.image || faces != old.faces;
  }
}
