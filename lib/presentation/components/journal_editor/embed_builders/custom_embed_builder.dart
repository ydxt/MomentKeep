
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

// 自定义嵌入构建器 - 处理所有custom类型的嵌入
class CustomEmbedBuilder extends EmbedBuilder {
  final Function(String id, bool isChecked) onCheckboxToggle;

  CustomEmbedBuilder(this.onCheckboxToggle);

  @override
  String get key => 'custom';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    var data = embedContext.node.value.data;

    // 解析嵌入数据，处理各种格式，包括被IME破坏的格式
    String? checkboxId;
    bool isChecked = false;
    bool isCheckbox = false;

    // 最简化的提取逻辑，确保只识别真正的复选框，严格过滤其他类型的嵌入
    if (data is Map) {
      // 处理map类型的数据
      if (data.containsKey('checkbox')) {
        // 直接的checkbox字段
        isCheckbox = true;
        checkboxId = DateTime.now().millisecondsSinceEpoch.toString();
        // 尝试从checkbox字段提取checked状态
        final checkboxData = data['checkbox'];
        if (checkboxData is Map && checkboxData.containsKey('checked')) {
          isChecked = checkboxData['checked'] as bool;
        } else if (checkboxData is bool) {
          isChecked = checkboxData;
        }
      } else if (data.containsKey('custom')) {
        // 处理custom字段，但只在它是复选框时
        final customData = data['custom'];
        if (customData is Map) {
          // 严格检查是否为真正的复选框格式，排除所有其他类型的嵌入
          if ((customData.containsKey('checkbox') || 
               (customData.containsKey('id') && 
                customData.containsKey('checked') && 
                !customData.containsKey('drawing') && 
                !customData.containsKey('points') && 
                !customData.containsKey('image') &&
                !customData.containsKey('audio') &&
                !customData.containsKey('video') &&
                !customData.containsKey('file')))) {
            // 真正的复选框格式
            isCheckbox = true;
            checkboxId = customData['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
            isChecked = customData['checked'] as bool;
          }
        } else if (customData is String) {
          // 检查字符串是否包含复选框特征，但不包含其他嵌入类型
          if ((customData.contains('checkbox') || (customData.contains('id') && customData.contains('checked'))) && 
              !customData.contains('drawing') && 
              !customData.contains('points') && 
              !customData.contains('image') &&
              !customData.contains('audio') &&
              !customData.contains('video') &&
              !customData.contains('file')) {
            isCheckbox = true;
            checkboxId = DateTime.now().millisecondsSinceEpoch.toString();
            isChecked = customData.contains('true');
          }
        }
      }
    } else if (data is String) {
      // 处理字符串类型的数据，包括被IME破坏的格式
      // 确保只处理真正的复选框，不是其他嵌入类型
      if ((data.contains('checkbox') || (data.contains('id') && data.contains('checked'))) && 
          !data.contains('drawing') && 
          !data.contains('points') && 
          !data.contains('image') &&
          !data.contains('audio') &&
          !data.contains('video') &&
          !data.contains('file')) {
        isCheckbox = true;
        checkboxId = DateTime.now().millisecondsSinceEpoch.toString();
        isChecked = data.contains('true');
      }
    }

    // 确保我们有一个有效的复选框
    if (isCheckbox && checkboxId != null) {
      // 渲染复选框
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            debugPrint(
                'Custom checkbox tapped: $checkboxId, current: $isChecked');
            onCheckboxToggle(checkboxId!, isChecked);
          },
          child: Padding(
            padding: const EdgeInsets.only(right: 12, top: 2, bottom: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: isChecked ? Colors.blue : Colors.grey.shade400,
                        width: 2),
                    color: isChecked ? Colors.blue : Colors.transparent,
                  ),
                  child: isChecked
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                // 添加一个额外的空格，确保与文本的距离足够
                const SizedBox(width: 2),
              ],
            ),
          ),
        ),
      );
    }

    // 其他类型的custom嵌入，返回SizedBox.shrink()，让其他嵌入构建器处理
    return const SizedBox.shrink();
  }

  // 构建未知嵌入的占位符
  Widget _buildUnknownEmbed() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: const Text('不支持的嵌入类型'),
    );
  }
}
