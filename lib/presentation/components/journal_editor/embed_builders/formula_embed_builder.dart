import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_math_fork/flutter_math.dart';

// 自定义公式嵌入构建器 - 支持实时 LaTeX 渲染
class FormulaEmbedBuilder extends EmbedBuilder {
  @override
  String get key => 'formula';

  // 编辑公式（带实时预览）
  void _editFormula(BuildContext context, EmbedContext embedContext) {
    if (embedContext.node.value is! CustomBlockEmbed) {
      return;
    }

    final CustomBlockEmbed embed = embedContext.node.value as CustomBlockEmbed;

    // 解析公式数据
    Map<String, dynamic> formulaData = {'latex': '', 'block': false};
    if (embed.data is String) {
      try {
        formulaData =
            jsonDecode(embed.data as String) as Map<String, dynamic>;
      } catch (_) {}
    }

    final String currentFormula = formulaData['latex'] ?? '';
    final bool isBlock = formulaData['block'] ?? false;

    final TextEditingController formulaController =
        TextEditingController(text: currentFormula);

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Text('编辑${isBlock ? '块级' : '行内'}公式'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: formulaController,
                    decoration: const InputDecoration(
                      hintText: r'例如: E = mc^2 或 \frac{a}{b}',
                      border: OutlineInputBorder(),
                      labelText: 'LaTeX 公式',
                    ),
                    maxLines: isBlock ? 4 : 2,
                    autofocus: true,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  // 实时预览区域
                  _buildPreviewArea(formulaController.text, isBlock),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  final updatedFormulaData = {
                    'id': formulaData['id'] ??
                        DateTime.now().millisecondsSinceEpoch.toString(),
                    'latex': formulaController.text,
                    'block': isBlock,
                  };

                  final updatedEmbed = CustomBlockEmbed(
                    'formula',
                    jsonEncode(updatedFormulaData),
                  );

                  embedContext.node.value = updatedEmbed;
                  Navigator.pop(dialogContext);
                },
                child: const Text('更新'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 构建实时预览区域
  static Widget _buildPreviewArea(String latex, bool isBlock) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F9FF),
        border: Border.all(color: const Color(0xFF90CAF9)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '预览',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF1976D2),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          if (latex.trim().isEmpty)
            const Text(
              '输入 LaTeX 公式后将在此处显示预览',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF90CAF9),
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Center(
              child: _renderMath(latex, isBlock ? 18.0 : 16.0),
            ),
        ],
      ),
    );
  }

  /// 安全地渲染 LaTeX，出错时显示红色错误消息
  static Widget _renderMath(String latex, double fontSize) {
    try {
      return Math.tex(
        latex,
        textStyle: TextStyle(fontSize: fontSize),
        mathStyle: MathStyle.display,
        onErrorFallback: (err) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                latex,
                style: TextStyle(
                  fontSize: fontSize,
                  fontStyle: FontStyle.italic,
                  fontFamily: 'monospace',
                  color: const Color(0xFFD32F2F),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '⚠ 语法错误: ${err.message}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFD32F2F),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      return Text(
        latex,
        style: TextStyle(
          fontSize: fontSize,
          fontStyle: FontStyle.italic,
          fontFamily: 'monospace',
          color: const Color(0xFFD32F2F),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    if (embedContext.node.value is! CustomBlockEmbed) {
      return Container();
    }

    final CustomBlockEmbed embed =
        embedContext.node.value as CustomBlockEmbed;

    // 解析公式数据
    String formula = '';
    bool isBlock = false;

    if (embed.data is String) {
      try {
        final Map<String, dynamic> formulaData =
            jsonDecode(embed.data as String) as Map<String, dynamic>;
        formula = formulaData['latex'] ?? '';
        isBlock = formulaData['block'] ?? false;
      } catch (_) {}
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _editFormula(context, embedContext);
        },
        borderRadius: BorderRadius.circular(isBlock ? 8 : 4),
        hoverColor: const Color(0x101E88E5),
        child: Container(
          padding: isBlock
              ? const EdgeInsets.all(16)
              : const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          margin: isBlock
              ? const EdgeInsets.symmetric(vertical: 8, horizontal: 0)
              : const EdgeInsets.symmetric(vertical: 0, horizontal: 2),
          decoration: BoxDecoration(
            color: isBlock
                ? const Color(0xFFF5F9FF)
                : const Color(0xFFEEF7FF),
            border: Border.all(
              color: isBlock
                  ? const Color(0xFF90CAF9)
                  : const Color(0xFF64B5F6),
              width: isBlock ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(isBlock ? 8 : 4),
            boxShadow: isBlock
                ? [
                    BoxShadow(
                      // ignore: deprecated_member_use
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: isBlock
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '公式',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1976D2),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Icon(
                          Icons.edit_outlined,
                          size: 14,
                          color: Color(0xFF64B5F6),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    formula.isEmpty
                        ? const Text(
                            '点击编辑公式',
                            style: TextStyle(
                              color: Color(0xFF64B5F6),
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        : _renderMath(formula, 18.0),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.functions,
                      size: 14,
                      color: Color(0xFF42A5F5),
                    ),
                    const SizedBox(width: 4),
                    formula.isEmpty
                        ? const Text(
                            '编辑公式',
                            style: TextStyle(
                              color: Color(0xFF42A5F5),
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        : _renderMath(formula, 14.0),
                  ],
                ),
        ),
      ),
    );
  }
}
