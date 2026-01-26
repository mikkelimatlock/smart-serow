import 'dart:async';
import 'package:flutter/material.dart';

import '../services/websocket_service.dart';
import '../theme/app_theme.dart';

/// Self-contained debug console that displays WebSocket log messages.
/// Subscribes to WebSocketService.debugStream internally.
class DebugConsole extends StatefulWidget {
  /// Maximum lines to display
  final int maxLines;

  const DebugConsole({
    super.key,
    this.maxLines = 8,
  });

  @override
  State<DebugConsole> createState() => _DebugConsoleState();
}

class _DebugConsoleState extends State<DebugConsole> {
  final List<String> _messages = [];
  StreamSubscription<String>? _debugSub;

  @override
  void initState() {
    super.initState();

    // Initialize with existing buffer
    _messages.addAll(WebSocketService.instance.debugMessages);
    _trimMessages();

    // Subscribe to new messages
    _debugSub = WebSocketService.instance.debugStream.listen((msg) {
      setState(() {
        _messages.add(msg);
        _trimMessages();
      });
    });
  }

  void _trimMessages() {
    while (_messages.length > widget.maxLines) {
      _messages.removeAt(0);
    }
  }

  @override
  void dispose() {
    _debugSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(4),
      child: Text(
        _messages.isEmpty ? '(no messages)' : _messages.join('\n'),
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 34,
          color: theme.foreground,
          height: 1.2,
        ),
      ),
    );
  }
}
