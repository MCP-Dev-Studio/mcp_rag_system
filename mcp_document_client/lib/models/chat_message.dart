import 'package:flutter/foundation.dart';

/// Chat message types
enum ChatMessageType {
  user,      // User message
  assistant, // Assistant message
  system,    // System message
  tool,      // Tool result message
  error      // Error message
}

/// Chat message model
class ChatMessage {
  /// Unique message ID
  final String id;

  /// Message type
  final ChatMessageType type;

  /// Message content
  final String content;

  /// Message timestamp
  final DateTime timestamp;

  /// Tool name (for tool messages)
  final String? toolName;

  /// Tool arguments (for tool messages)
  final Map<String, dynamic>? toolArguments;

  /// Create a chat message
  ChatMessage({
    required this.id,
    required this.type,
    required this.content,
    DateTime? timestamp,
    this.toolName,
    this.toolArguments,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create a user message
  factory ChatMessage.user(String content) {
    return ChatMessage(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      type: ChatMessageType.user,
      content: content,
    );
  }

  /// Create an assistant message
  factory ChatMessage.assistant(String content) {
    return ChatMessage(
      id: 'assistant_${DateTime.now().millisecondsSinceEpoch}',
      type: ChatMessageType.assistant,
      content: content,
    );
  }

  /// Create a system message
  factory ChatMessage.system(String content) {
    return ChatMessage(
      id: 'system_${DateTime.now().millisecondsSinceEpoch}',
      type: ChatMessageType.system,
      content: content,
    );
  }

  /// Create a tool message
  factory ChatMessage.tool(String toolName, String content, {Map<String, dynamic>? arguments}) {
    return ChatMessage(
      id: 'tool_${DateTime.now().millisecondsSinceEpoch}',
      type: ChatMessageType.tool,
      content: content,
      toolName: toolName,
      toolArguments: arguments,
    );
  }

  /// Create an error message
  factory ChatMessage.error(String content) {
    return ChatMessage(
      id: 'error_${DateTime.now().millisecondsSinceEpoch}',
      type: ChatMessageType.error,
      content: content,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString(),
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      if (toolName != null) 'toolName': toolName,
      if (toolArguments != null) 'toolArguments': toolArguments,
    };
  }

  /// Create from JSON
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      type: ChatMessageType.values.firstWhere(
            (e) => e.toString() == json['type'],
        orElse: () => ChatMessageType.system,
      ),
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      toolName: json['toolName'] as String?,
      toolArguments: json['toolArguments'] as Map<String, dynamic>?,
    );
  }
}