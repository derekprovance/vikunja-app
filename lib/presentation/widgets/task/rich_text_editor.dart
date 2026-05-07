import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

class RichTextEditor extends StatelessWidget {
  const RichTextEditor({
    super.key,
    required this.editorState,
    required this.editorScrollController,
  });

  final EditorState editorState;
  final EditorScrollController editorScrollController;

  @override
  Widget build(BuildContext context) {
    return MobileToolbarV2(
      editorState: editorState,
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
              editorState: editorState,
              editorScrollController: editorScrollController,
              floatingToolbarHeight: 32,
              toolbarBuilder: (context, anchor, closeToolbar) {
                return AdaptiveTextSelectionToolbar.editable(
                  // Hardcoded: always enabled; pasting with empty clipboard is harmless.
                  clipboardStatus: ClipboardStatus.pasteable,
                  onCopy: () {
                    copyCommand.execute(editorState);
                    closeToolbar();
                  },
                  onCut: () {
                    cutCommand.execute(editorState);
                    closeToolbar();
                  },
                  onPaste: () {
                    pasteCommand.execute(editorState);
                    closeToolbar();
                  },
                  onSelectAll: () => selectAllCommand.execute(editorState),
                  onLiveTextInput: null,
                  onLookUp: null,
                  onSearchWeb: null,
                  onShare: null,
                  anchors: TextSelectionToolbarAnchors(primaryAnchor: anchor),
                );
              },
              child: AppFlowyEditor(
                editorState: editorState,
                editorScrollController: editorScrollController,
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
    );
  }
}
