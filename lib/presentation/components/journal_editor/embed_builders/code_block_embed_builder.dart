import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';

// 自定义代码块嵌入构建器
class CodeBlockEmbedBuilder extends EmbedBuilder {
  @override
  String get key => 'code-block';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final data = embedContext.node.value.data;
    String code = '';
    String language = 'text';

    if (data is String) {
      try {
        final map = jsonDecode(data);
        if (map is Map) {
          code = map['code'] ?? '';
          language = map['language'] ?? 'text';
        } else {
          code = data;
        }
      } catch (e) {
        code = data;
      }
    } else if (data is Map) {
      code = data['code'] ?? '';
      language = data['language'] ?? 'text';
    }

    // 去除首尾多余的空行，但保留代码内部的缩进
    code = code.trim();

    return CodeBlockWidget(
      code: code,
      language: language,
      embedContext: embedContext,
    );
  }
}

class CodeBlockWidget extends StatefulWidget {
  final String code;
  final String language;
  final EmbedContext embedContext;

  const CodeBlockWidget({
    super.key,
    required this.code,
    required this.language,
    required this.embedContext,
  });

  @override
  State<CodeBlockWidget> createState() => _CodeBlockWidgetState();
}

class _CodeBlockWidgetState extends State<CodeBlockWidget> {
  bool _isExpanded = true;

  // 显示编辑对话框
  void _showEditDialog() {
    final TextEditingController codeController =
        TextEditingController(text: widget.code);
    String selectedLanguage = widget.language;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('编辑代码块'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    value: selectedLanguage == 'plaintext'
                        ? 'text'
                        : selectedLanguage,
                    isExpanded: true,
                    items: [
                      'text',
                      'dart',
                      'python',
                      'javascript',
                      'java',
                      'cpp',
                      'c',
                      'html',
                      'css',
                      'sql',
                      'json',
                      'yaml',
                      'xml',
                      'markdown',
                      'shell'
                    ].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      if (newValue != null) {
                        setState(() {
                          selectedLanguage = newValue;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeController,
                    decoration: const InputDecoration(
                      hintText: '请输入代码...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 10,
                    minLines: 5,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  _saveCode(codeController.text, selectedLanguage);
                  Navigator.pop(context);
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
  }

  // 保存代码块
  void _saveCode(String newCode, String newLanguage) {
    debugPrint(
        'Saving code block: lang=$newLanguage, code length=${newCode.length}');
    final codeData = jsonEncode({
      'language': newLanguage,
      'code': newCode,
    });

    final document = widget.embedContext.controller.document;

    // --- Debug: Dump Document Structure ---
    debugPrint('--- Document Structure Dump ---');
    int dumpOffset = 0;
    void dumpNode(Node node, int depth) {
      String indent = '  ' * depth;
      if (node is Line) {
        debugPrint(
            '${indent}Line (start: $dumpOffset, length: ${node.length})');
        for (final child in node.children) {
          String info = '';
          if (child is Leaf) {
            info = 'Leaf: ${child.value.runtimeType}';
            if (child.value is Embeddable) {
              info +=
                  ' (Embed: ${(child.value as Embeddable).type}, Data: ${(child.value as Embeddable).data})';
            }
          } else {
            info = child.runtimeType.toString();
          }
          debugPrint('${indent}  - Child (len: ${child.length}): $info');
          dumpOffset += child.length;
        }
        dumpOffset += 1; // Newline
      } else if (node is Block) {
        debugPrint('${indent}Block (start: $dumpOffset)');
        for (final child in node.children) {
          dumpNode(child, depth + 1);
        }
      } else {
        debugPrint('${indent}Unknown Node: ${node.runtimeType}');
      }
    }

    for (final node in document.root.children) {
      dumpNode(node, 0);
    }
    debugPrint('--- End Dump ---');
    // --------------------------------------

    int foundOffset = -1;

    // Helper to check if a node is a code block
    bool isCodeBlockNode(Embeddable embed) {
      if (embed.type == 'code-block') return true;
      if (embed.type == 'custom') {
        dynamic data = embed.data;
        // Handle String data (JSON)
        if (data is String) {
          try {
            data = jsonDecode(data);
          } catch (e) {
            return false;
          }
        }

        if (data is Map) {
          final keys = data.keys.toList();
          // Check loosely for key
          return keys.any((k) => k.toString() == 'code-block');
        }
      }
      return false;
    }

    // Helper to check node equality
    bool isMatchingNode(Node node) {
      if (node == widget.embedContext.node) return true;

      if (node is Leaf) {
        final leafNode = node;
        final targetLeafNode = widget.embedContext.node as Leaf;
        final nodeValue = leafNode.value;
        final targetValue = targetLeafNode.value;
        if (nodeValue is Embeddable && targetValue is Embeddable) {
          if (isCodeBlockNode(nodeValue) && isCodeBlockNode(targetValue)) {
            // Extract data for comparison
            dynamic getNodeData(Embeddable e) {
              if (e.type == 'code-block') return e.data;
              if (e.type == 'custom') {
                dynamic data = e.data;
                if (data is String) {
                  try {
                    data = jsonDecode(data);
                  } catch (_) {}
                }

                if (data is Map) {
                  for (final k in data.keys) {
                    if (k.toString() == 'code-block') {
                      return data[k];
                    }
                  }
                }
              }
              return null;
            }

            dynamic nodeData = getNodeData(nodeValue);
            dynamic targetData = getNodeData(targetValue);

            // Normalize to Map
            Map<String, dynamic>? nodeMap;
            Map<String, dynamic>? targetMap;

            if (nodeData is String) {
              try {
                nodeMap = jsonDecode(nodeData);
              } catch (_) {}
            } else if (nodeData is Map) {
              nodeMap = Map<String, dynamic>.from(nodeData);
            }

            if (targetData is String) {
              try {
                targetMap = jsonDecode(targetData);
              } catch (_) {}
            } else if (targetData is Map) {
              targetMap = Map<String, dynamic>.from(targetData);
            }

            if (nodeMap != null && targetMap != null) {
              return nodeMap.toString() == targetMap.toString();
            }
            return nodeData == targetData;
          }
        }
      }
      return false;
    }

    // Search and Log
    int currentOffset = 0;

    void traverse(Node node) {
      if (node is Line) {
        for (final child in node.children) {
          if (child is Leaf && child.value is Embeddable) {
            final embed = child.value as Embeddable;
            // Debug check
            bool isCode = isCodeBlockNode(embed);
            if (isCode) {
              if (isMatchingNode(child)) {
                foundOffset = currentOffset;
              }
            }
          }

          if (foundOffset == -1 && isMatchingNode(child)) {
            foundOffset = currentOffset;
          }
          currentOffset += child.length;
        }
        // Line always ends with a newline in Quill document structure
        currentOffset += 1;
      } else if (node is Block) {
        for (final child in node.children) {
          traverse(child);
        }
      }
    }

    for (final node in document.root.children) {
      traverse(node);
    }

    // Fallback: Check selection
    if (foundOffset == -1) {
      try {
        final selection = widget.embedContext.controller.selection;
        if (selection.isCollapsed) {
          debugPrint('Checking selection at ${selection.start}');

          // Reset traversal to find closest
          currentOffset = 0;
          int closestOffset = -1;
          int minDistance = 999999;

          void findClosest(Node node) {
            if (node is Line) {
              for (final child in node.children) {
                if (child is Leaf && child.value is Embeddable) {
                  final embed = child.value as Embeddable;
                  // Debug check
                  bool isCode = isCodeBlockNode(embed);
                  if (isCode) {
                    int dist = (currentOffset - selection.start).abs();
                    // Also check if selection is just after it (currentOffset + 1 == selection.start)
                    if ((currentOffset + 1) == selection.start) dist = 0;

                    debugPrint(
                        'Fallback: Found code block at $currentOffset, dist=$dist');

                    if (dist < minDistance) {
                      minDistance = dist;
                      closestOffset = currentOffset;
                    }
                  }
                }
                currentOffset += child.length;
              }
              currentOffset += 1; // Correctly handle newline
            } else if (node is Block) {
              for (final child in node.children) findClosest(child);
            }
          }

          for (final node in document.root.children) {
            findClosest(node);
          }

          if (closestOffset != -1 && minDistance < 100) {
            // Increased threshold
            debugPrint(
                'Using closest code block at $closestOffset (dist=$minDistance)');
            foundOffset = closestOffset;
          }
        }
      } catch (e) {
        debugPrint('Error in fallback: $e');
      }
    }

    if (foundOffset != -1) {
      debugPrint('Found code block node at offset $foundOffset. Replacing...');
      widget.embedContext.controller.replaceText(
        foundOffset,
        1,
        BlockEmbed.custom(CustomBlockEmbed('code-block', codeData)),
        TextSelection.collapsed(offset: foundOffset + 1),
      );
    } else {
      debugPrint('ERROR: Code block node not found in document!');
    }
  }

  // 基本语法高亮
  TextSpan _highlightSyntax(String code, String language) {
    if (code.isEmpty) return const TextSpan(text: '');

    final spans = <TextSpan>[];

    // 定义不同语言的关键字
    final keywords = {
      'dart': [
        'void',
        'var',
        'final',
        'const',
        'class',
        'extends',
        'implements',
        'with',
        'if',
        'else',
        'for',
        'while',
        'do',
        'switch',
        'case',
        'break',
        'continue',
        'return',
        'try',
        'catch',
        'finally',
        'throw',
        'rethrow',
        'async',
        'await',
        'import',
        'export',
        'part',
        'as',
        'show',
        'hide',
        'typedef',
        'enum',
        'true',
        'false',
        'null',
        'new',
        'this',
        'super',
        'in',
        'is'
      ],
      'python': [
        'def',
        'class',
        'if',
        'else',
        'elif',
        'for',
        'while',
        'break',
        'continue',
        'return',
        'try',
        'except',
        'finally',
        'raise',
        'import',
        'from',
        'as',
        'with',
        'pass',
        'lambda',
        'and',
        'or',
        'not',
        'in',
        'is',
        'True',
        'False',
        'None',
        'global',
        'nonlocal',
        'assert',
        'del',
        'yield'
      ],
      'javascript': [
        'function',
        'const',
        'let',
        'var',
        'if',
        'else',
        'for',
        'while',
        'do',
        'switch',
        'case',
        'break',
        'continue',
        'return',
        'try',
        'catch',
        'finally',
        'throw',
        'import',
        'export',
        'default',
        'as',
        'async',
        'await',
        'class',
        'extends',
        'super',
        'new',
        'this',
        'true',
        'false',
        'null',
        'undefined',
        'typeof',
        'instanceof',
        'void',
        'delete'
      ],
      'java': [
        'public',
        'private',
        'protected',
        'static',
        'final',
        'class',
        'extends',
        'implements',
        'interface',
        'if',
        'else',
        'for',
        'while',
        'do',
        'switch',
        'case',
        'break',
        'continue',
        'return',
        'try',
        'catch',
        'finally',
        'throw',
        'throws',
        'import',
        'package',
        'new',
        'this',
        'super',
        'true',
        'false',
        'null',
        'void',
        'int',
        'double',
        'float',
        'boolean',
        'char',
        'byte',
        'short',
        'long'
      ],
      'cpp': [
        'void',
        'int',
        'double',
        'float',
        'bool',
        'char',
        'short',
        'long',
        'unsigned',
        'signed',
        'const',
        'static',
        'extern',
        'inline',
        'class',
        'struct',
        'union',
        'enum',
        'namespace',
        'using',
        'if',
        'else',
        'for',
        'while',
        'do',
        'switch',
        'case',
        'default',
        'break',
        'continue',
        'return',
        'try',
        'catch',
        'throw',
        'new',
        'delete',
        'this',
        'super',
        'true',
        'false',
        'nullptr',
        'typedef',
        'template',
        'typename',
        'virtual',
        'override',
        'final',
        'public',
        'private',
        'protected',
        'friend',
        'operator',
        'sizeof',
        'typeid',
        'constexpr',
        'const_cast',
        'static_cast',
        'dynamic_cast',
        'reinterpret_cast'
      ],
    };

    final langKeywords = keywords[language.toLowerCase()] ?? [];

    // 构建正则表达式 - 改进版本，支持多行匹配和更好的关键字识别
    String keywordPattern = langKeywords.isEmpty
        ? r'(?!x)x' // 匹配不到任何东西
        : '\\b(${langKeywords.join('|')})\\b';

    String commentPattern = r'//.*';
    if (language.toLowerCase() == 'python') {
      commentPattern = r'#.*';
    }

    // 改进的正则表达式，支持多行匹配
    final pattern = RegExp(
      '(".*?"|\'.*?\')|($commentPattern)|(\\b\\d+\\b)|($keywordPattern)',
      multiLine: true,
    );

    int currentIndex = 0;

    // 遍历所有匹配项
    for (final match in pattern.allMatches(code)) {
      // 添加匹配项之前的普通文本
      if (match.start > currentIndex) {
        spans.add(TextSpan(
          text: code.substring(currentIndex, match.start),
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'monospace',
            fontSize: 14,
          ),
        ));
      }

      final text = match.group(0)!;
      TextStyle style;

      if (match.group(1) != null) {
        // 字符串
        style = const TextStyle(
          color: Color(0xFF98C379), // Green
          fontFamily: 'monospace',
          fontSize: 14,
        );
      } else if (match.group(2) != null) {
        // 注释
        style = TextStyle(
          color: Colors.grey.shade500,
          fontStyle: FontStyle.italic,
          fontFamily: 'monospace',
          fontSize: 14,
        );
      } else if (match.group(3) != null) {
        // 数字
        style = const TextStyle(
          color: Color(0xFFD19A66), // Orange
          fontFamily: 'monospace',
          fontSize: 14,
        );
      } else if (match.group(4) != null) {
        // 关键字
        style = const TextStyle(
          color: Color(0xFF61AFEF), // Blue
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
          fontSize: 14,
        );
      } else {
        style = const TextStyle(
          color: Colors.white,
          fontFamily: 'monospace',
          fontSize: 14,
        );
      }

      spans.add(TextSpan(
        text: text,
        style: style,
      ));

      currentIndex = match.end;
    }

    // 添加剩余的文本
    if (currentIndex < code.length) {
      spans.add(TextSpan(
        text: code.substring(currentIndex),
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'monospace',
          fontSize: 14,
        ),
      ));
    }

    return TextSpan(children: spans);
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.code.split('\n');
    final lineCount = lines.length;

    return GestureDetector(
      onTap: _showEditDialog,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with collapse/expand functionality
            GestureDetector(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isExpanded
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_right,
                          color: Colors.grey.shade400,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.language.toUpperCase(),
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy,
                              size: 16, color: Colors.white),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: widget.code));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('代码已复制')),
                            );
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit,
                              size: 16, color: Colors.white),
                          onPressed: _showEditDialog,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Code Content with line numbers and syntax highlighting
            if (_isExpanded)
              Container(
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Line Numbers
                      Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: Colors.grey.shade700,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (var i = 1; i <= lineCount; i++)
                              Text(
                                '$i',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Code with syntax highlighting
                      RichText(
                        text: _highlightSyntax(widget.code, widget.language),
                        textAlign: TextAlign.left,
                        softWrap: true,
                        textDirection: TextDirection.ltr,
                        textScaler: const TextScaler.linear(1.0),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
