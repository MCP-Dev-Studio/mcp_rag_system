import 'package:flutter/material.dart';
import 'package:mcp_client/mcp_client.dart' hide Logger;
import 'package:logging/logging.dart';

// Global service instance
import '../main.dart' show clientService;

/// Screen to display and interact with available MCP tools
class ToolListScreen extends StatefulWidget {
  const ToolListScreen({Key? key}) : super(key: key);

  @override
  State<ToolListScreen> createState() => _ToolListScreenState();
}

class _ToolListScreenState extends State<ToolListScreen> {
  final Logger _logger = Logger('ToolListScreen');

  // State
  List<Tool> _tools = [];
  Tool? _selectedTool;
  bool _isLoading = true;

  // Controllers
  final Map<String, TextEditingController> _paramControllers = {};

  @override
  void initState() {
    super.initState();
    _loadTools();
  }

  @override
  void dispose() {
    // Dispose controllers
    for (final controller in _paramControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // Load available tools
  Future<void> _loadTools() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final tools = clientService.availableTools;

      setState(() {
        _tools = tools;
        _isLoading = false;
      });
    } catch (e) {
      _logger.severe('Error loading tools: $e');

      setState(() {
        _tools = [];
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading tools: $e')),
        );
      }
    }
  }

  // Select a tool to view details
  void _selectTool(Tool tool) {
    // Clear previous controllers
    for (final controller in _paramControllers.values) {
      controller.dispose();
    }
    _paramControllers.clear();

    // Create controllers for each parameter
    if (tool.inputSchema != null &&
        tool.inputSchema!.containsKey('properties') &&
        tool.inputSchema!['properties'] is Map) {
      final properties = tool.inputSchema!['properties'] as Map;

      for (final key in properties.keys) {
        _paramControllers[key.toString()] = TextEditingController();
      }
    }

    setState(() {
      _selectedTool = tool;
    });
  }

  // Execute selected tool
  Future<void> _executeTool() async {
    if (_selectedTool == null) return;

    // Build arguments
    final Map<String, dynamic> arguments = {};

    for (final entry in _paramControllers.entries) {
      final key = entry.key;
      final value = entry.value.text;

      // Skip empty values
      if (value.isEmpty) continue;

      // Try to parse as number or boolean
      if (value == 'true') {
        arguments[key] = true;
      } else if (value == 'false') {
        arguments[key] = false;
      } else if (int.tryParse(value) != null) {
        arguments[key] = int.parse(value);
      } else if (double.tryParse(value) != null) {
        arguments[key] = double.parse(value);
      } else {
        arguments[key] = value;
      }
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Execute tool
      await clientService.executeTool(_selectedTool!.name, arguments);

      // Dismiss loading indicator
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Navigate back to chat
      if (mounted) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tool executed successfully')),
        );
      }
    } catch (e) {
      _logger.severe('Error executing tool: $e');

      // Dismiss loading indicator
      if (mounted) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error executing tool: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Tools'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
        children: [
          // Tool list (left side)
          SizedBox(
            width: 200,
            child: _buildToolList(theme),
          ),

          // Vertical divider
          VerticalDivider(
            width: 1,
            color: theme.dividerColor,
          ),

          // Tool details (right side)
          Expanded(
            child: _selectedTool != null
                ? _buildToolDetails(theme)
                : Center(
              child: Text(
                'Select a tool from the list',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build tool list
  Widget _buildToolList(ThemeData theme) {
    return ListView.builder(
      itemCount: _tools.length,
      itemBuilder: (context, index) {
        final tool = _tools[index];
        final isSelected = _selectedTool?.name == tool.name;

        return ListTile(
          title: Text(tool.name),
          subtitle: Text(
            tool.description ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          selected: isSelected,
          selectedTileColor: theme.colorScheme.primaryContainer.withOpacity(0.3),
          onTap: () => _selectTool(tool),
          leading: Icon(
            _getIconForTool(tool.name),
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        );
      },
    );
  }

  // Build tool details
  Widget _buildToolDetails(ThemeData theme) {
    if (_selectedTool == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tool name
          Text(
            _selectedTool!.name,
            style: theme.textTheme.titleLarge,
          ),

          // Tool description
          if (_selectedTool!.description != null) ...[
            const SizedBox(height: 8),
            Text(
              _selectedTool!.description!,
              style: theme.textTheme.bodyMedium,
            ),
          ],

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // Tool parameters
          Text(
            'Parameters',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),

          // Parameter inputs
          if (_paramControllers.isEmpty)
            const Text('This tool has no parameters'),

          for (final entry in _paramControllers.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextField(
                controller: entry.value,
                decoration: InputDecoration(
                  labelText: entry.key,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Execute button
          Center(
            child: FilledButton.icon(
              onPressed: _executeTool,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Execute Tool'),
            ),
          ),
        ],
      ),
    );
  }

  // Get icon for tool
  IconData _getIconForTool(String toolName) {
    // Common tool categories
    if (toolName.contains('search') || toolName.contains('find')) {
      return Icons.search;
    } else if (toolName.contains('document') || toolName.contains('file')) {
      return Icons.description;
    } else if (toolName.contains('create') || toolName.contains('add')) {
      return Icons.add_circle_outline;
    } else if (toolName.contains('delete') || toolName.contains('remove')) {
      return Icons.delete_outline;
    } else if (toolName.contains('update') || toolName.contains('edit')) {
      return Icons.edit;
    } else if (toolName.contains('list') || toolName.contains('get')) {
      return Icons.list;
    } else if (toolName.contains('chat') || toolName.contains('message')) {
      return Icons.chat_bubble_outline;
    } else if (toolName.contains('summarize') || toolName.contains('summary')) {
      return Icons.summarize;
    } else if (toolName.contains('question') || toolName.contains('answer')) {
      return Icons.question_answer;
    } else {
      return Icons.build; // Default tool icon
    }
  }
}