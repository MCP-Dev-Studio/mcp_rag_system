import 'package:flutter/foundation.dart';

/// Configuration settings for MCP client
class ClientConfig {
  /// Server URL (SSE endpoint)
  final String serverUrl;

  /// Authentication token (optional)
  final String? authToken;

  /// Whether to auto-connect on app startup
  final bool autoConnect;

  /// Create MCP client configuration
  const ClientConfig({
    required this.serverUrl,
    this.authToken,
    this.autoConnect = false,
  });

  /// Clone with new settings
  ClientConfig copyWith({
    String? serverUrl,
    String? authToken,
    bool? autoConnect,
  }) {
    return ClientConfig(
      serverUrl: serverUrl ?? this.serverUrl,
      authToken: authToken ?? this.authToken,
      autoConnect: autoConnect ?? this.autoConnect,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'serverUrl': serverUrl,
      'authToken': authToken,
      'autoConnect': autoConnect,
    };
  }

  /// Create from JSON
  factory ClientConfig.fromJson(Map<String, dynamic> json) {
    return ClientConfig(
      serverUrl: json['serverUrl'] as String,
      authToken: json['authToken'] as String?,
      autoConnect: json['autoConnect'] as bool? ?? false,
    );
  }

  @override
  String toString() {
    return 'ClientConfig(serverUrl: $serverUrl, autoConnect: $autoConnect)';
  }
}