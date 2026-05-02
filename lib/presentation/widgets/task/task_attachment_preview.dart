import 'package:background_downloader/background_downloader.dart'
    show TaskStatus, FileDownloader;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/domain/entities/task_attachment.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';

class TaskAttachmentSection extends ConsumerStatefulWidget {
  final List<TaskAttachment> attachments;
  final int taskId;

  const TaskAttachmentSection({
    super.key,
    required this.attachments,
    required this.taskId,
  });

  @override
  ConsumerState<TaskAttachmentSection> createState() =>
      _TaskAttachmentSectionState();
}

class _TaskAttachmentSectionState extends ConsumerState<TaskAttachmentSection> {
  static const _displayableImageMimes = {
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'image/bmp',
  };

  late final Future<Map<String, String>> _headersFuture;

  @override
  void initState() {
    super.initState();
    _headersFuture = ref.read(clientProviderProvider).getHeaders();
  }

  bool _isDisplayableImage(String mime) =>
      _displayableImageMimes.contains(mime);

  @override
  Widget build(BuildContext context) {
    final images = <TaskAttachment>[];
    final files = <TaskAttachment>[];

    for (final attachment in widget.attachments) {
      if (_isDisplayableImage(attachment.file.mime)) {
        images.add(attachment);
      } else {
        files.add(attachment);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.isNotEmpty) _buildImageRow(images),
        if (images.isNotEmpty && files.isNotEmpty) const SizedBox(height: 12),
        if (files.isNotEmpty) _buildFileList(files),
      ],
    );
  }

  Widget _buildImageRow(List<TaskAttachment> images) {
    return FutureBuilder<Map<String, String>>(
      future: _headersFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 104,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return SizedBox(
            height: 104,
            child: Center(
              child: Text(
                AppLocalizations.of(context).imagesLoadFailed,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          );
        }

        final imageHeaders = Map<String, String>.from(snapshot.data!)
          ..remove('Content-Type');
        final client = ref.read(clientProviderProvider);

        return SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) => _AttachmentImageThumbnail(
              attachment: images[index],
              taskId: widget.taskId,
              headers: imageHeaders,
              apiBase: client.apiBase,
            ),
          ),
        );
      },
    );
  }

  Widget _buildFileList(List<TaskAttachment> files) {
    return Column(
      children: files
          .map((a) => _AttachmentFileTile(
                key: ValueKey(a.id),
                attachment: a,
                taskId: widget.taskId,
              ))
          .toList(),
    );
  }
}

// ─── Image thumbnail ──────────────────────────────────────────────────────────

class _AttachmentImageThumbnail extends StatelessWidget {
  final TaskAttachment attachment;
  final int taskId;
  final Map<String, String> headers;
  final String apiBase;

  const _AttachmentImageThumbnail({
    required this.attachment,
    required this.taskId,
    required this.headers,
    required this.apiBase,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = '$apiBase/tasks/$taskId/attachments/${attachment.id}';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _ImageViewerPage(
              imageUrl: url,
              title: attachment.file.name,
              headers: headers,
            ),
          ),
        );
      },
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: CachedNetworkImage(
            imageUrl: url,
            httpHeaders: headers,
            width: 100,
            height: 100,
            fit: BoxFit.cover,
            progressIndicatorBuilder: (context, url, progress) => Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: progress.progress,
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Full-screen image viewer ─────────────────────────────────────────────────

class _ImageViewerPage extends StatelessWidget {
  final String imageUrl;
  final String title;
  final Map<String, String> headers;

  const _ImageViewerPage({
    required this.imageUrl,
    required this.title,
    required this.headers,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, overflow: TextOverflow.ellipsis),
      ),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            httpHeaders: headers,
            fit: BoxFit.contain,
            progressIndicatorBuilder: (context, url, progress) => Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
                value: progress.progress,
              ),
            ),
            errorWidget: (context, url, error) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── File tile ────────────────────────────────────────────────────────────────

class _AttachmentFileTile extends ConsumerStatefulWidget {
  final TaskAttachment attachment;
  final int taskId;

  const _AttachmentFileTile({
    super.key,
    required this.attachment,
    required this.taskId,
  });

  @override
  ConsumerState<_AttachmentFileTile> createState() =>
      _AttachmentFileTileState();
}

class _AttachmentFileTileState extends ConsumerState<_AttachmentFileTile> {
  bool _isDownloading = false;

  Future<void> _download() async {
    setState(() => _isDownloading = true);
    try {
      final result = await ref.read(taskRepositoryProvider).downloadAttachment(
            widget.taskId,
            widget.attachment,
          );
      if (!mounted) return;
      if (result.status == TaskStatus.complete) {
        FileDownloader().openFile(task: result.task);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).downloadFailed),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mime = widget.attachment.file.mime;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            // File-type icon area
            Container(
              width: 48,
              height: 56,
              decoration: BoxDecoration(
                color: _iconColor(mime, theme).withValues(alpha: 0.12),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(9),
                  bottomLeft: Radius.circular(9),
                ),
              ),
              child: Icon(
                _fileIcon(mime),
                size: 22,
                color: _iconColor(mime, theme),
              ),
            ),
            const SizedBox(width: 12),
            // Name + size
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.attachment.file.name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatFileSize(widget.attachment.file.size),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Download button / spinner
            if (_isDownloading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.download_outlined),
                onPressed: _download,
                color: theme.colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }

  IconData _fileIcon(String mime) {
    if (mime == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (mime.startsWith('video/')) return Icons.videocam_outlined;
    if (mime.startsWith('audio/')) return Icons.audiotrack_outlined;
    if (mime.startsWith('image/')) return Icons.image_outlined;
    if (mime.contains('zip') || mime.contains('archive') || mime.contains('tar')) {
      return Icons.folder_zip_outlined;
    }
    if (mime.contains('word') || mime.contains('document')) {
      return Icons.description_outlined;
    }
    if (mime.contains('sheet') || mime.contains('excel')) {
      return Icons.table_chart_outlined;
    }
    if (mime.contains('presentation') || mime.contains('powerpoint')) {
      return Icons.slideshow_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  Color _iconColor(String mime, ThemeData theme) {
    if (mime == 'application/pdf') return Colors.red.shade600;
    if (mime.startsWith('video/')) return Colors.purple.shade600;
    if (mime.startsWith('audio/')) return Colors.orange.shade700;
    if (mime.startsWith('image/')) return Colors.blue.shade600;
    if (mime.contains('zip') || mime.contains('archive') || mime.contains('tar')) {
      return Colors.brown.shade600;
    }
    if (mime.contains('word') || mime.contains('document')) {
      return Colors.blue.shade700;
    }
    if (mime.contains('sheet') || mime.contains('excel')) {
      return Colors.green.shade700;
    }
    if (mime.contains('presentation') || mime.contains('powerpoint')) {
      return Colors.orange.shade600;
    }
    return theme.colorScheme.onSurfaceVariant;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
