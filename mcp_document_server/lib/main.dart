import 'package:flutter/material.dart';
import 'package:mcp_llm/mcp_llm.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Import local files
import 'services/server_service.dart';
import 'screens/server_home.dart';

// Global service instances
late ServerService serverService;

void main() async {
  // Initialize Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // Set up logging
  _setupLogging();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize services
  serverService = ServerService();

  // Run the UI
  runApp(const MCPDocumentServerApp());
}

void _setupLogging() {
  // Set log level
  Logger.setAllLevels(_getLogLevel(dotenv.env['LOG_LEVEL'] ?? 'info'));
}

LogLevel _getLogLevel(String levelName) {
  switch (levelName.toLowerCase()) {
    case 'none':
      return LogLevel.none;
    case 'error':
      return LogLevel.error;
    case 'warning':
      return LogLevel.warning;
    case 'info':
      return LogLevel.info;
    case 'debug':
      return LogLevel.debug;
    case 'trace':
      return LogLevel.trace;
    default:
      return LogLevel.none;
  }
}

class MCPDocumentServerApp extends StatelessWidget {
  const MCPDocumentServerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MCP Document Server',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const ServerHome(),
    );
  }
}