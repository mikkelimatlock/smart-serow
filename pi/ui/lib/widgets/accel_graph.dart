import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 2D lateral G-meter showing acceleration as a dot on a cartesian grid.
///
/// Visual: square grid with dot position = (ax, ay) scaled by maxG
/// Optional ghost dot tracks peak magnitude within ghostTrackPeriod window.
class AccelGraph extends StatefulWidget {
  /// X-axis acceleration in g (lateral: negative = left, positive = right)
  final double? ax;

  /// Y-axis acceleration in g (longitudinal: negative = back, positive = forward)
  final double? ay;

  /// Maximum G range for the grid (default 2.0 = ±2G)
  final double maxG;

  /// If set, shows a ghost dot at peak magnitude position, resetting after this duration
  final Duration? ghostTrackPeriod;

  const AccelGraph({
    super.key,
    this.ax,
    this.ay,
    this.maxG = 2.0,
    this.ghostTrackPeriod,
  });

  @override
  State<AccelGraph> createState() => _AccelGraphState();
}

class _AccelGraphState extends State<AccelGraph> {
  // Ghost dot tracking
  double _ghostAx = 0;
  double _ghostAy = 0;
  double _ghostMagnitude = 0;

  // Timestamped history for sliding window
  List<({DateTime time, double ax, double ay})> _history = [];

  @override
  void didUpdateWidget(AccelGraph oldWidget) {
    super.didUpdateWidget(oldWidget);

    final currentAx = widget.ax ?? 0;
    final currentAy = widget.ay ?? 0;
    final now = DateTime.now();

    // Only track history when ghostTrackPeriod is configured
    if (widget.ghostTrackPeriod != null) {
      // Add current reading to history
      _history.add((time: now, ax: currentAx, ay: currentAy));

      // Prune entries outside the window
      final cutoff = now.subtract(widget.ghostTrackPeriod!);
      _history.removeWhere((e) => e.time.isBefore(cutoff));

      // Recalculate ghost as max magnitude from current window
      _ghostAx = currentAx;
      _ghostAy = currentAy;
      _ghostMagnitude = 0;

      for (final entry in _history) {
        final mag = math.sqrt(entry.ax * entry.ax + entry.ay * entry.ay);
        if (mag > _ghostMagnitude) {
          _ghostAx = entry.ax;
          _ghostAy = entry.ay;
          _ghostMagnitude = mag;
        }
      }
    } else {
      // No window configured - clear history to save memory
      _history.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        final gridSize = size * 0.6;
        final fontSize = size * 0.12;
        final strokeSize = size * 0.015;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // G-meter grid
            SizedBox(
              width: gridSize,
              height: gridSize,
              child: CustomPaint(
                painter: _AccelGraphPainter(
                  ax: widget.ax ?? 0,
                  ay: widget.ay ?? 0,
                  ghostAx: _ghostAx,
                  ghostAy: _ghostAy,
                  showGhost: widget.ghostTrackPeriod != null && _ghostMagnitude > 0,
                  maxG: widget.maxG,
                  foreground: theme.foreground,
                  subdued: theme.subdued,
                  background: theme.background,
                  strokeWeight: strokeSize,
                  traceBuffer: _history.map((e) => Offset(e.ax, e.ay)).toList(),
                ),
              ),
            ),

            SizedBox(height: size * 0.03),

            // Numeric readout
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Lon: ${_formatAccel(widget.ay)} (${_formatAccel(_ghostAy)})',
                  style: TextStyle(
                    fontSize: fontSize * 0.5,
                    fontWeight: FontWeight.w400,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: theme.foreground,
                  ),
                ),
                SizedBox(width: size * 0.1),
                Text(
                  'Lat: ${_formatAccel(widget.ax)} (${_formatAccel(_ghostAx)})',
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
              'Acceleration',
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

  String _formatAccel(double? force) {
    if (force == null) return '—°';
    return '${
      force.toStringAsFixed(1) == '-0.0' ? '0.0' : force.toStringAsFixed(1)
      }G';
  }
}

/// Custom painter for the G-meter grid and dots
class _AccelGraphPainter extends CustomPainter {
  final double ax;
  final double ay;
  final double ghostAx;
  final double ghostAy;
  final bool showGhost;
  final double maxG;
  final Color foreground;
  final Color subdued;
  final Color background;
  final double strokeWeight;
  final List<Offset> traceBuffer;

  _AccelGraphPainter({
    required this.ax,
    required this.ay,
    required this.ghostAx,
    required this.ghostAy,
    required this.showGhost,
    required this.maxG,
    required this.foreground,
    required this.subdued,
    required this.background,
    required this.strokeWeight,
    required this.traceBuffer,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final halfSize = size.width / 2;
    final radius = math.min(size.width, size.height) / 2;

    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));

    // No rectangular border

    // Grid lines at 0.25G intervals
    final gridPaint = Paint()
      ..color = subdued
      ..strokeWidth = strokeWeight * 0.4
      ..style = PaintingStyle.stroke;

    final gStep = 0.25;
    for (double g = gStep; g < maxG; g += gStep) {
      final offset = (g / maxG) * halfSize;

      // Vertical lines (left and right of center)
      canvas.drawLine(
        Offset(center.dx - offset, 0),
        Offset(center.dx - offset, size.height),
        gridPaint,
      );
      canvas.drawLine(
        Offset(center.dx + offset, 0),
        Offset(center.dx + offset, size.height),
        gridPaint,
      );

      // Horizontal lines (above and below center)
      canvas.drawLine(
        Offset(0, center.dy - offset),
        Offset(size.width, center.dy - offset),
        gridPaint,
      );
      canvas.drawLine(
        Offset(0, center.dy + offset),
        Offset(size.width, center.dy + offset),
        gridPaint,
      );
    }

    // Center axis lines (heavier)
    final axisPaint = Paint()
      ..color = subdued
      ..strokeWidth = strokeWeight
      ..style = PaintingStyle.stroke;

    // Horizontal axis
    canvas.drawLine(
      Offset(0, center.dy),
      Offset(size.width, center.dy),
      axisPaint,
    );
    // Vertical axis
    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      axisPaint,
    );

    // G-ring markers (circles at every 0.5G for quick reference)
    final ringPaint = Paint()
      ..color = subdued
      ..strokeWidth = strokeWeight * 0.5
      ..style = PaintingStyle.stroke;

    for (double g = 0.5; g <= maxG; g += 0.5) {
      final radius = (g / maxG) * halfSize;
      canvas.drawCircle(center, radius, ringPaint);
    }

    // Trace line
    if (traceBuffer.length >= 2) {
      final tracePaint = Paint()
        ..color = foreground
        ..strokeWidth = strokeWeight * 0.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path();
      for (int i = 0; i < traceBuffer.length; i++) {
        final pt = traceBuffer[i];
        final x = center.dx + (pt.dx.clamp(-maxG, maxG) / maxG) * halfSize;
        final y = center.dy - (pt.dy.clamp(-maxG, maxG) / maxG) * halfSize;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, tracePaint);
    }

    // Ghost dot (if enabled and has data)
    if (showGhost) {
      final ghostX = center.dx + (ghostAx / maxG) * halfSize;
      final ghostY = center.dy - (ghostAy / maxG) * halfSize; // Y inverted (up = positive)
      final ghostRadius = halfSize * 0.08;

      final ghostPaint = Paint()
        ..color = subdued
        ..strokeWidth = strokeWeight
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(Offset(ghostX, ghostY), ghostRadius, ghostPaint);
    }

    // Main dot - clamp to grid bounds
    final clampedAx = ax.clamp(-maxG, maxG);
    final clampedAy = ay.clamp(-maxG, maxG);
    final dotX = center.dx + (clampedAx / maxG) * halfSize;
    final dotY = center.dy - (clampedAy / maxG) * halfSize; // Y inverted (up = positive)
    final dotRadius = halfSize * 0.1;

    final dotPaint = Paint()
      ..color = foreground
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(dotX, dotY), dotRadius, dotPaint);
  }

  @override
  bool shouldRepaint(_AccelGraphPainter oldDelegate) {
    return ax != oldDelegate.ax ||
        ay != oldDelegate.ay ||
        ghostAx != oldDelegate.ghostAx ||
        ghostAy != oldDelegate.ghostAy ||
        showGhost != oldDelegate.showGhost ||
        maxG != oldDelegate.maxG ||
        foreground != oldDelegate.foreground ||
        subdued != oldDelegate.subdued ||
        traceBuffer != oldDelegate.traceBuffer;
  }
}
