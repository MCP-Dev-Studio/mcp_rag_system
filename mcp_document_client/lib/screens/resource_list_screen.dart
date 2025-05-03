import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mcp_client/mcp_client.dart';

// Global service instance
import '../main.dart' show clientService;

/// Screen to display and interact with available MCP resources
class ResourceListScreen extends StatefulWidget {
  const ResourceListScreen({Key? key}) : super(key: key);

  @override
  State<ResourceListScreen> createState() => _ResourceListScreenState();
}

class _ResourceListScreenState extends State<ResourceListScreen> {
  final Logger _logger = Logger('ResourceListScreen');

  // State
  List<Resource> _resources = [];
  Resource? _selectedResource;
  bool _isLoading = true;
  String? _resourceContent;
  bool _isLoadingResource = false;

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  // Load available resources
  Future<void> _loadResources() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final resources = clientService.availableResources;

      setState(() {
        _resources = resources;
        _isLoading = false;
      });
    } catch (e) {
      _logger.error('Error loading resources: $e');

      setState(() {
        _resources = [];
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading resources: $e')),
        );
      }
    }
  }

  // Select a resource to view
  Future<void> _selectResource(Resource resource) async {
    setState(() {
      _selectedResource = resource;
      _resourceContent = null;
      _isLoadingResource = true;
    });

    try {
      // Load resource content
      final content = await clientService.readResource(resource.uri);

      setState(() {
        _resourceContent = content;
        _isLoadingResource = false;
      });
    } catch (e) {
      _logger.error('Error loading resource content: $e');

      setState(() {
        _resourceContent = null;
        _isLoadingResource = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading resource content: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Resources'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
        children: [
          // Resource list (left side)
          SizedBox(
            width: 200,
            child: _buildResourceList(theme),
          ),

          // Vertical divider
          VerticalDivider(
            width: 1,
            color: theme.dividerColor,
          ),

          // Resource details (right side)
          Expanded(
            child: _selectedResource != null
                ? _buildResourceDetails(theme)
                : Center(
              child: Text(
                'Select a resource from the list',
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

  // Build resource list
  Widget _buildResourceList(ThemeData theme) {
    return ListView.builder(
      itemCount: _resources.length,
      itemBuilder: (context, index) {
        final resource = _resources[index];
        final isSelected = _selectedResource?.uri == resource.uri;

        return ListTile(
          title: Text(resource.name),
          subtitle: Text(
            resource.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          selected: isSelected,
          selectedTileColor: theme.colorScheme.primaryContainer.withOpacity(0.3),
          onTap: () => _selectResource(resource),
          leading: Icon(
            _getIconForResource(resource),
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        );
      },
    );
  }

  // Build resource details
  Widget _buildResourceDetails(ThemeData theme) {
    if (_selectedResource == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resource name
          Text(
            _selectedResource!.name,
            style: theme.textTheme.titleLarge,
          ),

          // Resource description
          ...[
          const SizedBox(height: 8),
          Text(
            _selectedResource!.description,
            style: theme.textTheme.bodyMedium,
          ),
        ],

          // Resource URI
          const SizedBox(height: 8),
          Text(
            'URI: ${_selectedResource!.uri}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),

          // Resource MIME type
          if (_selectedResource!.mimeType != null) ...[
            const SizedBox(height: 4),
            Text(
              'MIME Type: ${_selectedResource!.mimeType}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // Resource content
          Text(
            'Content',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),

          if (_isLoadingResource)
            const Center(child: CircularProgressIndicator())
          else if (_resourceContent == null)
            Text(
              'Failed to load resource content',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            )
          else
            _buildResourceContentWidget(theme),
        ],
      ),
    );
  }

  // Build resource content widget based on MIME type
  Widget _buildResourceContentWidget(ThemeData theme) {
    if (_resourceContent == null) {
      return const SizedBox.shrink();
    }

    final mimeType = _selectedResource?.mimeType;

    // Markdown or text content
    if (mimeType == 'text/markdown' || mimeType?.startsWith('text/') == true) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SelectableText(
          _resourceContent!,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontFamily: 'monospace',
          ),
        ),
      );
    }

    // JSON content
    if (mimeType == 'application/json') {
      try {
        // Try to format JSON
        final jsonMap = Map<String, dynamic>.from(
          _resourceContent!.startsWith('{')
              ? Map<String, dynamic>.from(
            Map.castFrom(
              Map<String, dynamic>.from(
                (jsonDecode(_resourceContent!) as Map),
              ),
            ),
          )
              : {'content': _resourceContent},
        );

        final formattedJson = const JsonEncoder.withIndent('  ').convert(jsonMap);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            formattedJson,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
        );
      } catch (e) {
        // If JSON parsing fails, show as plain text
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            _resourceContent!,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
        );
      }
    }

    // Default content view
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        _resourceContent!,
        style: theme.textTheme.bodyMedium,
      ),
    );
  }

  // Get icon for resource
  IconData _getIconForResource(Resource resource) {
    final uri = resource.uri;
    final mimeType = resource.mimeType;

    // Check URI
    if (uri.startsWith('docs://')) {
      return Icons.description;
    } else if (uri.startsWith('system://')) {
      return Icons.settings;
    } else if (uri.startsWith('user://')) {
      return Icons.person;
    }

    // Check MIME type
    if (mimeType == 'text/markdown') {
      return Icons.article;
    } else if (mimeType == 'application/json') {
      return Icons.data_object;
    } else if (mimeType?.startsWith('text/') == true) {
      return Icons.text_snippet;
    } else if (mimeType?.startsWith('image/') == true) {
      return Icons.image;
    } else if (mimeType?.startsWith('audio/') == true) {
      return Icons.audio_file;
    } else if (mimeType?.startsWith('video/') == true) {
      return Icons.video_file;
    }

    // Default icon
    return Icons.insert_drive_file;
  }
}