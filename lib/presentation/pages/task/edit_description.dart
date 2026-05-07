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
  late EditorScrollController _editorScrollController;

  @override
  void initState() {
    super.initState();
    _editorState = EditorState(document: _initialDocument(widget.initialText));
    _editorScrollController = EditorScrollController(
      editorState: _editorState,
      shrinkWrap: false,
    );
  }

  Document _initialDocument(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return Document.blank(withInitialText: true);
    }
    try {
      return htmlToDocument(raw);
    } catch (e, st) {
      debugPrintStack(stackTrace: st, label: 'Failed to decode task description HTML');
      return Document.blank(withInitialText: true);
    }
  }

  @override
  void dispose() {
    _editorState.dispose();
    _editorScrollController.dispose();
    super.dispose();
  }

  void _save() {
    final html = documentToHTML(_editorState.document);
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
      body: MobileToolbarV2(
        editorState: _editorState,
        toolbarItems: [
          textDecorationMobileToolbarItemV2,
          buildTextAndBackgroundColorMobileToolbarItem(),
          blocksMobileToolbarItem,
          linkMobileToolbarItem,
          dividerMobileToolbarItem,
        ],
        child: Column(
          children: [
            Expanded(
              child: MobileFloatingToolbar(
                editorState: _editorState,
                editorScrollController: _editorScrollController,
                floatingToolbarHeight: 32,
                toolbarBuilder: (context, anchor, closeToolbar) {
                  return AdaptiveTextSelectionToolbar.editable(
                    clipboardStatus: ClipboardStatus.pasteable,
                    onCopy: () {
                      copyCommand.execute(_editorState);
                      closeToolbar();
                    },
                    onCut: () => cutCommand.execute(_editorState),
                    onPaste: () => pasteCommand.execute(_editorState),
                    onSelectAll: () => selectAllCommand.execute(_editorState),
                    onLiveTextInput: null,
                    onLookUp: null,
                    onSearchWeb: null,
                    onShare: null,
                    anchors: TextSelectionToolbarAnchors(primaryAnchor: anchor),
                  );
                },
                child: AppFlowyEditor(
                  editorState: _editorState,
                  editorScrollController: _editorScrollController,
                  editorStyle: EditorStyle.mobile(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  ),
                  blockComponentBuilders: standardBlockComponentBuilderMap,
                  showMagnifier: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
