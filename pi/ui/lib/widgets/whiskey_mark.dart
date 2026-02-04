import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Primitive attitude indicator (whiskey mark) displaying roll/pitch.
///
/// Visual: tilting horizon line based on roll angle
///   Hard left  (-45°+):  ╲
///   Left       (-15°):   ╲─
///   Level      (0°):      ─
///   Right      (+15°):   ─╱
///   Hard right (+45°+):    ╱
///
/// Below the horizon: numeric readout "R: -12° P: 5°"
class WhiskeyMark extends StatelessWidget {
  /// Roll angle in degrees. Negative = left bank, positive = right bank.
  final double? roll;

  /// Pitch angle in degrees. Negative = nose down, positive = nose up.
  final double? pitch;

  const WhiskeyMark({
    super.key,
    this.roll,
    this.pitch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        final horizonSize = size * 0.6;
        final fontSize = size * 0.12;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Horizon indicator
            SizedBox(
              width: horizonSize,
              height: horizonSize,
              child: CustomPaint(
                painter: _HorizonPainter(
                  roll: roll ?? 0,
                  pitch: pitch ?? 0,
                  lineColor: theme.foreground,
                  borderWeight: 8,
                  skyColor: theme.subdued,
                  groundColor: theme.background,
                ),
              ),
            ),

            SizedBox(height: size * 0.05),

            // Numeric readout
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Roll: ${_formatAngle(roll)}',
                  style: TextStyle(
                    fontSize: fontSize * 0.5,
                    fontWeight: FontWeight.w400,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: theme.foreground,
                  ),
                ),
                SizedBox(width: size * 0.1),
                Text(
                  'Pitch: ${_formatAngle(pitch)}',
                  style: TextStyle(
                    fontSize: fontSize * 0.5,
                    fontWeight: FontWeight.w400,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: theme.subdued,
                  ),
                ),
              ],
            ),

            // Label
            Text(
              'Attitude',
              style: TextStyle(
                fontSize: fontSize * 0.8,
                fontWeight: FontWeight.w400,
                color: theme.subdued,
                letterSpacing: 1,
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatAngle(double? angle) {
    if (angle == null) return '—°';
    return '${
      angle.round() > 180 ? angle.round() - 360 : angle.round()
      }°';
  }
}

/// Custom painter for the tilting horizon line
class _HorizonPainter extends CustomPainter {
  final double roll;
  final double pitch;
  final double borderWeight;
  final Color lineColor;
  final Color skyColor;
  final Color groundColor;

  _HorizonPainter({
    required this.roll,
    required this.pitch,
    required this.borderWeight,
    required this.lineColor,
    required this.skyColor,
    required this.groundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    // Clip to circle
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));

    // Convert roll to radians (negate so positive roll tilts right visually)
    final rollRad = -roll * math.pi / 180;

    // Pitch offset (positive pitch moves horizon down, showing more sky)
    // Scale: 90° pitch = full radius displacement
    final pitchOffset = (pitch / 90) * radius;

    // Calculate horizon line endpoints
    // The horizon is a horizontal line that we rotate by roll and offset by pitch
    final horizonY = center.dy + pitchOffset;

    // Paint sky (above horizon)
    final skyPaint = Paint()..color = skyColor;
    final groundPaint = Paint()..color = groundColor;

    // Create rotated horizon path
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rollRad);
    canvas.translate(-center.dx, -center.dy);

    // Sky rectangle (above horizon)
    canvas.drawRect(
      Rect.fromLTRB(
        center.dx - radius * 2,
        center.dy - radius * 2,
        center.dx + radius * 2,
        horizonY,
      ),
      skyPaint,
    );

    // Ground rectangle (below horizon)
    canvas.drawRect(
      Rect.fromLTRB(
        center.dx - radius * 2,
        horizonY,
        center.dx + radius * 2,
        center.dy + radius * 2,
      ),
      groundPaint,
    );

    // Horizon line
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(center.dx - radius, horizonY),
      Offset(center.dx + radius, horizonY),
      linePaint,
    );

    canvas.restore();

    // Draw circle border
    final borderPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.5)
      ..strokeWidth = borderWeight
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius - 1, borderPaint);

    // Draw center reference mark (fixed, doesn't rotate)
    final refPaint = Paint()
      ..color = lineColor
      ..strokeWidth = borderWeight * 0.8
      ..style = PaintingStyle.stroke;

    // Small wings
    canvas.drawLine(
      Offset(center.dx - radius * 0.3, center.dy),
      Offset(center.dx - radius * 0.1, center.dy),
      refPaint,
    );
    canvas.drawLine(
      Offset(center.dx + radius * 0.1, center.dy),
      Offset(center.dx + radius * 0.3, center.dy),
      refPaint,
    );
    // Center vertical line
    canvas.drawLine(
      Offset(center.dx, center.dy - radius * 0.05),
      Offset(center.dx, center.dy + radius * 0.1),
      refPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_HorizonPainter oldDelegate) {
    return roll != oldDelegate.roll ||
        pitch != oldDelegate.pitch ||
        lineColor != oldDelegate.lineColor;
  }
}
