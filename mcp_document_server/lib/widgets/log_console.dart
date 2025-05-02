import 'package:flutter/material.dart';

/// Widget to display server logs
class LogConsole extends StatelessWidget {
  final List<String> logMessages;
  final ScrollController scrollController;

  const LogConsole({
    Key? key,
    required this.logMessages,
    required this.scrollController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Console header
        Container(
          padding: const EdgeInsets.all(8.0),
          color: theme.colorScheme.surfaceVariant,
          child: Row(
            children: [
              const Icon(Icons.terminal, size: 20.0),
              const SizedBox(width: 8.0),
              Text(
                'Server Logs',
                style: theme.textTheme.titleSmall,
              ),
              const Spacer(),
              Text(
                '${logMessages.length} messages',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        // Log display
        Expanded(
          child: Container(
            color: theme.colorScheme.surface,
            child: logMessages.isEmpty
                ? const Center(
              child: Text('No logs available'),
            )
                : ListView.builder(
              controller: scrollController,
              itemCount: logMessages.length,
              itemBuilder: (context, index) {
                final message = logMessages[index];
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 4.0,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: theme.dividerColor.withOpacity(0.1),
                      ),
                    ),
                  ),
                  child: Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
