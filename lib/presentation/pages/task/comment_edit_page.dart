import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:vikunja_app/domain/entities/task_comment.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/presentation/manager/task_comments_controller.dart';

class CommentEditPage extends ConsumerStatefulWidget {
  final int taskId;
  final TaskComment? comment;

  const CommentEditPage({super.key, required this.taskId, this.comment});

  @override
  ConsumerState<CommentEditPage> createState() => _CommentEditPageState();
}

class _CommentEditPageState extends ConsumerState<CommentEditPage> {
  late EditorState _editorState;
  bool _isSaving = false;

  bool get _isEditMode => widget.comment != null;

  @override
  void initState() {
    super.initState();
    _editorState = EditorState(document: _initialDocument(widget.comment?.comment));
  }

  Document _initialDocument(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return Document.blank(withInitialText: true);
    }
    try {
      return htmlToDocument(raw);
    } catch (e, st) {
      debugPrintStack(stackTrace: st, label: 'Failed to decode comment HTML');
      return Document.blank(withInitialText: true);
    }
  }

  @override
  void dispose() {
    _editorState.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;

    // Check if document is empty before saving state
    if (_isDocumentEmpty(_editorState.document)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).commentCannotBeEmpty),
          ),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    final html = documentToHTML(_editorState.document);

    final controller = ref.read(
      taskCommentsControllerProvider(widget.taskId).notifier,
    );

    final bool success;
    if (_isEditMode) {
      success = await controller.updateComment(widget.comment!, html);
    } else {
      success = await controller.addComment(html);
    }

    if (!mounted) return;

    if (success) {
      Navigator.pop(context, html);
    } else {
      setState(() => _isSaving = false);
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode ? l10n.commentUpdateError : l10n.commentAddError,
          ),
        ),
      );
    }
  }

  bool _isDocumentEmpty(Document doc) {
    for (final node in doc.root.children) {
      final text = node.delta?.toPlainText().trim() ?? '';
      if (text.isNotEmpty) return false;
      if (node.type != ParagraphBlockKeys.type) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? l10n.editCommentTitle : l10n.addCommentTitle),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            onPressed: !_isSaving ? _save : null,
          ),
        ],
      ),
      body: AppFlowyEditor(
        editorState: _editorState,
      ),
    );
  }
}
