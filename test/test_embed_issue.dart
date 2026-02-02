import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart';

void main() {
  // 测试日记内容分析
  testJournalContentAnalysis();
}

void testJournalContentAnalysis() {
  print('=== 测试日记内容分析 ===');
  
  // 模拟插入图片和绘图后的文档
  final initialDocument = QuillDocument.fromJson([
    {'insert': '测试文档\n'},
    {
      'insert': {
        'image': 'test_image.png'
      }
    },
    {'insert': '\n'},
    {
      'insert': {
        'custom': jsonEncode({
          'id': 'drawing_123',
          'points': [],
          'height': 300.0
        })
      }
    },
    {'insert': '\n'},
    {'insert': '一些文本\n'}
  ]);
  
  print('初始文档:');
  print(jsonEncode(initialDocument.toDelta().toJson()));
  print('');
  
  // 模拟输入中文后的文档（可能被IME破坏）
  final corruptedDocument = QuillDocument.fromJson([
    {'insert': '测试文档\n'},
    {
      'insert': {
        'image': 'test_image.png'
      }
    },
    {'insert': '\n'},
    {
      'insert': {
        'custom': 'OBJ'
      }
    },
    {'insert': '\n'},
    {'insert': '一些文本测试中文输入\n'}
  ]);
  
  print('输入中文后的文档（可能被破坏）:');
  print(jsonEncode(corruptedDocument.toDelta().toJson()));
  print('');
  
  // 分析文档差异
  analyzeDocumentDifference(initialDocument, corruptedDocument);
}

void analyzeDocumentDifference(QuillDocument initial, QuillDocument corrupted) {
  print('=== 文档差异分析 ===');
  
  final initialDelta = initial.toDelta();
  final corruptedDelta = corrupted.toDelta();
  
  print('初始文档操作数: ${initialDelta.length}');
  print('损坏文档操作数: ${corruptedDelta.length}');
  print('');
  
  // 遍历初始文档操作
  print('初始文档操作:');
  for (int i = 0; i < initialDelta.length; i++) {
    final op = initialDelta.toList()[i];
    print('操作 $i: ${jsonEncode(op.toJson())}');
  }
  print('');
  
  // 遍历损坏文档操作
  print('损坏文档操作:');
  for (int i = 0; i < corruptedDelta.length; i++) {
    final op = corruptedDelta.toList()[i];
    print('操作 $i: ${jsonEncode(op.toJson())}');
  }
  print('');
  
  // 检查嵌入数据
  print('=== 嵌入数据检查 ===');
  checkEmbedData(initialDelta, '初始文档');
  checkEmbedData(corruptedDelta, '损坏文档');
}

void checkEmbedData(Delta delta, String label) {
  print('$label 中的嵌入数据:');
  
  for (int i = 0; i < delta.length; i++) {
    final op = delta.toList()[i];
    if (op.data is Map) {
      final dataMap = op.data as Map;
      print('操作 $i 包含嵌入数据:');
      
      if (dataMap.containsKey('image')) {
        print('  图片嵌入: ${dataMap['image']}');
      }
      
      if (dataMap.containsKey('custom')) {
        final customData = dataMap['custom'];
        print('  自定义嵌入类型: ${customData.runtimeType}');
        print('  自定义嵌入值: $customData');
        
        if (customData is String) {
          try {
            final parsed = jsonDecode(customData);
            print('  解析后的自定义嵌入: ${jsonEncode(parsed)}');
          } catch (e) {
            print('  解析失败: $e');
          }
        }
      }
    }
  }
  print('');
}
