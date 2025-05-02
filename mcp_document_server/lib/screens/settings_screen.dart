import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Global service instance
import '../main.dart' show serverService;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Logger _logger = Logger('SettingsScreen');

  // Controllers
  final TextEditingController _openAiApiKeyController = TextEditingController();
  final TextEditingController _claudeApiKeyController = TextEditingController();
  final TextEditingController _serverPortController = TextEditingController();
  final TextEditingController _authTokenController = TextEditingController();

  // State
  bool _isLoading = false;
  bool _showOpenAiKey = false;
  bool _showClaudeKey = false;
  bool _showAuthToken = false;
  String _logLevel = 'info';
  bool _autoStart = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _openAiApiKeyController.dispose();
    _claudeApiKeyController.dispose();
    _serverPortController.dispose();
    _authTokenController.dispose();
    super.dispose();
  }

  // Load settings
  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load values from .env
      _openAiApiKeyController.text = dotenv.env['OPENAI_API_KEY'] ?? '';
      _claudeApiKeyController.text = dotenv.env['CLAUDE_API_KEY'] ?? '';
      _serverPortController.text = dotenv.env['SERVER_PORT'] ?? '8999';
      _authTokenController.text = dotenv.env['MCP_AUTH_TOKEN'] ?? '';
      _logLevel = dotenv.env['LOG_LEVEL'] ?? 'info';

      // Load values from preferences
      final prefs = await SharedPreferences.getInstance();
      _autoStart = prefs.getBool('auto_start_server') ?? false;
    } catch (e) {
      _logger.severe('Error loading settings: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Save settings
  Future<void> _saveSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Update environment variables in memory
      dotenv.env['OPENAI_API_KEY'] = _openAiApiKeyController.text;
      dotenv.env['CLAUDE_API_KEY'] = _claudeApiKeyController.text;
      dotenv.env['SERVER_PORT'] = _serverPortController.text;
      dotenv.env['MCP_AUTH_TOKEN'] = _authTokenController.text;
      dotenv.env['LOG_LEVEL'] = _logLevel;

      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_start_server', _autoStart);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully')),
        );
      }

      // Note: Changes to dotenv variables won't persist to the .env file
      // In a real app, we would need to write to the .env file or use a different storage method
    } catch (e) {
      _logger.severe('Error saving settings: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save Settings',
            onPressed: _isLoading ? null : _saveSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Server settings section
            Text('Server Settings', style: theme.textTheme.titleLarge),
            const Divider(),

            // Server port
            TextField(
              controller: _serverPortController,
              decoration: const InputDecoration(
                labelText: 'Server Port',
                hintText: '8999',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16.0),

            // Authentication token
            TextField(
              controller: _authTokenController,
              decoration: InputDecoration(
                labelText: 'Authentication Token',
                hintText: 'Leave empty for no authentication',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_showAuthToken ? Icons.visibility_off : Icons.visibility),
                  onPressed: () {
                    setState(() {
                      _showAuthToken = !_showAuthToken;
                    });
                  },
                ),
              ),
              obscureText: !_showAuthToken,
            ),
            const SizedBox(height: 16.0),

            // Log level dropdown
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Log Level',
                border: OutlineInputBorder(),
              ),
              value: _logLevel,
              items: const [
                DropdownMenuItem(value: 'error', child: Text('Error')),
                DropdownMenuItem(value: 'warning', child: Text('Warning')),
                DropdownMenuItem(value: 'info', child: Text('Info')),
                DropdownMenuItem(value: 'debug', child: Text('Debug')),
                DropdownMenuItem(value: 'trace', child: Text('Trace')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _logLevel = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16.0),

            // Auto-start checkbox
            SwitchListTile(
              title: const Text('Auto-start server on app launch'),
              value: _autoStart,
              onChanged: (value) {
                setState(() {
                  _autoStart = value;
                });
              },
            ),

            const SizedBox(height: 32.0),

            // API Keys section
            Text('API Keys', style: theme.textTheme.titleLarge),
            const Divider(),

            // OpenAI API key
            TextField(
              controller: _openAiApiKeyController,
              decoration: InputDecoration(
                labelText: 'OpenAI API Key',
                hintText: 'sk-...',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_showOpenAiKey ? Icons.visibility_off : Icons.visibility),
                  onPressed: () {
                    setState(() {
                      _showOpenAiKey = !_showOpenAiKey;
                    });
                  },
                ),
              ),
              obscureText: !_showOpenAiKey,
            ),
            const SizedBox(height: 16.0),

            // Claude API key
            TextField(
              controller: _claudeApiKeyController,
              decoration: InputDecoration(
                labelText: 'Claude API Key',
                hintText: 'sk-...',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_showClaudeKey ? Icons.visibility_off : Icons.visibility),
                  onPressed: () {
                    setState(() {
                      _showClaudeKey = !_showClaudeKey;
                    });
                  },
                ),
              ),
              obscureText: !_showClaudeKey,
            ),

            const SizedBox(height: 32.0),

            // Server actions section
            Text('Server Actions', style: theme.textTheme.titleLarge),
            const Divider(),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: Icon(serverService.isRunning ? Icons.stop : Icons.play_arrow),
                  label: Text(serverService.isRunning ? 'Stop Server' : 'Start Server'),
                  onPressed: serverService.isRunning
                      ? serverService.stopServer
                      : serverService.startServer,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Restart Server'),
                  onPressed: serverService.isRunning
                      ? serverService.restartServer
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}