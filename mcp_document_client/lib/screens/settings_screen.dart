import 'package:flutter/material.dart';
import 'package:mcp_llm/mcp_llm.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Local imports
import '../models/client_config.dart';
import '../main.dart' show clientService;

/// Screen for configuring client settings
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Logger _logger = Logger('SettingsScreen');

  // Controllers
  final TextEditingController _serverUrlController = TextEditingController();
  final TextEditingController _authTokenController = TextEditingController();

  // State
  bool _isLoading = false;
  bool _autoConnect = false;
  bool _showAuthToken = false;
  String _logLevel = 'info';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _authTokenController.dispose();
    super.dispose();
  }

  // Load settings
  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      // Load server URL and auth token
      _serverUrlController.text = prefs.getString('server_url') ?? '';
      _authTokenController.text = prefs.getString('auth_token') ?? '';

      // Load other settings
      _autoConnect = prefs.getBool('auto_connect') ?? false;
      _logLevel = prefs.getString('log_level') ?? 'info';

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      _logger.error('Error loading settings: $e');

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
        );
      }
    }
  }

  // Save settings
  Future<void> _saveSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      // Save server URL and auth token
      await prefs.setString('server_url', _serverUrlController.text);
      await prefs.setString('auth_token', _authTokenController.text);

      // Save other settings
      await prefs.setBool('auto_connect', _autoConnect);
      await prefs.setString('log_level', _logLevel);

      // Update log level
      Logger.setAllLevels(_getLogLevel(_logLevel));

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully')),
        );
      }
    } catch (e) {
      _logger.error('Error saving settings: $e');

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e')),
        );
      }
    }
  }

  // Get log level from string
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

  // Reset to defaults
  Future<void> _resetToDefaults() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text('Are you sure you want to reset all settings to defaults?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    // Reset settings
    setState(() {
      _serverUrlController.text = '';
      _authTokenController.text = '';
      _autoConnect = false;
      _logLevel = 'info';
    });

    // Save changes
    await _saveSettings();
  }

  // Connect to server with current settings
  Future<void> _connectToServer() async {
    // Validate URL
    if (_serverUrlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server URL is required')),
      );
      return;
    }

    // Set loading state
    setState(() {
      _isLoading = true;
    });

    try {
      // Create config
      final config = ClientConfig(
        serverUrl: _serverUrlController.text,
        authToken: _authTokenController.text.isEmpty ? null : _authTokenController.text,
        autoConnect: _autoConnect,
      );

      // Connect to server
      final success = await clientService.connect(config);

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Connected to server')),
          );

          // Go back to home screen
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to connect: ${clientService.connectionStatus}')),
          );
        }
      }
    } catch (e) {
      _logger.error('Error connecting to server: $e');

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error connecting to server: $e')),
        );
      }
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
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset to Defaults',
            onPressed: _isLoading ? null : _resetToDefaults,
          ),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connection settings section
            Text('Connection Settings', style: theme.textTheme.titleLarge),
            const Divider(),

            // Server URL
            TextField(
              controller: _serverUrlController,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'e.g. http://localhost:8999/sse',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Authentication token
            TextField(
              controller: _authTokenController,
              decoration: InputDecoration(
                labelText: 'Authentication Token (optional)',
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
            const SizedBox(height: 16),

            // Auto-connect option
            SwitchListTile(
              title: const Text('Auto-connect on startup'),
              subtitle: const Text('Automatically connect to the server when the app starts'),
              value: _autoConnect,
              onChanged: (value) {
                setState(() {
                  _autoConnect = value;
                });
              },
            ),

            const SizedBox(height: 24),

            // Application settings section
            Text('Application Settings', style: theme.textTheme.titleLarge),
            const Divider(),

            // Log level
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Log Level',
                border: OutlineInputBorder(),
              ),
              value: _logLevel,
              items: const [
                DropdownMenuItem(value: 'severe', child: Text('Error')),
                DropdownMenuItem(value: 'warning', child: Text('Warning')),
                DropdownMenuItem(value: 'info', child: Text('Info')),
                DropdownMenuItem(value: 'fine', child: Text('Debug')),
                DropdownMenuItem(value: 'finer', child: Text('Verbose')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _logLevel = value;
                  });
                }
              },
            ),

            const SizedBox(height: 32),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                  onPressed: _isLoading ? null : _saveSettings,
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.link),
                  label: const Text('Connect'),
                  onPressed: _isLoading ? null : _connectToServer,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}