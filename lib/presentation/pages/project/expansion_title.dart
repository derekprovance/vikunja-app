import 'package:flutter/material.dart';

class VikunjaExpansionTile extends StatelessWidget {
  final Widget title;
  final List<Widget> children;
  final GestureTapCallback? onTitleTap;
  final Widget? leading;

  const VikunjaExpansionTile({
    super.key,
    required this.title,
    required this.children,
    this.onTitleTap,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: leading,
      title: onTitleTap == null
          ? title
          : InkWell(
              onTap: onTitleTap,
              child: title,
            ),
      shape: const Border(),
      collapsedShape: const Border(),
      childrenPadding: const EdgeInsetsDirectional.only(start: 16),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      children: children,
    );
  }
}
