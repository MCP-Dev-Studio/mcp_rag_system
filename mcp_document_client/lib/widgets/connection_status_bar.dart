import 'package:flutter/material.dart';

/// Widget to display connection status
class ConnectionStatusBar extends StatelessWidget {
  final bool isConnected;
  final String status;
  final VoidCallback onConnect;

  const ConnectionStatusBar({
    Key? key,
    required this.isConnected,
    required this.status,
    required this.onConnect,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: isConnected
          ? theme.colorScheme.primary.withOpacity(0.1)
          : theme.colorScheme.error.withOpacity(0.1),
      child: Row(
        children: [
          // Status indicator
          Icon(
            isConnected ? Icons.cloud_done : Icons.cloud_off,
            color: isConnected ? theme.colorScheme.primary : theme.colorScheme.error,
            size: 20.0,
          ),
          const SizedBox(width: 8.0),
          // Status text
          Expanded(
            child: Text(
              status,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isConnected ? theme.colorScheme.primary : theme.colorScheme.error,
              ),
            ),
          ),
          // Connect button (if not connected)
          if (!isConnected)
            TextButton.icon(
              onPressed: onConnect,
              icon: const Icon(Icons.link),
              label: const Text('Connect'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}