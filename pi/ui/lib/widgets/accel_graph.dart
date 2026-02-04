import 'dart:async';
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
  Timer? _ghostResetTimer;

  @override
  void initState() {
    super.initState();
    _setupGhostTimer();
  }

  @override
  void didUpdateWidget(AccelGraph oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update ghost position if current magnitude exceeds previous peak
    final currentAx = widget.ax ?? 0;
    final currentAy = widget.ay ?? 0;
    final currentMag = math.sqrt(currentAx * currentAx + currentAy * currentAy);

    if (currentMag > _ghostMagnitude) {
      _ghostAx = currentAx;
      _ghostAy = currentAy;
      _ghostMagnitude = currentMag;
    }

    // Restart timer if period changed
    if (oldWidget.ghostTrackPeriod != widget.ghostTrackPeriod) {
      _setupGhostTimer();
    }
  }

  void _setupGhostTimer() {
    _ghostResetTimer?.cancel();
    if (widget.ghostTrackPeriod != null) {
      _ghostResetTimer = Timer.periodic(widget.ghostTrackPeriod!, (_) {
        setState(() {
          // Reset ghost to current position
          _ghostAx = widget.ax ?? 0;
          _ghostAy = widget.ay ?? 0;
          _ghostMagnitude = math.sqrt(_ghostAx * _ghostAx + _ghostAy * _ghostAy);
        });
      });
    }
  }

  @override
  void dispose() {
    _ghostResetTimer?.cancel();
    super.dispose();
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
              'ACCEL',
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
    return '${force.toStringAsFixed(1)}G';
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
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final halfSize = size.width / 2;
    final radius = math.min(size.width, size.height) / 2;

    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));

    // No rectangular border

    // Grid lines at 0.5G intervals
    final gridPaint = Paint()
      ..color = subdued
      ..strokeWidth = strokeWeight * 0.6
      ..style = PaintingStyle.stroke;

    final gStep = 0.5;
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

    // G-ring markers (circles at 1G and 2G for quick reference)
    final ringPaint = Paint()
      ..color = subdued
      ..strokeWidth = strokeWeight
      ..style = PaintingStyle.stroke;

    for (double g = 1.0; g <= maxG; g += 1.0) {
      final radius = (g / maxG) * halfSize;
      canvas.drawCircle(center, radius, ringPaint);
    }

    // Ghost dot (if enabled and has data)
    if (showGhost) {
      final ghostX = center.dx + (ghostAx / maxG) * halfSize;
      final ghostY = center.dy - (ghostAy / maxG) * halfSize; // Y inverted (up = positive)
      final ghostRadius = halfSize * 0.08;

      final ghostPaint = Paint()
        ..color = subdued.withValues(alpha: 0.5)
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
        subdued != oldDelegate.subdued;
  }
}
