import 'package:flutter/material.dart';

import '../services/websocket_service.dart';
import '../theme/app_theme.dart';

/// Android-style persistent status bar for system indicators.
/// Shows GPS satellites, LTE signal, Pi temp, voltage, WS status at a glance.
class SystemBar extends StatelessWidget {
  final int? gpsSatellites; // null = disconnected
  final int? lteSignal; // null = disconnected, 0-4 bars
  final double? piTemp; // null = unavailable
  final double? voltage; // null = Arduino disconnected
  final WsConnectionState? wsState; // WebSocket connection state

  const SystemBar({
    super.key,
    this.gpsSatellites,
    this.lteSignal,
    this.piTemp,
    this.voltage,
    this.wsState,
  });

  /// Get WebSocket status text and abnormal flag
  (String, bool) _wsStatus() {
    switch (wsState) {
      case WsConnectionState.connected:
        return ('OK', false);
      case WsConnectionState.connecting:
        return ('...', true);
      case WsConnectionState.disconnected:
      case null:
        return ('OFF', true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final (wsText, wsAbnormal) = _wsStatus();

    return Expanded(
      flex: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Font sizes relative to bar height
          final labelSize = constraints.maxHeight * 0.5;
          final valueSize = constraints.maxHeight * 0.5;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left group: WS, GPS, LTE
                _Indicator(
                  label: 'WS',
                  value: wsText,
                  isAbnormal: wsAbnormal,
                  alignment: Alignment.centerLeft,
                  labelSize: labelSize,
                  valueSize: valueSize,
                  flex: 2,
                  theme: theme,
                ),
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
                  alignment: Alignment.centerLeft,
                  labelSize: labelSize,
                  valueSize: valueSize,
                  flex: 2,
                  theme: theme,
                ),
                _Indicator(
                  label: 'Mains',
                  value: voltage != null ? '${voltage!.toStringAsFixed(1)} V' : 'N/A',
                  isAbnormal: voltage == null || voltage! < 11.7 || voltage! > 14.5,
                  alignment: Alignment.centerLeft,
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
