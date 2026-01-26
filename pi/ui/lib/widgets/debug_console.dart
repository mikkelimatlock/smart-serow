import 'dart:async';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Generic debug console that displays streaming log messages.
///
/// Can be wired to any message source via [messageStream] and [initialMessages].
/// Example sources: WebSocketService.debugStream, ArduinoService logs, etc.
class DebugConsole extends StatefulWidget {
  /// Stream of new messages to display
  final Stream<String> messageStream;

  /// Initial messages to populate (e.g., from a buffer)
  final List<String> initialMessages;

  /// Maximum lines to display
  final int maxLines;

  const DebugConsole({
    super.key,
    required this.messageStream,
    this.initialMessages = const [],
    this.maxLines = 8,
  });

  @override
  State<DebugConsole> createState() => _DebugConsoleState();
}

class _DebugConsoleState extends State<DebugConsole> {
  final List<String> _messages = [];
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();

    // Initialize with existing buffer
    _messages.addAll(widget.initialMessages);
    _trimMessages();

    // Subscribe to new messages
    _sub = widget.messageStream.listen((msg) {
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
    _sub?.cancel();
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
