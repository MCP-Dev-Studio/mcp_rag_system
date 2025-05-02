import 'package:flutter/material.dart';
import '../models/chat_message.dart';

/// Widget to display a chat message
class ChatMessageWidget extends StatelessWidget {
  final ChatMessage message;

  const ChatMessageWidget({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine background color and alignment based on message type
    Color backgroundColor;
    Alignment alignment;

    switch (message.type) {
      case ChatMessageType.user:
        backgroundColor = theme.colorScheme.primaryContainer.withOpacity(0.7);
        alignment = Alignment.centerRight;
        break;
      case ChatMessageType.assistant:
        backgroundColor = theme.colorScheme.secondaryContainer.withOpacity(0.7);
        alignment = Alignment.centerLeft;
        break;
      case ChatMessageType.system:
        backgroundColor = theme.colorScheme.surfaceVariant.withOpacity(0.5);
        alignment = Alignment.center;
        break;
      case ChatMessageType.tool:
        backgroundColor = theme.colorScheme.tertiaryContainer.withOpacity(0.7);
        alignment = Alignment.centerLeft;
        break;
      case ChatMessageType.error:
        backgroundColor = theme.colorScheme.errorContainer.withOpacity(0.7);
        alignment = Alignment.center;
        break;
    }

    // Format timestamp
    final formattedTime = '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16.0),
        ),
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Message header
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon based on message type
                Icon(
                  _getIconForMessageType(message.type),
                  size: 16.0,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8.0),
                // Display sender name
                Text(
                  _getSenderName(message.type),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                // Timestamp
                Text(
                  formattedTime,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            // Message content
            Text(
              message.content,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            // Display tool information if it's a tool message
            if (message.type == ChatMessageType.tool && message.toolName != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Tool: ${message.toolName}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Get appropriate icon for message type
  IconData _getIconForMessageType(ChatMessageType type) {
    switch (type) {
      case ChatMessageType.user:
        return Icons.person;
      case ChatMessageType.assistant:
        return Icons.smart_toy;
      case ChatMessageType.system:
        return Icons.info;
      case ChatMessageType.tool:
        return Icons.build;
      case ChatMessageType.error:
        return Icons.error;
    }
  }

  // Get sender name based on message type
  String _getSenderName(ChatMessageType type) {
    switch (type) {
      case ChatMessageType.user:
        return 'You';
      case ChatMessageType.assistant:
        return 'Assistant';
      case ChatMessageType.system:
        return 'System';
      case ChatMessageType.tool:
        return message.toolName ?? 'Tool';
      case ChatMessageType.error:
        return 'Error';
    }
  }
}