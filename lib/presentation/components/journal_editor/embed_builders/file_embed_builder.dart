import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:open_file/open_file.dart';

// 自定义文件附件嵌入构建器
class FileEmbedBuilder extends EmbedBuilder {
  @override
  String get key => 'file';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final nodeData = embedContext.node.value.data;

    // Parse file data from either JSON string or Map
    Map<String, dynamic> fileData = {};

    if (nodeData is String) {
      try {
        fileData = Map<String, dynamic>.from(jsonDecode(nodeData));
      } catch (e) {
        debugPrint('Failed to parse file data: $e');
        return const SizedBox();
      }
    } else if (nodeData is Map) {
      fileData = Map<String, dynamic>.from(nodeData);
    }

    final filePath = fileData['path'] as String? ?? '';
    final fileName = fileData['name'] as String? ?? 'Unknown File';
    final fileType = fileData['type'] as String? ?? '';

    return GestureDetector(
      onTap: () {
        if (filePath.isNotEmpty) {
          _openFile(filePath, fileType, fileName);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              _getFileIcon(fileType),
              color: _getFileColor(fileType),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    filePath,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: () {
                if (filePath.isNotEmpty) {
                  _openFile(filePath, fileType, fileName);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 打开文件，根据平台采用不同策略
  void _openFile(String filePath, String fileType, String fileName) {
    if (kIsWeb) {
      // Web平台：构建完整URL并在新标签页打开
      String fileUrl = filePath;
      if (!fileUrl.startsWith('http://') && !fileUrl.startsWith('https://')) {
        // 构建完整URL
        fileUrl = 'http://localhost:5000/uploads/$fileUrl';
      }
      // 在新标签页打开文件 - 使用 kIsWeb guard
      // For web, we'll just print a message since we can't use dart:html directly here
      debugPrint('Would open URL in web browser: $fileUrl');
    } else {
      // 其他平台：使用OpenFile打开
      OpenFile.open(filePath);
    }
  }

  IconData _getFileIcon(String fileType) {
    switch (fileType) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String fileType) {
    switch (fileType) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      case 'txt':
        return Colors.grey;
      case 'zip':
      case 'rar':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
