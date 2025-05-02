import 'package:flutter/material.dart';
import 'package:mcp_llm/mcp_llm.dart';

/// Widget to display document information in a card
class DocumentCard extends StatelessWidget {
  final Document document;
  final VoidCallback onTap;

  const DocumentCard({
    Key? key,
    required this.document,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Extract metadata
    String? createdAt;
    String? updatedAt;
    String? author;
    List<String> tags = [];

    if (document.metadata.containsKey('created_at')) {
      final timestamp = document.metadata['created_at'] as String;
      try {
        final date = DateTime.parse(timestamp);
        createdAt = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      } catch (_) {
        createdAt = timestamp;
      }
    }

    if (document.metadata.containsKey('updated_at')) {
      final timestamp = document.metadata['updated_at'] as String;
      try {
        final date = DateTime.parse(timestamp);
        updatedAt = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      } catch (_) {
        updatedAt = timestamp;
      }
    }

    if (document.metadata.containsKey('author')) {
      author = document.metadata['author'] as String?;
    }

    if (document.metadata.containsKey('tags') && document.metadata['tags'] is List) {
      tags = (document.metadata['tags'] as List).map((tag) => tag.toString()).toList();
    }

    // Create preview of content
    final contentPreview = document.content.length > 150
        ? '${document.content.substring(0, 150)}...'
        : document.content;

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and ID
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      document.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Text(
                    document.id,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),

              // Metadata row
              Row(
                children: [
                  if (author != null) ...[
                    Icon(
                      Icons.person,
                      size: 16.0,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                    const SizedBox(width: 4.0),
                    Text(
                      author,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(width: 16.0),
                  ],
                  if (updatedAt != null) ...[
                    Icon(
                      Icons.update,
                      size: 16.0,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                    const SizedBox(width: 4.0),
                    Text(
                      updatedAt,
                      style: theme.textTheme.bodySmall,
                    ),
                  ] else if (createdAt != null) ...[
                    Icon(
                      Icons.calendar_today,
                      size: 16.0,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                    const SizedBox(width: 4.0),
                    Text(
                      createdAt,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8.0),

              // Tags
              if (tags.isNotEmpty)
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: tags.map((tag) => Chip(
                    label: Text(
                      tag,
                      style: theme.textTheme.labelSmall,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  )).toList(),
                ),
              if (tags.isNotEmpty)
                const SizedBox(height: 8.0),

              // Content preview
              Text(
                contentPreview,
                style: theme.textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}