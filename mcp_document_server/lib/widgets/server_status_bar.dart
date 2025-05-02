import 'package:flutter/material.dart';

/// Widget to display server status
class ServerStatusBar extends StatelessWidget {
  final bool isRunning;
  final String statusMessage;
  final int connectedClients;

  const ServerStatusBar({
    Key? key,
    required this.isRunning,
    required this.statusMessage,
    required this.connectedClients,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: isRunning
          ? theme.colorScheme.primary.withOpacity(0.1)
          : theme.colorScheme.error.withOpacity(0.1),
      child: Row(
        children: [
          // Status indicator
          Icon(
            isRunning ? Icons.cloud_done : Icons.cloud_off,
            color: isRunning ? theme.colorScheme.primary : theme.colorScheme.error,
            size: 20.0,
          ),
          const SizedBox(width: 8.0),
          // Status text
          Expanded(
            child: Text(
              statusMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isRunning ? theme.colorScheme.primary : theme.colorScheme.error,
              ),
            ),
          ),
          // Connected clients indicator
          if (isRunning)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.person,
                    size: 16.0,
                  ),
                  const SizedBox(width: 4.0),
                  Text(
                    '$connectedClients',
                    style: theme.textTheme.labelMedium,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}