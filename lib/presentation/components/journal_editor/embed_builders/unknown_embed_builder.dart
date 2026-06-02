import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

// 自定义未知嵌入构建器
class UnknownEmbedBuilder extends EmbedBuilder {
  @override
  String get key => 'unknown';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: const Text('不支持的嵌入类型'),
    );
  }
}
