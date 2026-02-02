import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

// 自定义公式嵌入构建器 - 修复插入多个公式的问题
class FormulaEmbedBuilder extends EmbedBuilder {
  @override
  String get key => 'formula';

  // 编辑公式
  void _editFormula(BuildContext context, EmbedContext embedContext) {
    // 获取当前嵌入节点
    if (embedContext.node.value is! CustomBlockEmbed) {
      return;
    }
    
    final CustomBlockEmbed embed = embedContext.node.value as CustomBlockEmbed;
    
    // 解析公式数据
    Map<String, dynamic> formulaData = {'latex': '', 'block': false};
    if (embed.data is String) {
      try {
        formulaData = jsonDecode(embed.data as String) as Map<String, dynamic>;
      } catch (_) {
        // 解析失败时使用默认值
      }
    }
    
    final String currentFormula = formulaData['latex'] ?? '';
    final bool isBlock = formulaData['block'] ?? false;
    
    final TextEditingController formulaController = 
        TextEditingController(text: currentFormula);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('编辑${isBlock ? '块级' : '行内'}公式'),
        content: TextField(
          controller: formulaController,
          decoration: const InputDecoration(
            hintText: '例如: E = mc^2',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
                final updatedFormulaData = {
                  'id': formulaData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  'latex': formulaController.text,
                  'block': isBlock
                };

                // 直接修改当前嵌入节点的数据，避免替换操作
                // 这种方式更可靠，不会导致插入新节点
                final updatedEmbed = CustomBlockEmbed(
                  'formula',
                  jsonEncode(updatedFormulaData),
                );
                
                // 更新当前节点的值
                embedContext.node.value = updatedEmbed;
                
                Navigator.pop(context);
            },
            child: const Text('更新'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    // 获取当前嵌入节点
    if (embedContext.node.value is! CustomBlockEmbed) {
      return Container();
    }
    
    final CustomBlockEmbed embed = embedContext.node.value as CustomBlockEmbed;
    
    // 解析公式数据
    String formula = '';
    bool isBlock = false;
    
    if (embed.data is String) {
      try {
        final Map<String, dynamic> formulaData = jsonDecode(embed.data as String) as Map<String, dynamic>;
        formula = formulaData['latex'] ?? '';
        isBlock = formulaData['block'] ?? false;
      } catch (_) {
        // 解析失败时使用默认值
      }
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
                        Text(
                          '公式',
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF1976D2),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Icon(
                          Icons.edit_outlined,
                          size: 14,
                          color: const Color(0xFF64B5F6),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formula.isEmpty ? '点击编辑公式' : formula,
                      style: TextStyle(
                        color: formula.isEmpty 
                            ? const Color(0xFF64B5F6)
                            : const Color(0xFF1A237E),
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        fontFamily: 'Serif',
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.functions,
                      size: 14,
                      color: const Color(0xFF42A5F5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formula.isEmpty ? '编辑公式' : formula,
                      style: TextStyle(
                        color: formula.isEmpty 
                            ? const Color(0xFF42A5F5)
                            : const Color(0xFF1565C0),
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        fontFamily: 'Serif',
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
