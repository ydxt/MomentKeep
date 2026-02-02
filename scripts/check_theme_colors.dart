import 'dart:io';
import 'package:path/path.dart' as path;

/// 检查所有页面文件中的硬编码颜色
void main() {
  // 要检查的硬编码颜色列表
  final List<String> hardcodedColors = [
    'Colors.black',
    'Colors.white',
    'Color(0xFF1a3525)',
    'Color(0xFF2a4532)',
    'Color(0xFF326744)',
    'Color(0xFF13ec5b)',
    'Color(0xFF92c9a4)',
    'Color(0xFFff6b6b)',
    'Color(0xFFffc107)',
  ];
  
  // 要检查的文件扩展名
  final List<String> extensions = ['.dart'];
  
  // 要检查的目录
  final String pagesDir = 'lib/presentation/pages';
  final String componentsDir = 'lib/presentation/components';
  
  print('开始检查硬编码颜色...');
  print('=' * 50);
  
  // 检查页面目录
  _checkDirectory(pagesDir, hardcodedColors, extensions);
  
  // 检查组件目录
  _checkDirectory(componentsDir, hardcodedColors, extensions);
  
  print('=' * 50);
  print('硬编码颜色检查完成！');
}

/// 检查目录中的文件
void _checkDirectory(String dirPath, List<String> hardcodedColors, List<String> extensions) {
  final Directory dir = Directory(dirPath);
  
  if (!dir.existsSync()) {
    print('目录不存在: $dirPath');
    return;
  }
  
  print('检查目录: $dirPath');
  
  // 遍历目录中的所有文件
  final List<FileSystemEntity> files = dir.listSync(recursive: true);
  
  for (final file in files) {
    if (file is File) {
      final String filePath = file.path;
      final String extension = path.extension(filePath);
      
      // 只检查指定扩展名的文件
      if (extensions.contains(extension)) {
        _checkFile(filePath, hardcodedColors);
      }
    }
  }
}

/// 检查文件中的硬编码颜色
void _checkFile(String filePath, List<String> hardcodedColors) {
  try {
    final File file = File(filePath);
    final String content = file.readAsStringSync();
    
    // 检查每个硬编码颜色
    for (final color in hardcodedColors) {
      if (content.contains(color)) {
        // 计算出现次数
        final int count = RegExp(color).allMatches(content).length;
        
        // 查找所有出现的行号
        final List<int> lineNumbers = [];
        final List<String> lines = content.split('\n');
        
        for (int i = 0; i < lines.length; i++) {
          if (lines[i].contains(color)) {
            lineNumbers.add(i + 1);
          }
        }
        
        print('文件: $filePath');
        print('  发现硬编码颜色: $color');
        print('  出现次数: $count');
        print('  行号: ${lineNumbers.join(', ')}');
        print('');
      }
    }
  } catch (e) {
    print('读取文件失败: $filePath, 错误: $e');
  }
}
