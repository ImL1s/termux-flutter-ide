import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FindReplaceBar extends ConsumerStatefulWidget {
  final CodeController controller;
  final VoidCallback onClose;

  const FindReplaceBar({
    super.key,
    required this.controller,
    required this.onClose,
  });

  @override
  ConsumerState<FindReplaceBar> createState() => _FindReplaceBarState();
}

class _FindReplaceBarState extends ConsumerState<FindReplaceBar> {
  final TextEditingController _findController = TextEditingController();
  final TextEditingController _replaceController = TextEditingController();
  final FocusNode _findFocusNode = FocusNode();

  List<int> _matchOffsets = [];
  int _currentMatchIndex = -1;
  bool _showReplace = false;
  bool _caseSensitive = false;

  @override
  void initState() {
    super.initState();
    _findFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _findController.dispose();
    _replaceController.dispose();
    _findFocusNode.dispose();
    super.dispose();
  }

  void _search() {
    final query = _findController.text;
    if (query.isEmpty) {
      setState(() {
        _matchOffsets = [];
        _currentMatchIndex = -1;
      });
      return;
    }

    final text = widget.controller.text;
    final pattern = _caseSensitive ? query : query.toLowerCase();
    final searchText = _caseSensitive ? text : text.toLowerCase();

    final List<int> offsets = [];
    int start = 0;
    while (true) {
      final index = searchText.indexOf(pattern, start);
      if (index == -1) break;
      offsets.add(index);
      start = index + 1;
    }

    setState(() {
      _matchOffsets = offsets;
      _currentMatchIndex = offsets.isEmpty ? -1 : 0;
    });

    if (_matchOffsets.isNotEmpty) {
      _goToMatch(_currentMatchIndex);
    }
  }

  void _goToMatch(int index) {
    if (index < 0 || index >= _matchOffsets.length) return;

    final offset = _matchOffsets[index];
    final query = _findController.text;

    widget.controller.selection = TextSelection(
      baseOffset: offset,
      extentOffset: offset + query.length,
    );

    setState(() {
      _currentMatchIndex = index;
    });
  }

  void _findNext() {
    if (_matchOffsets.isEmpty) return;
    final nextIndex = (_currentMatchIndex + 1) % _matchOffsets.length;
    _goToMatch(nextIndex);
  }

  void _findPrevious() {
    if (_matchOffsets.isEmpty) return;
    final prevIndex =
        (_currentMatchIndex - 1 + _matchOffsets.length) % _matchOffsets.length;
    _goToMatch(prevIndex);
  }

  void _replaceCurrent() {
    if (_currentMatchIndex < 0 || _currentMatchIndex >= _matchOffsets.length) {
      return;
    }

    final offset = _matchOffsets[_currentMatchIndex];
    final query = _findController.text;
    final replacement = _replaceController.text;

    final text = widget.controller.text;
    final newText =
        text.replaceRange(offset, offset + query.length, replacement);
    widget.controller.text = newText;

    // Re-search to update offsets
    _search();
  }

  void _replaceAll() {
    final query = _findController.text;
    final replacement = _replaceController.text;
    if (query.isEmpty) return;

    final text = widget.controller.text;
    final pattern = _caseSensitive
        ? query
        : RegExp(RegExp.escape(query), caseSensitive: false);
    final newText = text.replaceAll(pattern, replacement);
    widget.controller.text = newText;

    setState(() {
      _matchOffsets = [];
      _currentMatchIndex = -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1E2E),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Find Row
          Row(
            children: [
              // Toggle Replace
              IconButton(
                icon: Icon(
                  _showReplace ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                ),
                onPressed: () => setState(() => _showReplace = !_showReplace),
                tooltip: 'Toggle Replace',
              ),
              // Find Input
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _findController,
                    focusNode: _findFocusNode,
                    decoration: InputDecoration(
                      hintText: '搜尋...',
                      hintStyle:
                          const TextStyle(color: Colors.grey, fontSize: 14),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(color: Color(0xFF45475A)),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF313244),
                    ),
                    style: const TextStyle(fontSize: 14),
                    onChanged: (_) => _search(),
                    onSubmitted: (_) => _findNext(),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Match Count
              if (_matchOffsets.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '${_currentMatchIndex + 1}/${_matchOffsets.length}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              // Previous
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                onPressed: _findPrevious,
                tooltip: '上一個',
              ),
              // Next
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                onPressed: _findNext,
                tooltip: '下一個',
              ),
              // Case Sensitive Toggle
              IconButton(
                icon: Icon(
                  Icons.text_fields,
                  size: 20,
                  color: _caseSensitive ? const Color(0xFFCBA6F7) : Colors.grey,
                ),
                onPressed: () {
                  setState(() => _caseSensitive = !_caseSensitive);
                  _search();
                },
                tooltip: '區分大小寫',
              ),
              // Close
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: widget.onClose,
                tooltip: '關閉',
              ),
            ],
          ),
          // Replace Row
          if (_showReplace)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const SizedBox(width: 40), // Align with find input
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: TextField(
                        controller: _replaceController,
                        decoration: InputDecoration(
                          hintText: '取代...',
                          hintStyle:
                              const TextStyle(color: Colors.grey, fontSize: 14),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide:
                                const BorderSide(color: Color(0xFF45475A)),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF313244),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Replace Single
                  TextButton(
                    onPressed: _replaceCurrent,
                    child: const Text('取代', style: TextStyle(fontSize: 12)),
                  ),
                  // Replace All
                  TextButton(
                    onPressed: _replaceAll,
                    child: const Text('全部取代', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
