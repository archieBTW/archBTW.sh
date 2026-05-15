import 'package:archbtw_sh/generated/source_code.dart';
import 'package:archbtw_sh/pages/source_code/file_tree.dart';
import 'package:flutter/material.dart';
import 'package:archbtw_sh/widgets/selectable_highlight_view.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';

class SourceCodePage extends StatefulWidget {
  const SourceCodePage({super.key});

  @override
  State<SourceCodePage> createState() => _SourceCodePageState();
}

class _SourceCodePageState extends State<SourceCodePage> {
  String? _selectedFile = 'lib/main.dart';

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Widget _buildTopBar(bool isDesktop) {
    return Container(
      height: 40,
      color: const Color(0xFF0D0D0D),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white70, size: 20),
            onPressed: () {
              Navigator.pop(context); // Go back home
            },
            tooltip: 'Back to Home',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const Spacer(),
          const Text(
            'archBTW.sh',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 14,
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (!isDesktop)
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.white70, size: 20),
              onPressed: () {
                _scaffoldKey.currentState?.openDrawer();
              },
              tooltip: 'files',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            )
          else
            const SizedBox(width: 20),
        ],
      ),
    );
  }

  Widget _buildCodeViewer(String content, bool isDesktop) {
    final lines = content.split('\n');
    final double fontSize = isDesktop ? 14 : 11;

    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Line numbers
              SelectionContainer.disabled(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(lines.length, (index) {
                    return Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: fontSize,
                        color: Colors.white38,
                        height: 1.5,
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(width: 16),
              // Code
              SelectableHighlightView(
                content,
                language: 'dart',
                theme: {
                  ...atomOneDarkTheme,
                  'root': TextStyle(
                    backgroundColor: const Color(0xFF0D0D0D),
                    color:
                        atomOneDarkTheme['root']?.color ??
                        const Color(0xffabb2bf),
                  ),
                },
                padding: EdgeInsets.zero,
                textStyle: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: fontSize,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 768.0;

    final fileTreeWidget = FileTreeWidget(
      files: sourceCodeFiles,
      selectedFile: _selectedFile,
      onFileSelected: (path) {
        setState(() {
          _selectedFile = path;
        });
        if (!isDesktop) {
          Navigator.of(context).pop(); // Close drawer
        }
      },
    );

    final String? fileName = _selectedFile?.split('/').last;
    final content = _selectedFile != null
        ? sourceCodeFiles[_selectedFile!]
        : null;

    final codeViewerWidget = Container(
      color: const Color(0xFF0D0D0D), // Match sidebar background
      width: double.infinity,
      height: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (fileName != null)
            Container(
              color: const Color(0xFF0D0D0D),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0D0D0D), // Match the background
                      border: Border(
                        top: BorderSide(color: Colors.blueAccent, width: 2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          fileName,
                          style: const TextStyle(
                            fontFamily: 'JetBrainsMono',
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white54,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: content == null
                ? const Center(
                    child: Text(
                      'Select a file to view its source code.',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        color: Colors.white54,
                      ),
                    ),
                  )
                : _buildCodeViewer(content, isDesktop),
          ),
        ],
      ),
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF0D0D0D),
      drawer: isDesktop ? null : Drawer(child: fileTreeWidget),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(isDesktop),
            Expanded(
              child: isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 250, child: fileTreeWidget),
                        Expanded(child: codeViewerWidget),
                      ],
                    )
                  : codeViewerWidget,
            ),
          ],
        ),
      ),
    );
  }
}
