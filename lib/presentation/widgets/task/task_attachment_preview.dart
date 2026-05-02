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

  bool _isDisplayableImage(String mime) {
    return _displayableImageMimes.contains(mime);
  }

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
            height: 88,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return SizedBox(
            height: 88,
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
          height: 88,
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: url,
          httpHeaders: headers,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          progressIndicatorBuilder: (context, url, progress) => Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: progress.progress,
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
        title: Text(
          title,
          overflow: TextOverflow.ellipsis,
        ),
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
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          Icon(
            Icons.insert_drive_file_outlined,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.attachment.file.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          if (_isDownloading)
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.download_outlined),
              onPressed: _download,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 48,
                minHeight: 48,
              ),
            ),
        ],
      ),
    );
  }
}
