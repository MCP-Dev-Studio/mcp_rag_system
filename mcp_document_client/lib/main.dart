// File: mcp_document_client/lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import services and models
import 'services/client_service.dart';
import 'models/client_config.dart';

// Import screens
import 'screens/client_home.dart';

// Global service instance
late ClientService clientService;

void main() async {
  // Initialize Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize services
  clientService = ClientService();
  await clientService.initialize();

  // Auto-connect if saved settings exist
  final prefs = await SharedPreferences.getInstance();
  final serverUrl = prefs.getString('server_url') ?? dotenv.env['MCP_SERVER_URL'];
  final authToken = prefs.getString('auth_token') ?? dotenv.env['MCP_AUTH_TOKEN'];

  if (serverUrl != null && serverUrl.isNotEmpty) {
    final config = ClientConfig(
      serverUrl: serverUrl,
      authToken: authToken,
      autoConnect: prefs.getBool('auto_connect') ?? false,
    );

    if (config.autoConnect) {
      await clientService.connect(config);
    }
  }

  // Run the UI
  runApp(const MCPDocumentClientApp());
}

class MCPDocumentClientApp extends StatelessWidget {
  const MCPDocumentClientApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MCP Document Client',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const ClientHome(),
    );
  }
}