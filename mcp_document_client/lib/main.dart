// File: mcp_document_client/lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart';

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

  // Set up logging
  _setupLogging();

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

void _setupLogging() {
  // Set log level
  Logger.root.level = _getLogLevel(dotenv.env['LOG_LEVEL'] ?? 'info');

  // Set up log listener
  Logger.root.onRecord.listen((record) {
    // ignore: avoid_print
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
}

Level _getLogLevel(String levelName) {
  switch (levelName.toLowerCase()) {
    case 'all':
      return Level.ALL;
    case 'finest':
      return Level.FINEST;
    case 'finer':
      return Level.FINER;
    case 'fine':
      return Level.FINE;
    case 'config':
      return Level.CONFIG;
    case 'info':
      return Level.INFO;
    case 'warning':
      return Level.WARNING;
    case 'severe':
      return Level.SEVERE;
    case 'shout':
      return Level.SHOUT;
    case 'off':
      return Level.OFF;
    default:
      return Level.INFO;
  }
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