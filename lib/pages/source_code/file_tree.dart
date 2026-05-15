import 'package:flutter/material.dart';

class FileNode {
  final String name;
  final String? fullPath;
  final List<FileNode> children;

  FileNode({required this.name, this.fullPath, List<FileNode>? children})
      : children = children ?? [];

  bool get isFile => fullPath != null;
}

class FileTreeWidget extends StatelessWidget {
  final Map<String, String> files;
  final String? selectedFile;
  final ValueChanged<String> onFileSelected;

  const FileTreeWidget({
    super.key,
    required this.files,
    this.selectedFile,
    required this.onFileSelected,
  });

  FileNode _buildTree() {
    final root = FileNode(name: 'archbtw.sh');
    final libNode = FileNode(name: 'lib');
    root.children.add(libNode);

    for (final path in files.keys) {
      final cleanPath = path.startsWith('lib/') ? path.substring(4) : path;
      final parts = cleanPath.split('/');
      var current = libNode;
      for (var i = 0; i < parts.length; i++) {
        final part = parts[i];
        final isFile = i == parts.length - 1;

        var child = current.children.cast<FileNode?>().firstWhere(
            (n) => n!.name == part,
            orElse: () => null);
        if (child == null) {
          child = FileNode(
            name: part,
            fullPath: isFile ? path : null,
          );
          current.children.add(child);
        }
        current = child;
      }
    }
    
    _sortNode(libNode);
    return root;
  }

  void _sortNode(FileNode node) {
    node.children.sort((a, b) {
      if (a.isFile && !b.isFile) return 1;
      if (!a.isFile && b.isFile) return -1;
      return a.name.compareTo(b.name);
    });
    for (final child in node.children) {
      _sortNode(child);
    }
  }

  @override
  Widget build(BuildContext context) {
    final root = _buildTree();
    return Container(
      color: const Color(0xFF0D0D0D), // very dark background for sidebar
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'EXPLORER',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 11,
                color: Colors.white54,
                letterSpacing: 1.2,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _TreeNodeWidget(
                  node: root,
                  level: 0,
                  selectedFile: selectedFile,
                  onFileSelected: onFileSelected,
                  initiallyExpanded: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TreeNodeWidget extends StatefulWidget {
  final FileNode node;
  final int level;
  final String? selectedFile;
  final ValueChanged<String> onFileSelected;
  final bool initiallyExpanded;

  const _TreeNodeWidget({
    required this.node,
    required this.level,
    required this.selectedFile,
    required this.onFileSelected,
    this.initiallyExpanded = false,
  });

  @override
  State<_TreeNodeWidget> createState() => _TreeNodeWidgetState();
}

class _TreeNodeWidgetState extends State<_TreeNodeWidget> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded || widget.level <= 1;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.node.isFile) {
      final isSelected = widget.node.fullPath == widget.selectedFile;
      return InkWell(
        onTap: () => widget.onFileSelected(widget.node.fullPath!),
        child: Container(
          color: isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent,
          padding: EdgeInsets.only(left: 16.0 + (widget.level * 12.0), top: 4, bottom: 4, right: 8),
          child: Row(
            children: [
              const Icon(Icons.insert_drive_file, size: 14, color: Colors.white70),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.node.name,
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 13,
                    color: isSelected ? Colors.white : Colors.white70,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Container(
              padding: EdgeInsets.only(left: 8.0 + (widget.level * 12.0), top: 4, bottom: 4, right: 8),
              child: Row(
                children: [
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                    size: 16,
                    color: Colors.white54,
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.folder, size: 14, color: Color(0xFF9E75FF)), // purple folder
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.node.name,
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            ...widget.node.children.map((child) => _TreeNodeWidget(
                  node: child,
                  level: widget.level + 1,
                  selectedFile: widget.selectedFile,
                  onFileSelected: widget.onFileSelected,
                )),
        ],
      );
    }
  }
}
