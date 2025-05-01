import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logging/logging.dart';

// Import local files
import 'services/server_service.dart';
import 'services/document_service.dart';
import 'screens/server_home.dart';

// Global service instances
late ServerService serverService;
late DocumentService documentService;

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
  runApp(const MyCPDocumentServerApp());
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

class MyCPDocumentServerApp extends StatelessWidget {
  const MyCPDocumentServerApp({Key? key}) : super(key: key);

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
