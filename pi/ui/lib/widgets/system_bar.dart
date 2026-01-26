import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Android-style persistent status bar for system indicators.
/// Shows GPS satellites, LTE signal, Pi temp, voltage at a glance.
class SystemBar extends StatelessWidget {
  final int? gpsSatellites; // null = disconnected
  final int? lteSignal; // null = disconnected, 0-4 bars
  final double? piTemp; // null = unavailable
  final double? voltage; // null = Arduino disconnected

  const SystemBar({
    super.key,
    this.gpsSatellites,
    this.lteSignal,
    this.piTemp,
    this.voltage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return Expanded(
      flex: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Font sizes relative to bar height
          final labelSize = constraints.maxHeight * 0.5;
          final valueSize = constraints.maxHeight * 0.5;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.subdued.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left group: GPS, LTE
                _Indicator(
                  label: 'GPS',
                  value: gpsSatellites?.toString() ?? 'N/A',
                  isAbnormal: gpsSatellites == null || gpsSatellites == 0,
                  alignment: Alignment.centerLeft,
                  labelSize: labelSize,
                  valueSize: valueSize,
                  flex: 2,
                  theme: theme,
                ),
                _Indicator(
                  label: 'LTE',
                  value: lteSignal?.toString() ?? 'N/A',
                  isAbnormal: lteSignal == null,
                  alignment: Alignment.centerLeft,
                  labelSize: labelSize,
                  valueSize: valueSize,
                  flex: 2,
                  theme: theme,
                ),

                // Right group: Pi, Chassis
                _Indicator(
                  label: 'Pi',
                  value: piTemp != null ? '${piTemp!.toStringAsFixed(1)} °C' : 'N/A',
                  isAbnormal: piTemp == null || piTemp! > 80,
                  alignment: Alignment.centerRight,
                  labelSize: labelSize,
                  valueSize: valueSize,
                  flex: 2,
                  theme: theme,
                ),
                _Indicator(
                  label: 'Chassis',
                  value: voltage != null ? '${voltage!.toStringAsFixed(1)} V' : 'N/A',
                  isAbnormal: voltage == null || voltage! < 11.9,
                  alignment: Alignment.centerRight,
                  labelSize: labelSize,
                  valueSize: valueSize,
                  flex: 3,
                  theme: theme,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Single status indicator in a fixed-width flex slot.
class _Indicator extends StatelessWidget {
  final String label;
  final String value;
  final bool isAbnormal;
  final Alignment alignment;
  final double labelSize;
  final double valueSize;
  final int flex;
  final AppTheme theme;

  const _Indicator({
    required this.label,
    required this.value,
    required this.isAbnormal,
    required this.alignment,
    required this.labelSize,
    required this.valueSize,
    required this.flex,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: alignment,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$label ',
              style: TextStyle(
                fontSize: labelSize,
                color: theme.subdued,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: valueSize,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: isAbnormal ? theme.highlight : theme.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
