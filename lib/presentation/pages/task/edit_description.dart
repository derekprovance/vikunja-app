import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';

class EditDescription extends StatefulWidget {
  final String? initialText;

  const EditDescription({super.key, required this.initialText});

  @override
  EditDescriptionState createState() => EditDescriptionState();
}

class EditDescriptionState extends State<EditDescription> {
  late EditorState _editorState;

  @override
  void initState() {
    super.initState();
    final doc = (widget.initialText?.trim().isNotEmpty ?? false)
        ? AppFlowyEditorHTMLCodec().decode(widget.initialText!)
        : EditorState.blank().document;
    _editorState = EditorState(document: doc);
  }

  @override
  void dispose() {
    _editorState.dispose();
    super.dispose();
  }

  void _save() {
    final html = AppFlowyEditorHTMLCodec().encode(_editorState.document);
    if (!context.mounted) return;
    Navigator.pop(context, html);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).editDescriptionTitle),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _save,
          ),
        ],
      ),
      body: AppFlowyEditor(
        editorState: _editorState,
      ),
    );
  }
}
