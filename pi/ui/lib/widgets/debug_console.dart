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

  /// Optional title for the console (shown in title bar)
  final String? title;

  const DebugConsole({
    super.key,
    required this.messageStream,
    this.initialMessages = const [],
    this.maxLines = 8,
    this.title,
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
      decoration: BoxDecoration(
        color: theme.background.withAlpha(64),
        border: Border.all(color: theme.subdued, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title bar (optional)
          if (widget.title != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: theme.subdued, width: 1),
                ),
              ),
              child: Text(
                widget.title!,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 24,
                  color: theme.subdued,
                ),
              ),
            ),
          // Console content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                _messages.isEmpty ? '(no messages)' : _messages.join('\n'),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 30,
                  color: theme.foreground,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
