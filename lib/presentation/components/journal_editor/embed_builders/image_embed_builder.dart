import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:path/path.dart' as path_package;
import 'package:path_provider/path_provider.dart';

/// 自定义图片嵌入构建器，支持图片大小调整，避免崩溃
class CustomImageEmbedBuilder extends EmbedBuilder {
  @override
  String get key => 'image';

  /// 从复杂数据结构中提取图片路径，处理各种可能的格式
  String? _extractImagePathFromData(dynamic data) {
    if (data is Map) {
      // 直接查找image字段
      if (data.containsKey('image')) {
        final imageValue = data['image'];
        if (imageValue is String) {
          // 检查字符串是否为 "OBJ" 或其他无效值
          if (imageValue != 'OBJ' && imageValue.isNotEmpty) {
            return imageValue;
          }
        } else if (imageValue is Map && imageValue.containsKey('path')) {
          final pathValue = imageValue['path'] as String;
          // 检查路径是否为 "OBJ" 或其他无效值
          if (pathValue != 'OBJ' && pathValue.isNotEmpty) {
            return pathValue;
          }
        }
      }
      
      // 查找custom字段
      if (data.containsKey('custom')) {
        final customValue = data['custom'];
        if (customValue is String) {
          // 检查字符串是否为 "OBJ" 或其他无效值
          if (customValue != 'OBJ' && customValue.isNotEmpty) {
            // 尝试解析custom字符串
            try {
              final customMap = _safeJsonDecode(customValue);
              if (customMap != null) {
                return _extractImagePathFromData(customMap);
              }
            } catch (e) {
              // 如果解析失败，检查字符串是否包含图片路径特征
              if (customValue.contains('.png') || customValue.contains('.jpg') || customValue.contains('.jpeg') || customValue.contains('.gif')) {
                return customValue;
              }
            }
          }
        } else if (customValue is Map) {
          return _extractImagePathFromData(customValue);
        }
      }
      
      // 遍历所有键值对，寻找可能的图片路径
      for (final entry in data.entries) {
        final value = entry.value;
        if (value is String) {
          // 检查字符串是否为 "OBJ" 或其他无效值
          if (value != 'OBJ' && value.isNotEmpty) {
            // 检查字符串是否看起来像图片路径
            if ((value.contains('.png') || value.contains('.jpg') || value.contains('.jpeg') || value.contains('.gif')) && 
                !value.contains('ImageWithResizeHandles')) {
              return value;
            }
          }
        } else if (value is Map) {
          final foundPath = _extractImagePathFromData(value);
          if (foundPath != null) {
            return foundPath;
          }
        }
      }
    }
    return null;
  }

  /// 从节点中提取路径，处理各种边缘情况
  String _extractPathFromNode(dynamic node) {
    try {
      // 尝试获取节点的原始数据
      if (node is dynamic && node.value != null && node.value.data != null) {
        final data = node.value.data;
        if (data is String) {
          // 检查字符串是否为 "OBJ" 或其他无效值
          if (data == 'OBJ' || data.isEmpty) {
            return '';
          }
          return data;
        } else if (data is Map) {
          final foundPath = _extractImagePathFromData(data);
          if (foundPath != null) {
            return foundPath;
          }
        } else if (data is CustomBlockEmbed) {
          final customData = data.data;
          if (customData is String) {
            // 检查字符串是否为 "OBJ" 或其他无效值
            if (customData == 'OBJ' || customData.isEmpty) {
              return '';
            }
            return customData;
          } else if (customData is Map) {
            final foundPath = _extractImagePathFromData(customData);
            if (foundPath != null) {
              return foundPath;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error extracting path from node: $e');
    }
    return '';
  }
  
  /// 从节点中恢复图片路径
  /// 作为备用方法，用于处理解析失败的情况
  String _recoverImagePathFromNode(Node node) {
    // 尝试从节点的原始数据中恢复图片路径
    try {
      // 尝试使用动态访问获取节点的原始数据
      dynamic dynamicNode = node;
      try {
        // 尝试获取节点的value属性
        dynamic nodeValue = dynamicNode.value;
        if (nodeValue != null) {
          // 尝试获取data属性
          dynamic embedData = nodeValue.data;
          if (embedData != null) {
            // 尝试从embedData中提取图片路径
            if (embedData is Map) {
              final foundPath = _extractImagePathFromData(embedData);
              if (foundPath != null && foundPath != 'OBJ') {
                return foundPath;
              }
            } else if (embedData is String && embedData != 'OBJ') {
              // 尝试解析字符串数据
              final map = _safeJsonDecode(embedData);
              if (map != null) {
                final foundPath = _extractImagePathFromData(map);
                if (foundPath != null) {
                  return foundPath;
                }
              }
              // 如果解析失败，直接返回字符串（可能是路径）
              if (embedData.contains('.png') || embedData.contains('.jpg') || embedData.contains('.jpeg')) {
                return embedData;
              }
            }
          }
        }
      } catch (e) {
        // 如果获取失败，尝试其他方式
        debugPrint('Error recovering image path from node: $e');
      }
    } catch (e) {
      debugPrint('Error in _recoverImagePathFromNode: $e');
    }
    return '';
  }

  /// 安全的JSON解析，避免解析失败导致崩溃
  Map<String, dynamic>? _safeJsonDecode(String jsonString) {
    try {
      final decoded = json.decode(jsonString);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (e) {
      debugPrint('Error parsing JSON: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final nodeValue = embedContext.node.value.data;
    String imagePath = '';

    // 调试信息：打印nodeValue的类型和值
    debugPrint('CustomImageEmbedBuilder: nodeValue type: ${nodeValue.runtimeType}, value: $nodeValue');
    
    // 增强的嵌入数据处理逻辑，专门处理被IME破坏的格式
    try {
      if (nodeValue is String) {
        // 直接使用字符串作为图像路径（Quill编辑器保存的是文件名）
        // 检查字符串是否为 "OBJ" 或其他无效值
          if (nodeValue == 'OBJ' || nodeValue.isEmpty) {
            debugPrint('CustomImageEmbedBuilder: Invalid string path: $nodeValue');
            // 尝试从节点中提取路径
            imagePath = _extractPathFromNode(embedContext.node);
            // 如果提取失败，尝试恢复图片路径
            if (imagePath.isEmpty) {
              imagePath = _recoverImagePathFromNode(embedContext.node);
              debugPrint('CustomImageEmbedBuilder: Recovered path from node: $imagePath');
            }
          } else {
            imagePath = nodeValue;
            debugPrint('CustomImageEmbedBuilder: Using string path: $imagePath');
          }
      } else if (nodeValue is Map) {
        // 处理可能的复杂数据结构，包括被IME破坏的格式
        debugPrint('CustomImageEmbedBuilder: Processing Map nodeValue: $nodeValue');
        
        // 增强的路径提取逻辑
        String? foundPath = _extractImagePathFromData(nodeValue);
        
        // 如果找到有效的路径，则使用它，否则将imagePath设为空
        imagePath = foundPath ?? '';
        debugPrint('CustomImageEmbedBuilder: Final path from Map: $imagePath');
      } else if (nodeValue is CustomBlockEmbed) {
        // 处理CustomBlockEmbed类型
        debugPrint('CustomImageEmbedBuilder: Handling CustomBlockEmbed data');
        final customData = nodeValue.data;
        if (customData is String) {
          // 检查字符串是否为 "OBJ" 或其他无效值
          if (customData == 'OBJ' || customData.isEmpty) {
            debugPrint('CustomImageEmbedBuilder: Invalid CustomBlockEmbed string: $customData');
            // 尝试从节点中提取路径
            imagePath = _extractPathFromNode(embedContext.node);
            // 如果提取失败，尝试恢复图片路径
            if (imagePath.isEmpty) {
              imagePath = _recoverImagePathFromNode(embedContext.node);
              debugPrint('CustomImageEmbedBuilder: Recovered path from node: $imagePath');
            }
          } else {
            imagePath = customData;
            debugPrint('CustomImageEmbedBuilder: Using string path from CustomBlockEmbed: $imagePath');
          }
        } else if (customData is Map) {
          // 增强的路径提取逻辑
          String? foundPath = _extractImagePathFromData(customData);
          
          // 如果找到有效的路径，则使用它，否则将imagePath设为空
          imagePath = foundPath ?? '';
          debugPrint('CustomImageEmbedBuilder: Final path from CustomBlockEmbed Map: $imagePath');
        } else {
          // 处理其他类型的customData
          debugPrint('CustomImageEmbedBuilder: CustomBlockEmbed data is other type: ${customData.runtimeType}');
          // 尝试从节点中提取路径
          imagePath = _extractPathFromNode(embedContext.node);
          // 如果提取失败，尝试恢复图片路径
          if (imagePath.isEmpty) {
            imagePath = _recoverImagePathFromNode(embedContext.node);
            debugPrint('CustomImageEmbedBuilder: Recovered path from node: $imagePath');
          }
        }
      } else if (nodeValue is BlockEmbed) {
        // 处理BlockEmbed类型
        debugPrint('CustomImageEmbedBuilder: Handling BlockEmbed data');
        final embedData = nodeValue.data;
        if (embedData is String) {
          // 检查字符串是否为 "OBJ" 或其他无效值
          if (embedData == 'OBJ' || embedData.isEmpty) {
            debugPrint('CustomImageEmbedBuilder: Invalid BlockEmbed string: $embedData');
            // 尝试从节点中提取路径
            imagePath = _extractPathFromNode(embedContext.node);
            // 如果提取失败，尝试恢复图片路径
            if (imagePath.isEmpty) {
              imagePath = _recoverImagePathFromNode(embedContext.node);
              debugPrint('CustomImageEmbedBuilder: Recovered path from node: $imagePath');
            }
          } else {
            imagePath = embedData;
            debugPrint('CustomImageEmbedBuilder: Using string path from BlockEmbed: $imagePath');
          }
        } else if (embedData is Map) {
          // 增强的路径提取逻辑
          String? foundPath = _extractImagePathFromData(embedData);
          
          // 如果找到有效的路径，则使用它，否则将imagePath设为空
          imagePath = foundPath ?? '';
          debugPrint('CustomImageEmbedBuilder: Final path from BlockEmbed Map: $imagePath');
        } else {
          // 处理其他类型的embedData
          debugPrint('CustomImageEmbedBuilder: BlockEmbed data is other type: ${embedData.runtimeType}');
          // 尝试从节点中提取路径
          imagePath = _extractPathFromNode(embedContext.node);
          // 如果提取失败，尝试恢复图片路径
          if (imagePath.isEmpty) {
            imagePath = _recoverImagePathFromNode(embedContext.node);
            debugPrint('CustomImageEmbedBuilder: Recovered path from node: $imagePath');
          }
        }
      } else {
        // 处理其他类型的情况，尝试将其转换为字符串
        imagePath = nodeValue.toString();
        // 检查字符串是否为 "OBJ" 或其他无效值
        if (imagePath == 'OBJ' || imagePath.isEmpty) {
          debugPrint('CustomImageEmbedBuilder: Invalid toString path: $imagePath');
          // 尝试从节点中提取路径
          imagePath = _extractPathFromNode(embedContext.node);
          // 如果提取失败，尝试恢复图片路径
          if (imagePath.isEmpty) {
            imagePath = _recoverImagePathFromNode(embedContext.node);
            debugPrint('CustomImageEmbedBuilder: Recovered path from node: $imagePath');
          }
        } else {
          debugPrint('CustomImageEmbedBuilder: Using toString path: $imagePath');
        }
      }
    } catch (e) {
      debugPrint('CustomImageEmbedBuilder: Error processing nodeValue: $e');
      // 尝试从节点中提取路径
      imagePath = _extractPathFromNode(embedContext.node);
      // 如果提取失败，尝试恢复图片路径
      if (imagePath.isEmpty) {
        imagePath = _recoverImagePathFromNode(embedContext.node);
        debugPrint('CustomImageEmbedBuilder: Recovered path from node after error: $imagePath');
      }
    }
    
    // 检查图像路径是否有效，避免传递无效的路径
    if (imagePath.contains('ImageWithResizeHandles') || imagePath.contains('{') || imagePath.contains('}') || imagePath.isEmpty) {
      // 尝试从节点的原始数据中提取路径
      imagePath = _extractPathFromNode(embedContext.node);
      debugPrint('CustomImageEmbedBuilder: Extracted path from node: $imagePath');
      
      // 如果提取失败，尝试恢复图片路径
      if (imagePath.isEmpty) {
        imagePath = _recoverImagePathFromNode(embedContext.node);
        debugPrint('CustomImageEmbedBuilder: Recovered path from node: $imagePath');
      }
    }
    
    if (imagePath.isNotEmpty) {
      debugPrint('CustomImageEmbedBuilder: Valid path: $imagePath');
    } else {
      debugPrint('CustomImageEmbedBuilder: Invalid path: $imagePath');
    }

    // 使用支持大小调整的图片显示组件
    debugPrint('CustomImageEmbedBuilder: Creating ImageWithResizeHandles with path: $imagePath');
    return ImageWithResizeHandles(imagePath: imagePath);
  }
}

// 调整大小的手柄类型
enum ResizeHandle {
  none,
  // 角手柄
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  // 边手柄
  top,
  right,
  bottom,
  left,
}

/// 带有调整大小手柄的图片组件
class ImageWithResizeHandles extends StatefulWidget {
  final String imagePath;

  const ImageWithResizeHandles({super.key, required this.imagePath});

  @override
  State<ImageWithResizeHandles> createState() => _ImageWithResizeHandlesState();
}

/// 图片组件的实际实现，包含状态管理
class _ImageWithResizeHandlesState extends State<ImageWithResizeHandles> {
  String _fullImagePath = '';
  bool _isLoading = true;
  bool _hasError = false;
  
  // 图片尺寸状态
  double _width = 300;
  double _height = 200;
  
  // 调整大小的状态
  bool _isResizing = false;
  ResizeHandle _resizeHandle = ResizeHandle.none;
  Offset _resizeStartOffset = Offset.zero;
  
  // 最小和最大尺寸限制
  static const double _minWidth = 50;
  static const double _maxWidth = 1000;
  static const double _minHeight = 50;
  static const double _maxHeight = 800;

  @override
  void initState() {
    super.initState();
    _loadImagePath();
  }

  @override
  void didUpdateWidget(ImageWithResizeHandles oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当图片路径变化时，重新加载图片
    if (widget.imagePath != oldWidget.imagePath) {
      _fullImagePath = '';
      _isLoading = true;
      _hasError = false;
      _loadImagePath();
    }
  }

  Future<void> _loadImagePath() async {
    // 检查图片路径是否有效，避免尝试加载无效的URL
    if (widget.imagePath.contains('ImageWithResizeHandles')) {
      // 无效的图片路径，标记为错误
      _hasError = true;
      _isLoading = false;
      if (mounted) {
        setState(() {});
      }
      return;
    }

    if (widget.imagePath.startsWith('http')) {
      // 有效的网络图片，直接使用
      _fullImagePath = widget.imagePath;
      _isLoading = false;
      if (mounted) {
        setState(() {});
      }
      return;
    }

    if (kIsWeb) {
      // Web平台，处理图片路径
      // 对于web端，图片应该通过服务器访问
      try {
        // 检查图片路径是否有效，避免尝试加载无效的URL
        if (widget.imagePath.isNotEmpty) {
          // 清理路径中的换行符和空格
          final cleanedPath = widget.imagePath.trim();
          
          // 检查路径是否已经包含完整的URL
          if (cleanedPath.startsWith('http')) {
            // 路径已经是完整的URL，直接使用
            _fullImagePath = cleanedPath;
            debugPrint('Using full URL: $cleanedPath');
          } else {
            // 路径是相对路径，构建完整的URL
            final fullUrl = 'http://localhost:5000/uploads/$cleanedPath';
            
            // 调试信息
            debugPrint('Full image URL: $fullUrl');
            
            // 检查构建的URL是否包含无效内容
            if (fullUrl.contains('ImageWithResizeHandles')) {
              // 无效的图片URL，标记为错误
              _hasError = true;
              debugPrint('Invalid URL: contains ImageWithResizeHandles');
            } else {
              // 有效的图片URL，使用它
              _fullImagePath = fullUrl;
              debugPrint('Valid URL: $fullUrl');
            }
          }
        } else {
          // 无效的图片路径，标记为错误
          _hasError = true;
        }
      } catch (e) {
        // 处理可能的异常
        debugPrint('Error loading image path: $e');
        _hasError = true;
      } finally {
        // 无论如何，设置isLoading为false
        _isLoading = false;
        if (mounted) {
          setState(() {});
        }
      }
      return;
    }

    try {
      // 桌面平台，获取完整路径
      final appDir = await getApplicationDocumentsDirectory();
      final storageDir = Directory(path_package.join(appDir.path, 'MomentKeep'));
      
      // 定义所有可能的图片路径
      final List<String> possiblePaths = [];
      
      // 旧路径：直接在images目录下
      final oldImageDir = Directory(path_package.join(storageDir.path, 'images'));
      possiblePaths.add(path_package.join(oldImageDir.path, widget.imagePath));
      
      // 旧路径：直接在storage目录下
      possiblePaths.add(path_package.join(storageDir.path, widget.imagePath));
      
      // 新路径：带有用户ID的目录结构
      // 1. 列出storageDir下的所有子目录（用户ID目录）
      if (await storageDir.exists()) {
        final userDirs = storageDir.listSync().where((entity) => entity is Directory).toList();
        for (final userDir in userDirs) {
          final userDirPath = (userDir as Directory).path;
          
          // 尝试用户目录下的images目录
          final userImageDir = Directory(path_package.join(userDirPath, 'images'));
          possiblePaths.add(path_package.join(userImageDir.path, widget.imagePath));
          
          // 尝试直接在用户目录下
          possiblePaths.add(path_package.join(userDirPath, widget.imagePath));
        }
      }
      
      // 调试信息：打印所有可能的路径
      debugPrint('Checking image paths: $possiblePaths');
      
      // 尝试所有可能的路径
      bool found = false;
      for (final fullPath in possiblePaths) {
        final file = File(fullPath);
        if (await file.exists()) {
          _fullImagePath = fullPath;
          debugPrint('Found image at: $fullPath');
          found = true;
          break;
        }
      }
      
      if (!found) {
        _hasError = true;
        debugPrint('Image not found in any path: ${widget.imagePath}');
      }
    } catch (e) {
      debugPrint('Error loading image path: $e');
      _hasError = true;
    } finally {
      _isLoading = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  // 根据鼠标位置确定当前的调整大小手柄
  ResizeHandle _getResizeHandle(Offset localPosition) {
    const handleSize = 15.0;
    
    // 检查四个角
    if (localPosition.dx <= handleSize && localPosition.dy <= handleSize) {
      return ResizeHandle.topLeft;
    } else if (localPosition.dx >= _width - handleSize && localPosition.dy <= handleSize) {
      return ResizeHandle.topRight;
    } else if (localPosition.dx <= handleSize && localPosition.dy >= _height - handleSize) {
      return ResizeHandle.bottomLeft;
    } else if (localPosition.dx >= _width - handleSize && localPosition.dy >= _height - handleSize) {
      return ResizeHandle.bottomRight;
    }
    
    // 检查四条边
    if (localPosition.dy <= handleSize) {
      return ResizeHandle.top;
    } else if (localPosition.dx >= _width - handleSize) {
      return ResizeHandle.right;
    } else if (localPosition.dy >= _height - handleSize) {
      return ResizeHandle.bottom;
    } else if (localPosition.dx <= handleSize) {
      return ResizeHandle.left;
    }
    
    return ResizeHandle.none;
  }

  // 处理调整大小开始
  void _onResizeStart(DragStartDetails details) {
    setState(() {
      _isResizing = true;
      _resizeStartOffset = details.localPosition;
      _resizeHandle = _getResizeHandle(details.localPosition);
    });
  }

  // 处理调整大小过程
  void _onResizeUpdate(DragUpdateDetails details) {
    if (!_isResizing) return;
    
    final delta = details.localPosition - _resizeStartOffset;
    double newWidth = _width;
    double newHeight = _height;
    
    switch (_resizeHandle) {
      // 角手柄 - 同时调整宽度和高度
      case ResizeHandle.topLeft:
        newWidth = _width - delta.dx;
        newHeight = _height - delta.dy;
        break;
      case ResizeHandle.topRight:
        newWidth = _width + delta.dx;
        newHeight = _height - delta.dy;
        break;
      case ResizeHandle.bottomLeft:
        newWidth = _width - delta.dx;
        newHeight = _height + delta.dy;
        break;
      case ResizeHandle.bottomRight:
        newWidth = _width + delta.dx;
        newHeight = _height + delta.dy;
        break;
      // 边手柄 - 只调整一个维度
      case ResizeHandle.top:
        newHeight = _height - delta.dy;
        break;
      case ResizeHandle.right:
        newWidth = _width + delta.dx;
        break;
      case ResizeHandle.bottom:
        newHeight = _height + delta.dy;
        break;
      case ResizeHandle.left:
        newWidth = _width - delta.dx;
        break;
      default:
        return;
    }
    
    // 限制最小和最大尺寸
    newWidth = newWidth.clamp(_minWidth, _maxWidth);
    newHeight = newHeight.clamp(_minHeight, _maxHeight);
    
    setState(() {
      _width = newWidth;
      _height = newHeight;
    });
  }

  // 处理调整大小结束
  void _onResizeEnd(DragEndDetails details) {
    setState(() {
      _isResizing = false;
      _resizeHandle = ResizeHandle.none;
    });
  }

  // 当前鼠标位置的手柄类型
  ResizeHandle _currentHandle = ResizeHandle.none;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        width: 300,
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasError || _fullImagePath.isEmpty) {
      return SizedBox(
        width: _width,
        height: _height,
        child: Center(
          child: Icon(Icons.error, color: Colors.red, size: 48),
        ),
      );
    }

    // 添加 ExcludeSemantics 以防止 Windows 端辅助功能树崩溃
    return ExcludeSemantics(
      child: Center(
        child: MouseRegion(
          onHover: (details) {
            final handle = _getResizeHandle(details.localPosition);
            if (handle != _currentHandle) {
              setState(() {
                _currentHandle = handle;
              });
            }
          },
          onExit: (details) {
            if (_currentHandle != ResizeHandle.none) {
              setState(() {
                _currentHandle = ResizeHandle.none;
              });
            }
          },
          cursor: _getCursorForHandle(_currentHandle),
          child: GestureDetector(
            // 只使用拖动手势识别器来处理调整大小
            onPanStart: _onResizeStart,
            onPanUpdate: _onResizeUpdate,
            onPanEnd: _onResizeEnd,
            child: Container(
              width: _width,
              height: _height,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey, width: 1),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 图片显示 - 根据平台选择不同的图片加载方式
                  if (kIsWeb)
                    // Web平台使用Image.network
                    Image.network(
                      _fullImagePath,
                      fit: BoxFit.contain, // 使用contain确保整个图像可见
                      width: _width,
                      height: _height,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('Image loading error: $error');
                        return Center(
                          child: Icon(Icons.error, color: Colors.red, size: 48),
                        );
                      },
                    )
                  else
                    // 桌面平台使用Image.file
                    // 确保文件存在且路径有效
                    Image.file(
                      File(_fullImagePath),
                      fit: BoxFit.contain, // 使用contain确保整个图像可见
                      width: _width,
                      height: _height,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('Image loading error: $error');
                        return Center(
                          child: Icon(Icons.error, color: Colors.red, size: 48),
                        );
                      },
                    ),
                  // 调整大小的手柄
                  Positioned(
                    top: -5,
                    left: -5,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    top: -5,
                    right: -5,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -5,
                    left: -5,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -5,
                    right: -5,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 根据手柄类型获取光标样式
  MouseCursor _getCursorForHandle(ResizeHandle handle) {
    switch (handle) {
      // 角手柄
      case ResizeHandle.topLeft:
      case ResizeHandle.bottomRight:
        return SystemMouseCursors.resizeUpLeftDownRight;
      case ResizeHandle.topRight:
      case ResizeHandle.bottomLeft:
        return SystemMouseCursors.resizeUpRightDownLeft;
      // 边手柄
      case ResizeHandle.top:
      case ResizeHandle.bottom:
        return SystemMouseCursors.resizeUpDown;
      case ResizeHandle.left:
      case ResizeHandle.right:
        return SystemMouseCursors.resizeLeftRight;
      default:
        return MouseCursor.defer;
    }
  }
}
