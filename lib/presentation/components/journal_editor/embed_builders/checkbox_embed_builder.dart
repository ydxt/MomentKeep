import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

// 自定义复选框嵌入构建器
class CheckboxEmbedBuilder extends EmbedBuilder {
  final Function(String id, bool isChecked) onToggle;

  CheckboxEmbedBuilder(this.onToggle);

  @override
  String get key => 'checkbox';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    var data = embedContext.node.value.data;
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (e) {
        return const SizedBox();
      }
    }

    if (data is! Map) return const SizedBox();

    final id = data['id'] as String;
    final isChecked = data['checked'] as bool;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          debugPrint('Checkbox tapped: $id, current: $isChecked');
          onToggle(id, isChecked);
        },
        child: Padding(
          padding: const EdgeInsets.only(right: 8, top: 2, bottom: 2),
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
            ],
          ),
        ),
      ),
    );
  }
}
