import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as flutter_quill;
import 'package:moment_keep/presentation/components/journal_editor/drawing_point.dart';
import 'dart:async';

/// 绘图画家类
class DrawingPainter extends CustomPainter {
  final List<DrawingPoint> points;

  DrawingPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      return;
    }

    try {
      // Optimized: Draw only lines between consecutive points
      // No need to draw individual points since lines already cover them
      for (int i = 0; i < points.length - 1; i++) {
        final p1 = points[i];
        final p2 = points[i + 1];

        // Skip stroke end markers and invalid points
        if (p1.isEndOfStroke || p2.isEndOfStroke) {
          continue;
        }

        if (!p1.offset.dx.isFinite ||
            !p1.offset.dy.isFinite ||
            !p2.offset.dx.isFinite ||
            !p2.offset.dy.isFinite) {
          continue;
        }

        // Draw a simple line between consecutive points
        final paint = Paint()
          ..color = p1.color
          ..strokeWidth = p1.width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

        canvas.drawLine(p1.offset, p2.offset, paint);
      }
    } catch (e, stackTrace) {
      // Prevent application crash by catching all exceptions
      print('DrawingPainter.paint: ERROR - $e');
      print('DrawingPainter.paint: STACK TRACE - $stackTrace');
    }
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) {
    if (identical(oldDelegate.points, points)) return false;
    if (oldDelegate.points.length != points.length) return true;

    // Fast path for very small number of points
    if (points.length <= 10) {
      for (int i = 0; i < points.length; i++) {
        final oldPoint = oldDelegate.points[i];
        final newPoint = points[i];

        if (oldPoint.offset != newPoint.offset ||
            oldPoint.isEndOfStroke != newPoint.isEndOfStroke) {
          return true;
        }
      }
      return false;
    }

    // Optimized: Check only the most recent points
    // When drawing, only the last few points change
    final compareCount = math.min(20, points.length);
    final startIndex = points.length - compareCount;

    for (int i = startIndex; i < points.length; i++) {
      final oldPoint = oldDelegate.points[i];
      final newPoint = points[i];

      if (oldPoint.offset != newPoint.offset ||
          oldPoint.isEndOfStroke != newPoint.isEndOfStroke) {
        return true;
      }
    }

    return false;
  }

  @override
  bool hitTest(Offset position) {
    // Optimized: Return false to indicate we don't need hit testing
    // This can improve performance for complex drawings
    return false;
  }

  // Removed semanticsBuilder override to avoid null return type error
  // The default implementation already returns null implicitly
}

/// 自定义绘图嵌入构建器
class DrawingEmbedBuilder extends flutter_quill.EmbedBuilder {
  @override
  String get key => 'drawing';

  /// 安全的 JSON 解析，避免解析失败导致崩溃
  Map<String, dynamic>? _safeJsonDecode(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (e) {
      debugPrint('Error parsing JSON: $e');
    }
    return null;
  }

  /// 从 map 中提取绘图点，处理各种可能的格式
  List<DrawingPoint> _extractDrawingPointsFromMap(Map<dynamic, dynamic> map) {
    List<DrawingPoint> points = [];

    // 直接查找points字段
    if (map.containsKey('points')) {
      final pointsValue = map['points'];
      if (pointsValue is List) {
        try {
          points = pointsValue
              .where((e) => e is Map<String, dynamic>)
              .map((e) => DrawingPoint.fromJson(e as Map<String, dynamic>))
              .toList();
        } catch (e) {
          debugPrint('Error extracting points: $e');
        }
      }
    }

    // 查找custom字段中的points
    if (points.isEmpty && map.containsKey('custom')) {
      final customValue = map['custom'];
      if (customValue is Map && customValue.containsKey('points')) {
        final pointsValue = customValue['points'];
        if (pointsValue is List) {
          try {
            points = pointsValue
                .where((e) => e is Map<String, dynamic>)
                .map((e) => DrawingPoint.fromJson(e as Map<String, dynamic>))
                .toList();
          } catch (e) {
            debugPrint('Error extracting points from custom: $e');
          }
        }
      }
    }

    return points;
  }

  /// 从 map 中提取绘图 ID，处理各种可能的格式
  String _extractDrawingIdFromMap(Map<dynamic, dynamic> map) {
    // 直接查找id字段
    if (map.containsKey('id')) {
      final idValue = map['id'];
      if (idValue is String) {
        return idValue;
      } else if (idValue is int) {
        return idValue.toString();
      }
    }

    // 查找custom字段中的id
    if (map.containsKey('custom')) {
      final customValue = map['custom'];
      if (customValue is Map && customValue.containsKey('id')) {
        final idValue = customValue['id'];
        if (idValue is String) {
          return idValue;
        } else if (idValue is int) {
          return idValue.toString();
        }
      }
    }

    // 生成一个新的ID
    return 'new_${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(1000)}';
  }

  /// 从节点中提取绘图数据
  /// 作为备用方法，用于处理解析失败的情况
  Map<String, dynamic> _extractDrawingDataFromNode(flutter_quill.Node node) {
    // 实现从节点中提取绘图数据的逻辑
    // 由于这是一个备用方法，我们可以尝试从节点的其他属性中提取数据
    List<DrawingPoint> points = [];
    double height = 300.0;
    String drawingId = '';

    try {
      // 注意：Node是抽象类，不同的子类可能有不同的属性
      // 尝试从节点的原始数据中恢复绘图数据
      debugPrint('Using fallback method to extract drawing data');

      // 尝试使用动态访问获取节点的原始数据
      dynamic dynamicNode = node;
      try {
        // 尝试获取节点的value属性
        dynamic nodeValue = dynamicNode.value;
        if (nodeValue != null) {
          // 尝试获取data属性
          dynamic embedData = nodeValue.data;
          if (embedData != null) {
            // 尝试从embedData中提取绘图数据
            if (embedData is Map) {
              if (embedData.containsKey('points') &&
                  embedData['points'] is List) {
                final pointsList = embedData['points'] as List;
                points.addAll(pointsList
                    .where((e) => e is Map<String, dynamic>)
                    .map((e) =>
                        DrawingPoint.fromJson(e as Map<String, dynamic>)));
              }
              if (embedData.containsKey('height') &&
                  embedData['height'] is num) {
                height = embedData['height'] as double;
              }
              if (embedData.containsKey('id') && embedData['id'] is String) {
                drawingId = embedData['id'] as String;
              }
              // 处理新的嵌入数据格式
              if (embedData.containsKey('custom') &&
                  embedData['custom'] is String) {
                final customData = embedData['custom'] as String;
                if (customData != 'OBJ' && customData.isNotEmpty) {
                  final map = _safeJsonDecode(customData);
                  if (map != null) {
                    if (map.containsKey('points') && map['points'] is List) {
                      final pointsList = map['points'] as List;
                      points.addAll(pointsList
                          .where((e) => e is Map<String, dynamic>)
                          .map((e) => DrawingPoint.fromJson(
                              e as Map<String, dynamic>)));
                    }
                    if (map.containsKey('height') && map['height'] is num) {
                      height = map['height'] as double;
                    }
                    if (map.containsKey('id') && map['id'] is String) {
                      drawingId = map['id'] as String;
                    }
                  }
                }
              }
            } else if (embedData is String) {
              // 尝试解析字符串数据，即使是"OBJ"也尝试解析
              debugPrint(
                  'DrawingEmbedBuilder: Trying to parse string data: $embedData');
              if (embedData != 'OBJ' && embedData.isNotEmpty) {
                final map = _safeJsonDecode(embedData);
                if (map != null) {
                  if (map.containsKey('points') && map['points'] is List) {
                    final pointsList = map['points'] as List;
                    points.addAll(pointsList
                        .where((e) => e is Map<String, dynamic>)
                        .map((e) =>
                            DrawingPoint.fromJson(e as Map<String, dynamic>)));
                  }
                  if (map.containsKey('height') && map['height'] is num) {
                    height = map['height'] as double;
                  }
                  if (map.containsKey('id') && map['id'] is String) {
                    drawingId = map['id'] as String;
                  }
                }
              }
            } else if (embedData is flutter_quill.CustomBlockEmbed) {
              // 处理CustomBlockEmbed对象
              debugPrint(
                  'DrawingEmbedBuilder: Handling CustomBlockEmbed in extract method');
              final customEmbedData = embedData.data;
              if (customEmbedData is String) {
                debugPrint(
                    'DrawingEmbedBuilder: CustomBlockEmbed data is string: $customEmbedData');
                if (customEmbedData != 'OBJ' && customEmbedData.isNotEmpty) {
                  final map = _safeJsonDecode(customEmbedData);
                  if (map != null) {
                    if (map.containsKey('points') && map['points'] is List) {
                      final pointsList = map['points'] as List;
                      points.addAll(pointsList
                          .where((e) => e is Map<String, dynamic>)
                          .map((e) => DrawingPoint.fromJson(
                              e as Map<String, dynamic>)));
                    }
                    if (map.containsKey('height') && map['height'] is num) {
                      height = map['height'] as double;
                    }
                    if (map.containsKey('id') && map['id'] is String) {
                      drawingId = map['id'] as String;
                    }
                  }
                }
              } else if (customEmbedData is Map) {
                if (customEmbedData.containsKey('points') &&
                    customEmbedData['points'] is List) {
                  final pointsList = customEmbedData['points'] as List;
                  points.addAll(pointsList
                      .where((e) => e is Map<String, dynamic>)
                      .map((e) =>
                          DrawingPoint.fromJson(e as Map<String, dynamic>)));
                }
                if (customEmbedData.containsKey('height') &&
                    customEmbedData['height'] is num) {
                  height = customEmbedData['height'] as double;
                }
                if (customEmbedData.containsKey('id') &&
                    customEmbedData['id'] is String) {
                  drawingId = customEmbedData['id'] as String;
                }
              }
            } else if (embedData is flutter_quill.BlockEmbed) {
              // 处理BlockEmbed对象
              debugPrint(
                  'DrawingEmbedBuilder: Handling BlockEmbed in extract method');
              final blockEmbedData = embedData.data;
              if (blockEmbedData is String) {
                debugPrint(
                    'DrawingEmbedBuilder: BlockEmbed data is string: $blockEmbedData');
                if (blockEmbedData != 'OBJ' && blockEmbedData.isNotEmpty) {
                  final map = _safeJsonDecode(blockEmbedData);
                  if (map != null) {
                    if (map.containsKey('points') && map['points'] is List) {
                      final pointsList = map['points'] as List;
                      points.addAll(pointsList
                          .where((e) => e is Map<String, dynamic>)
                          .map((e) => DrawingPoint.fromJson(
                              e as Map<String, dynamic>)));
                    }
                    if (map.containsKey('height') && map['height'] is num) {
                      height = map['height'] as double;
                    }
                    if (map.containsKey('id') && map['id'] is String) {
                      drawingId = map['id'] as String;
                    }
                  }
                }
              } else if (blockEmbedData is Map) {
                if (blockEmbedData.containsKey('points') &&
                    blockEmbedData['points'] is List) {
                  final pointsList = blockEmbedData['points'] as List;
                  points.addAll(pointsList
                      .where((e) => e is Map<String, dynamic>)
                      .map((e) =>
                          DrawingPoint.fromJson(e as Map<String, dynamic>)));
                }
                if (blockEmbedData.containsKey('height') &&
                    blockEmbedData['height'] is num) {
                  height = blockEmbedData['height'] as double;
                }
                if (blockEmbedData.containsKey('id') &&
                    blockEmbedData['id'] is String) {
                  drawingId = blockEmbedData['id'] as String;
                }
              }
            }
          }
        }

        // 尝试获取节点的其他属性，作为最后的恢复手段
        debugPrint('DrawingEmbedBuilder: Trying other node properties');
        try {
          // 尝试获取节点的type属性
          dynamic nodeType = dynamicNode.type;
          debugPrint('DrawingEmbedBuilder: Node type: $nodeType');

          // 尝试获取节点的toJson方法
          if (dynamicNode is! flutter_quill.Leaf) {
            // 对于非叶子节点，尝试其他方法
            debugPrint('DrawingEmbedBuilder: Node is not a Leaf');
          }
        } catch (e) {
          debugPrint(
              'DrawingEmbedBuilder: Error accessing other node properties: $e');
        }
      } catch (e) {
        // 如果获取失败，尝试其他方式
        debugPrint('Error extracting drawing data from node: $e');

        // 尝试直接从node对象中提取数据
        try {
          debugPrint('DrawingEmbedBuilder: Trying direct node access');
          // 尝试获取node的documentOffset
          final offset = node.documentOffset;
          debugPrint('DrawingEmbedBuilder: Node offset: $offset');
        } catch (e2) {
          debugPrint('DrawingEmbedBuilder: Error with direct node access: $e2');
        }
      }
    } catch (e) {
      debugPrint('Error in _extractDrawingDataFromNode: $e');
      // 如果提取失败，返回空数据
    }

    return {'points': points, 'height': height, 'drawingId': drawingId};
  }

  @override
  Widget build(BuildContext context, flutter_quill.EmbedContext embedContext) {
    final node = embedContext.node;
    final data = node.value.data;
    List<DrawingPoint> points = [];
    double height = 300.0;
    String drawingId = '';

    // Debug: Print data type and value
    debugPrint(
        'DrawingEmbedBuilder: data type: ${data.runtimeType}, value: $data');

    // 增强的绘图数据解析逻辑，处理被IME破坏的格式
    try {
      // 处理不同类型的数据
      if (data is String) {
        // 处理字符串数据
        debugPrint('DrawingEmbedBuilder: Handling string data');
        // 检查字符串是否为 "OBJ" 或其他无效值
        if (data == 'OBJ' || data.isEmpty) {
          debugPrint('DrawingEmbedBuilder: Invalid string data: $data');
          // 尝试从节点中提取绘图数据
          final extractedData = _extractDrawingDataFromNode(node);
          points = extractedData['points'] ?? [];
          height = extractedData['height'] ?? 300.0;
          drawingId = extractedData['drawingId'] ?? '';
          // 尝试从文档历史中恢复数据
          if (points.isEmpty) {
            points = _recoverDrawingDataFromDocument(embedContext.controller);
            debugPrint(
                'DrawingEmbedBuilder: Recovered points from document history: ${points.length}');
          }
          // 尝试从整个文档中搜索绘图数据
          if (points.isEmpty) {
            points = _searchDrawingDataInDocument(embedContext.controller);
            debugPrint(
                'DrawingEmbedBuilder: Searched drawing data in entire document: ${points.length}');
          }
        } else {
          final map = _safeJsonDecode(data);
          if (map != null) {
            final parsedData = _parseDrawingData(map);
            points = parsedData['points'] ?? [];
            height = parsedData['height'] ?? 300.0;
            drawingId = parsedData['drawingId'] ?? '';
          } else {
            // JSON解析失败，尝试从节点中提取绘图数据
            debugPrint(
                'DrawingEmbedBuilder: JSON parsing failed, trying node extraction');
            final extractedData = _extractDrawingDataFromNode(node);
            points = extractedData['points'] ?? [];
            height = extractedData['height'] ?? 300.0;
            drawingId = extractedData['drawingId'] ?? '';
            // 尝试从文档历史中恢复数据
            if (points.isEmpty) {
              points = _recoverDrawingDataFromDocument(embedContext.controller);
              debugPrint(
                  'DrawingEmbedBuilder: Recovered points from document history: ${points.length}');
            }
            // 尝试从整个文档中搜索绘图数据
            if (points.isEmpty) {
              points = _searchDrawingDataInDocument(embedContext.controller);
              debugPrint(
                  'DrawingEmbedBuilder: Searched drawing data in entire document: ${points.length}');
            }
          }
        }
      } else if (data is Map) {
        // 处理map数据，包括被IME破坏的格式
        debugPrint('DrawingEmbedBuilder: Handling map data');
        // 首先检查是否包含custom字段，这是最常见的格式
        if (data.containsKey('custom')) {
          final customData = data['custom'];
          debugPrint(
              'DrawingEmbedBuilder: Found custom field, type: ${customData.runtimeType}');
          if (customData is String) {
            // 尝试解析custom字符串
            final customMap = _safeJsonDecode(customData);
            if (customMap != null) {
              debugPrint('DrawingEmbedBuilder: Parsed custom string to map');
              // 检查是否包含drawing字段（嵌套格式）
              if (customMap.containsKey('drawing')) {
                final drawingData = customMap['drawing'];
                if (drawingData is String) {
                  // 解析嵌套的绘图字符串
                  final drawingMap = _safeJsonDecode(drawingData);
                  if (drawingMap != null) {
                    debugPrint(
                        'DrawingEmbedBuilder: Parsed nested drawing string to map');
                    final parsedData = _parseDrawingData(drawingMap);
                    points = parsedData['points'] ?? [];
                    height = parsedData['height'] ?? 300.0;
                    drawingId = parsedData['drawingId'] ?? '';
                  }
                } else if (drawingData is Map) {
                  // 直接解析嵌套的绘图map
                  debugPrint(
                      'DrawingEmbedBuilder: Directly parsing nested drawing map');
                  final parsedData = _parseDrawingData(drawingData);
                  points = parsedData['points'] ?? [];
                  height = parsedData['height'] ?? 300.0;
                  drawingId = parsedData['drawingId'] ?? '';
                }
              } else {
                // 直接解析custom map
                debugPrint('DrawingEmbedBuilder: Directly parsing custom map');
                final parsedData = _parseDrawingData(customMap);
                points = parsedData['points'] ?? [];
                height = parsedData['height'] ?? 300.0;
                drawingId = parsedData['drawingId'] ?? '';
              }
            }
          } else if (customData is Map) {
            // 直接解析custom map
            debugPrint('DrawingEmbedBuilder: Directly parsing custom map');
            final parsedData = _parseDrawingData(customData);
            points = parsedData['points'] ?? [];
            height = parsedData['height'] ?? 300.0;
            drawingId = parsedData['drawingId'] ?? '';
          }
        } else {
          // 直接解析map
          debugPrint('DrawingEmbedBuilder: Directly parsing map');
          final parsedData = _parseDrawingData(data);
          points = parsedData['points'] ?? [];
          height = parsedData['height'] ?? 300.0;
          drawingId = parsedData['drawingId'] ?? '';
        }

        // 尝试从文档历史中恢复数据
        if (points.isEmpty) {
          points = _recoverDrawingDataFromDocument(embedContext.controller);
          debugPrint(
              'DrawingEmbedBuilder: Recovered points from document history: ${points.length}');
        }
        // 尝试从整个文档中搜索绘图数据
        if (points.isEmpty) {
          points = _searchDrawingDataInDocument(embedContext.controller);
          debugPrint(
              'DrawingEmbedBuilder: Searched drawing data in entire document: ${points.length}');
        }
      } else if (data is flutter_quill.CustomBlockEmbed) {
        // 处理CustomBlockEmbed直接类型
        debugPrint('DrawingEmbedBuilder: Handling CustomBlockEmbed data');
        final customData = data.data;
        if (customData is String) {
          // 检查字符串是否为 "OBJ" 或其他无效值
          if (customData == 'OBJ' || customData.isEmpty) {
            debugPrint(
                'DrawingEmbedBuilder: Invalid CustomBlockEmbed string: $customData');
            // 尝试从节点中提取绘图数据
            final extractedData = _extractDrawingDataFromNode(node);
            points = extractedData['points'] ?? [];
            height = extractedData['height'] ?? 300.0;
            drawingId = extractedData['drawingId'] ?? '';
            // 尝试从文档历史中恢复数据
            if (points.isEmpty) {
              points = _recoverDrawingDataFromDocument(embedContext.controller);
              debugPrint(
                  'DrawingEmbedBuilder: Recovered points from document history: ${points.length}');
            }
            // 尝试从整个文档中搜索绘图数据
            if (points.isEmpty) {
              points = _searchDrawingDataInDocument(embedContext.controller);
              debugPrint(
                  'DrawingEmbedBuilder: Searched drawing data in entire document: ${points.length}');
            }
          } else {
            // 尝试解析customData字符串
            final map = _safeJsonDecode(customData);
            if (map != null) {
              debugPrint(
                  'DrawingEmbedBuilder: Parsed CustomBlockEmbed string to map');
              final parsedData = _parseDrawingData(map);
              points = parsedData['points'] ?? [];
              height = parsedData['height'] ?? 300.0;
              drawingId = parsedData['drawingId'] ?? '';
            } else {
              // JSON解析失败，尝试从节点中提取绘图数据
              debugPrint(
                  'DrawingEmbedBuilder: CustomBlockEmbed JSON parsing failed, trying node extraction');
              final extractedData = _extractDrawingDataFromNode(node);
              points = extractedData['points'] ?? [];
              height = extractedData['height'] ?? 300.0;
              drawingId = extractedData['drawingId'] ?? '';
              // 尝试从文档历史中恢复数据
              if (points.isEmpty) {
                points =
                    _recoverDrawingDataFromDocument(embedContext.controller);
                debugPrint(
                    'DrawingEmbedBuilder: Recovered points from document history: ${points.length}');
              }
              // 尝试从整个文档中搜索绘图数据
              if (points.isEmpty) {
                points = _searchDrawingDataInDocument(embedContext.controller);
                debugPrint(
                    'DrawingEmbedBuilder: Searched drawing data in entire document: ${points.length}');
              }
            }
          }
        } else if (customData is Map) {
          debugPrint('DrawingEmbedBuilder: CustomBlockEmbed data is map');
          final parsedData = _parseDrawingData(customData);
          points = parsedData['points'] ?? [];
          height = parsedData['height'] ?? 300.0;
          drawingId = parsedData['drawingId'] ?? '';
          // 尝试从文档历史中恢复数据
          if (points.isEmpty) {
            final recoveredData = _extractDrawingDataFromNode(node);
            points = recoveredData['points'] ?? [];
            debugPrint(
                'DrawingEmbedBuilder: Recovered points from node: ${points.length}');
          }
          // 尝试从整个文档中搜索绘图数据
          if (points.isEmpty) {
            points = _searchDrawingDataInDocument(embedContext.controller);
            debugPrint(
                'DrawingEmbedBuilder: Searched drawing data in entire document: ${points.length}');
          }
        } else {
          // 处理其他类型的customData
          debugPrint(
              'DrawingEmbedBuilder: CustomBlockEmbed data is other type: ${customData.runtimeType}');
          // 尝试从节点中提取绘图数据
          final extractedData = _extractDrawingDataFromNode(node);
          points = extractedData['points'] ?? [];
          height = extractedData['height'] ?? 300.0;
          drawingId = extractedData['drawingId'] ?? '';
          // 尝试从文档历史中恢复数据
          if (points.isEmpty) {
            points = _recoverDrawingDataFromDocument(embedContext.controller);
            debugPrint(
                'DrawingEmbedBuilder: Recovered points from document history: ${points.length}');
          }
          // 尝试从整个文档中搜索绘图数据
          if (points.isEmpty) {
            points = _searchDrawingDataInDocument(embedContext.controller);
            debugPrint(
                'DrawingEmbedBuilder: Searched drawing data in entire document: ${points.length}');
          }
        }
      } else if (data is flutter_quill.BlockEmbed) {
        // 处理BlockEmbed类型
        debugPrint('DrawingEmbedBuilder: Handling BlockEmbed data');
        final embedData = data.data;
        if (embedData is String) {
          // 检查字符串是否为 "OBJ" 或其他无效值
          if (embedData == 'OBJ' || embedData.isEmpty) {
            debugPrint(
                'DrawingEmbedBuilder: Invalid BlockEmbed string: $embedData');
            // 尝试从节点中提取绘图数据
            final extractedData = _extractDrawingDataFromNode(node);
            points = extractedData['points'] ?? [];
            height = extractedData['height'] ?? 300.0;
            drawingId = extractedData['drawingId'] ?? '';
            // 尝试从文档历史中恢复数据
            if (points.isEmpty) {
              points = _recoverDrawingDataFromDocument(embedContext.controller);
              debugPrint(
                  'DrawingEmbedBuilder: Recovered points from document history: ${points.length}');
            }
            // 尝试从整个文档中搜索绘图数据
            if (points.isEmpty) {
              points = _searchDrawingDataInDocument(embedContext.controller);
              debugPrint(
                  'DrawingEmbedBuilder: Searched drawing data in entire document: ${points.length}');
            }
          } else {
            final map = _safeJsonDecode(embedData);
            if (map != null) {
              final parsedData = _parseDrawingData(map);
              points = parsedData['points'] ?? [];
              height = parsedData['height'] ?? 300.0;
              drawingId = parsedData['drawingId'] ?? '';
            } else {
              // JSON解析失败，尝试从节点中提取绘图数据
              debugPrint(
                  'DrawingEmbedBuilder: BlockEmbed JSON parsing failed, trying node extraction');
              final extractedData = _extractDrawingDataFromNode(node);
              points = extractedData['points'] ?? [];
              height = extractedData['height'] ?? 300.0;
              drawingId = extractedData['drawingId'] ?? '';
              // 尝试从文档历史中恢复数据
              if (points.isEmpty) {
                points =
                    _recoverDrawingDataFromDocument(embedContext.controller);
                debugPrint(
                    'DrawingEmbedBuilder: Recovered points from document history: ${points.length}');
              }
              // 尝试从整个文档中搜索绘图数据
              if (points.isEmpty) {
                points = _searchDrawingDataInDocument(embedContext.controller);
                debugPrint(
                    'DrawingEmbedBuilder: Searched drawing data in entire document: ${points.length}');
              }
            }
          }
        } else if (embedData is flutter_quill.CustomBlockEmbed) {
          // 处理BlockEmbed.custom()创建的嵌入类型
          debugPrint(
              'DrawingEmbedBuilder: BlockEmbed data is CustomBlockEmbed');
          final customEmbedData = embedData.data;
          if (customEmbedData is String) {
            debugPrint(
                'DrawingEmbedBuilder: CustomBlockEmbed data is string: $customEmbedData');
            if (customEmbedData != 'OBJ' && customEmbedData.isNotEmpty) {
              final map = _safeJsonDecode(customEmbedData);
              if (map != null) {
                debugPrint(
                    'DrawingEmbedBuilder: Parsed CustomBlockEmbed string to map');
                final parsedData = _parseDrawingData(map);
                points = parsedData['points'] ?? [];
                height = parsedData['height'] ?? 300.0;
                drawingId = parsedData['drawingId'] ?? '';
              }
            }
          } else if (customEmbedData is Map) {
            debugPrint('DrawingEmbedBuilder: CustomBlockEmbed data is map');
            final parsedData = _parseDrawingData(customEmbedData);
            points = parsedData['points'] ?? [];
            height = parsedData['height'] ?? 300.0;
            drawingId = parsedData['drawingId'] ?? '';
          }
          // 尝试从文档历史中恢复数据
          if (points.isEmpty) {
            points = _recoverDrawingDataFromDocument(embedContext.controller);
            debugPrint(
                'DrawingEmbedBuilder: Recovered points from document history: ${points.length}');
          }
          // 尝试从整个文档中搜索绘图数据
          if (points.isEmpty) {
            points = _searchDrawingDataInDocument(embedContext.controller);
            debugPrint(
                'DrawingEmbedBuilder: Searched drawing data in entire document: ${points.length}');
          }
        } else if (embedData is Map) {
          final parsedData = _parseDrawingData(embedData);
          points = parsedData['points'] ?? [];
          height = parsedData['height'] ?? 300.0;
          drawingId = parsedData['drawingId'] ?? '';
          // 尝试从文档历史中恢复数据
          if (points.isEmpty) {
            points = _extractDrawingDataFromNode(node)['points'] ?? [];
            debugPrint(
                'DrawingEmbedBuilder: Recovered points from node: ${points.length}');
          }
          // 尝试从整个文档中搜索绘图数据
          if (points.isEmpty) {
            points = _searchDrawingDataInDocument(embedContext.controller);
            debugPrint(
                'DrawingEmbedBuilder: Searched drawing data in entire document: ${points.length}');
          }
        } else {
          // 处理其他类型的embedData
          debugPrint(
              'DrawingEmbedBuilder: BlockEmbed data is other type: ${embedData.runtimeType}');
          // 尝试从节点中提取绘图数据
          final extractedData = _extractDrawingDataFromNode(node);
          points = extractedData['points'] ?? [];
          height = extractedData['height'] ?? 300.0;
          drawingId = extractedData['drawingId'] ?? '';
          // 尝试从文档历史中恢复数据
          if (points.isEmpty) {
            points = _recoverDrawingDataFromDocument(embedContext.controller);
            debugPrint(
                'DrawingEmbedBuilder: Recovered points from document history: ${points.length}');
          }
          // 尝试从整个文档中搜索绘图数据
          if (points.isEmpty) {
            points = _searchDrawingDataInDocument(embedContext.controller);
            debugPrint(
                'DrawingEmbedBuilder: Searched drawing data in entire document: ${points.length}');
          }
        }
      } else {
        // 尝试处理其他类型的对象
        try {
          debugPrint('DrawingEmbedBuilder: Handling other data type');
          // 检查data是否有'data'属性（BlockEmbed情况）
          final dataData = data.data;
          if (dataData != null) {
            debugPrint(
                'DrawingEmbedBuilder: Found data.data property, type: ${dataData.runtimeType}');
            if (dataData is String) {
              // 检查字符串是否为 "OBJ" 或其他无效值
              if (dataData == 'OBJ' || dataData.isEmpty) {
                debugPrint(
                    'DrawingEmbedBuilder: Invalid other data type string: $dataData');
                // 尝试从节点中提取绘图数据
                final extractedData = _extractDrawingDataFromNode(node);
                points = extractedData['points'] ?? [];
                height = extractedData['height'] ?? 300.0;
                drawingId = extractedData['drawingId'] ?? '';
                // 尝试从文档历史中恢复数据
                if (points.isEmpty) {
                  points =
                      _recoverDrawingDataFromDocument(embedContext.controller);
                  debugPrint(
                      'DrawingEmbedBuilder: Recovered points from document history: ${points.length}');
                }
                // 尝试从整个文档中搜索绘图数据
                if (points.isEmpty) {
                  points =
                      _searchDrawingDataInDocument(embedContext.controller);
                  debugPrint(
                      'DrawingEmbedBuilder: Searched drawing data in entire document: ${points.length}');
                }
              } else {
                final map = _safeJsonDecode(dataData);
                if (map != null) {
                  final parsedData = _parseDrawingData(map);
                  points = parsedData['points'] ?? [];
                  height = parsedData['height'] ?? 300.0;
                  drawingId = parsedData['drawingId'] ?? '';
                } else {
                  // JSON解析失败，尝试从节点中提取绘图数据
                  debugPrint(
                      'DrawingEmbedBuilder: Other data type JSON parsing failed, trying node extraction');
                  final extractedData = _extractDrawingDataFromNode(node);
                  points = extractedData['points'] ?? [];
                  height = extractedData['height'] ?? 300.0;
                  drawingId = extractedData['drawingId'] ?? '';
                  // 尝试从文档历史中恢复数据
                  if (points.isEmpty) {
                    points = _recoverDrawingDataFromDocument(
                        embedContext.controller);
                    debugPrint(
                        'DrawingEmbedBuilder: Recovered points from document history: ${points.length}');
                  }
                  // 尝试从整个文档中搜索绘图数据
                  if (points.isEmpty) {
                    points =
                        _searchDrawingDataInDocument(embedContext.controller);
                    debugPrint(
                        'DrawingEmbedBuilder: Searched drawing data in entire document: ${points.length}');
                  }
                }
              }
            } else if (dataData is Map) {
              final parsedData = _parseDrawingData(dataData);
              points = parsedData['points'] ?? [];
              height = parsedData['height'] ?? 300.0;
              drawingId = parsedData['drawingId'] ?? '';
              // 尝试从文档历史中恢复数据
              if (points.isEmpty) {
                points =
                    _recoverDrawingDataFromDocument(embedContext.controller);
                debugPrint(
                    'DrawingEmbedBuilder: Recovered points from document history: ${points.length}');
              }
              // 尝试从整个文档中搜索绘图数据
              if (points.isEmpty) {
                points = _searchDrawingDataInDocument(embedContext.controller);
                debugPrint(
                    'DrawingEmbedBuilder: Searched drawing data in entire document: ${points.length}');
              }
            } else {
              // 处理其他类型的dataData
              debugPrint(
                  'DrawingEmbedBuilder: data.data is other type: ${dataData.runtimeType}');
              // 尝试从节点中提取绘图数据
              final extractedData = _extractDrawingDataFromNode(node);
              points = extractedData['points'] ?? [];
              height = extractedData['height'] ?? 300.0;
              drawingId = extractedData['drawingId'] ?? '';
              // 尝试从文档历史中恢复数据
              if (points.isEmpty) {
                points =
                    _recoverDrawingDataFromDocument(embedContext.controller);
                debugPrint(
                    'DrawingEmbedBuilder: Recovered points from document history: ${points.length}');
              }
              // 尝试从整个文档中搜索绘图数据
              if (points.isEmpty) {
                points = _searchDrawingDataInDocument(embedContext.controller);
                debugPrint(
                    'DrawingEmbedBuilder: Searched drawing data in entire document: ${points.length}');
              }
            }
          } else {
            // dataData为null，尝试从节点中提取绘图数据
            debugPrint('DrawingEmbedBuilder: data.data is null');
            final extractedData = _extractDrawingDataFromNode(node);
            points = extractedData['points'] ?? [];
            height = extractedData['height'] ?? 300.0;
            drawingId = extractedData['drawingId'] ?? '';
            // 尝试从文档历史中恢复数据
            if (points.isEmpty) {
              points = _recoverDrawingDataFromDocument(embedContext.controller);
              debugPrint(
                  'DrawingEmbedBuilder: Recovered points from document history: ${points.length}');
            }
            // 尝试从整个文档中搜索绘图数据
            if (points.isEmpty) {
              points = _searchDrawingDataInDocument(embedContext.controller);
              debugPrint(
                  'DrawingEmbedBuilder: Searched drawing data in entire document: ${points.length}');
            }
          }
        } catch (e) {
          debugPrint('Error handling other data type: $e');
          // 尝试从节点中提取绘图数据
          final extractedData = _extractDrawingDataFromNode(node);
          points = extractedData['points'] ?? [];
          height = extractedData['height'] ?? 300.0;
          drawingId = extractedData['drawingId'] ?? '';
          // 尝试从文档历史中恢复数据
          if (points.isEmpty) {
            points = _recoverDrawingDataFromDocument(embedContext.controller);
            debugPrint(
                'DrawingEmbedBuilder: Recovered points from document history: ${points.length}');
          }
          // 尝试从整个文档中搜索绘图数据
          if (points.isEmpty) {
            points = _searchDrawingDataInDocument(embedContext.controller);
            debugPrint(
                'DrawingEmbedBuilder: Searched drawing data in entire document: ${points.length}');
          }
        }
      }
    } catch (e) {
      debugPrint('Error parsing drawing data: $e');
      // 尝试替代解析方法，处理嵌套JSON格式和被IME破坏的格式
      try {
        if (data is Map) {
          // 处理包含custom字段的情况
          if (data.containsKey('custom')) {
            final customData = data['custom'];
            if (customData is String) {
              // 解析custom字符串数据
              final customMap = _safeJsonDecode(customData);
              if (customMap != null) {
                if (customMap is Map) {
                  // 检查是否包含drawing字段
                  if (customMap.containsKey('drawing')) {
                    final drawingData = customMap['drawing'];
                    if (drawingData is String) {
                      // 解析嵌套的绘图字符串数据
                      final drawingMap = _safeJsonDecode(drawingData);
                      if (drawingMap != null) {
                        final parsedData = _parseDrawingData(drawingMap);
                        points = parsedData['points'] ?? [];
                        height = parsedData['height'] ?? 300.0;
                        drawingId = parsedData['drawingId'] ?? '';
                      }
                    } else if (drawingData is Map) {
                      // 解析嵌套的绘图map数据
                      final parsedData = _parseDrawingData(drawingData);
                      points = parsedData['points'] ?? [];
                      height = parsedData['height'] ?? 300.0;
                      drawingId = parsedData['drawingId'] ?? '';
                    }
                  } else {
                    // 直接解析custom map
                    final parsedData = _parseDrawingData(customMap);
                    points = parsedData['points'] ?? [];
                    height = parsedData['height'] ?? 300.0;
                    drawingId = parsedData['drawingId'] ?? '';
                  }
                }
              }
            } else if (customData is Map) {
              // 解析custom map数据
              if (customData.containsKey('drawing')) {
                final drawingData = customData['drawing'];
                if (drawingData is String) {
                  // 解析嵌套的绘图字符串数据
                  final drawingMap = _safeJsonDecode(drawingData);
                  if (drawingMap != null) {
                    final parsedData = _parseDrawingData(drawingMap);
                    points = parsedData['points'] ?? [];
                    height = parsedData['height'] ?? 300.0;
                    drawingId = parsedData['drawingId'] ?? '';
                  }
                } else if (drawingData is Map) {
                  // 解析嵌套的绘图map数据
                  final parsedData = _parseDrawingData(drawingData);
                  points = parsedData['points'] ?? [];
                  height = parsedData['height'] ?? 300.0;
                  drawingId = parsedData['drawingId'] ?? '';
                }
              } else {
                // 直接解析custom map
                final parsedData = _parseDrawingData(customData);
                points = parsedData['points'] ?? [];
                height = parsedData['height'] ?? 300.0;
                drawingId = parsedData['drawingId'] ?? '';
              }
            }
          }

          // 如果仍然没有找到数据，尝试从map中提取关键点
          if (points.isEmpty) {
            points = _extractDrawingPointsFromMap(data);
            drawingId = _extractDrawingIdFromMap(data);
          }
        }
      } catch (e2) {
        debugPrint('Error parsing nested drawing data: $e2');
        // 尝试从节点中提取绘图数据
        final extractedData = _extractDrawingDataFromNode(node);
        points = extractedData['points'] ?? [];
        height = extractedData['height'] ?? 300.0;
        drawingId = extractedData['drawingId'] ?? '';
        // 尝试从文档历史中恢复数据
        if (points.isEmpty) {
          points = _recoverDrawingDataFromDocument(embedContext.controller);
          debugPrint(
              'DrawingEmbedBuilder: Recovered points from document history: ${points.length}');
        }
        // 尝试从整个文档中搜索绘图数据
        if (points.isEmpty) {
          points = _searchDrawingDataInDocument(embedContext.controller);
          debugPrint(
              'DrawingEmbedBuilder: Searched drawing data in entire document: ${points.length}');
        }
      }
    }

    // Debug: Print parsed data
    debugPrint(
        'DrawingEmbedBuilder: Parsed points: ${points.length}, height: $height, id: $drawingId');

    // 即使解析失败，也要确保返回一个有效的绘图组件
    // 这样可以避免整个编辑器崩溃
    if (points.isEmpty && drawingId.isEmpty) {
      debugPrint('DrawingEmbedBuilder: Creating empty drawing placeholder');
      // 生成一个唯一的绘图ID
      drawingId =
          'new_${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(1000)}';
    }

    // 使用基于绘图ID的稳定 key，避免每次重新渲染时重建 DrawingWidget
    // 这样可以保留未保存的绘图轨迹
    final key = ValueKey<String>(drawingId);

    return DrawingWidget(
      key: key,
      initialPoints: points,
      height: height,
      embedContext: embedContext,
    );
  }

  /// 从文档历史中恢复绘图数据
  List<DrawingPoint> _recoverDrawingDataFromDocument(
      flutter_quill.QuillController controller) {
    try {
      debugPrint(
          'DrawingEmbedBuilder: Attempting to recover drawing data from document history');

      // 获取文档的当前状态
      final delta = controller.document.toDelta();
      List<DrawingPoint> recoveredPoints = [];

      // 遍历文档中的所有操作，查找绘图嵌入
      for (final op in delta.toList()) {
        if (op.data is Map) {
          final dataMap = op.data as Map;

          // 查找包含绘图数据的操作
          if (dataMap.containsKey('custom')) {
            final customData = dataMap['custom'];
            if (customData is String) {
              // 检查是否为 OBJ 字符串
              if (customData == 'OBJ') {
                debugPrint(
                    'DrawingEmbedBuilder: Found OBJ string, skipping...');
                continue;
              }

              final customMap = _safeJsonDecode(customData);
              if (customMap != null && customMap is Map) {
                // 检查是否包含绘图数据
                if (customMap.containsKey('id') &&
                    customMap.containsKey('points')) {
                  final pointsData = customMap['points'];
                  if (pointsData is List) {
                    try {
                      final points = pointsData
                          .where((e) => e is Map<String, dynamic>)
                          .map((e) =>
                              DrawingPoint.fromJson(e as Map<String, dynamic>))
                          .toList();
                      if (points.isNotEmpty) {
                        recoveredPoints.addAll(points);
                        debugPrint(
                            'DrawingEmbedBuilder: Found drawing data in document history');
                        break;
                      }
                    } catch (e) {
                      debugPrint(
                          'Error recovering drawing data from document history: $e');
                    }
                  }
                }
              }
            } else if (customData is Map &&
                customData.containsKey('id') &&
                customData.containsKey('points')) {
              final pointsData = customData['points'];
              if (pointsData is List) {
                try {
                  final points = pointsData
                      .where((e) => e is Map<String, dynamic>)
                      .map((e) =>
                          DrawingPoint.fromJson(e as Map<String, dynamic>))
                      .toList();
                  if (points.isNotEmpty) {
                    recoveredPoints.addAll(points);
                    debugPrint(
                        'DrawingEmbedBuilder: Found drawing data in document history');
                    break;
                  }
                } catch (e) {
                  debugPrint(
                      'Error recovering drawing data from document history: $e');
                }
              }
            }
          }

          // 检查是否直接包含绘图数据
          if (dataMap.containsKey('drawing')) {
            final drawingData = dataMap['drawing'];
            if (drawingData is Map && drawingData.containsKey('points')) {
              final pointsData = drawingData['points'];
              if (pointsData is List) {
                try {
                  final points = pointsData
                      .where((e) => e is Map<String, dynamic>)
                      .map((e) =>
                          DrawingPoint.fromJson(e as Map<String, dynamic>))
                      .toList();
                  if (points.isNotEmpty) {
                    recoveredPoints.addAll(points);
                    debugPrint(
                        'DrawingEmbedBuilder: Found drawing data directly in document');
                    break;
                  }
                } catch (e) {
                  debugPrint(
                      'Error recovering drawing data from direct drawing field: $e');
                }
              }
            }
          }
        }
      }

      return recoveredPoints;
    } catch (e) {
      debugPrint('Error recovering drawing data from document: $e');
      return [];
    }
  }

  /// 在整个文档中搜索绘图数据
  List<DrawingPoint> _searchDrawingDataInDocument(
      flutter_quill.QuillController controller) {
    try {
      debugPrint(
          'DrawingEmbedBuilder: Searching for drawing data in entire document');

      // 获取文档的当前状态
      final delta = controller.document.toDelta();
      List<DrawingPoint> recoveredPoints = [];

      // 遍历文档中的所有操作，查找任何可能包含绘图数据的内容
      for (final op in delta.toList()) {
        if (op.data is Map) {
          final dataMap = op.data as Map;

          // 检查各种可能包含绘图数据的字段
          if (dataMap.containsKey('custom')) {
            final customData = dataMap['custom'];
            if (customData is String) {
              // 跳过 OBJ 字符串
              if (customData == 'OBJ') {
                continue;
              }

              // 尝试解析任何可能的 JSON 数据
              final customMap = _safeJsonDecode(customData);
              if (customMap != null && customMap is Map) {
                // 检查是否包含任何可能的绘图数据
                if (customMap.containsKey('points')) {
                  final pointsData = customMap['points'];
                  if (pointsData is List) {
                    try {
                      final points = pointsData
                          .where((e) => e is Map<String, dynamic>)
                          .map((e) =>
                              DrawingPoint.fromJson(e as Map<String, dynamic>))
                          .toList();
                      if (points.isNotEmpty) {
                        recoveredPoints.addAll(points);
                        debugPrint(
                            'DrawingEmbedBuilder: Found drawing data in custom field');
                        break;
                      }
                    } catch (e) {
                      debugPrint('Error parsing points from custom field: $e');
                    }
                  }
                }
              }
            } else if (customData is Map) {
              // 直接检查 customData Map
              if (customData.containsKey('points')) {
                final pointsData = customData['points'];
                if (pointsData is List) {
                  try {
                    final points = pointsData
                        .where((e) => e is Map<String, dynamic>)
                        .map((e) =>
                            DrawingPoint.fromJson(e as Map<String, dynamic>))
                        .toList();
                    if (points.isNotEmpty) {
                      recoveredPoints.addAll(points);
                      debugPrint(
                          'DrawingEmbedBuilder: Found drawing data in custom map');
                      break;
                    }
                  } catch (e) {
                    debugPrint('Error parsing points from custom map: $e');
                  }
                }
              }
            }
          }

          // 检查其他可能的字段
          if (dataMap.containsKey('drawing')) {
            final drawingData = dataMap['drawing'];
            if (drawingData is Map && drawingData.containsKey('points')) {
              final pointsData = drawingData['points'];
              if (pointsData is List) {
                try {
                  final points = pointsData
                      .where((e) => e is Map<String, dynamic>)
                      .map((e) =>
                          DrawingPoint.fromJson(e as Map<String, dynamic>))
                      .toList();
                  if (points.isNotEmpty) {
                    recoveredPoints.addAll(points);
                    debugPrint(
                        'DrawingEmbedBuilder: Found drawing data in drawing field');
                    break;
                  }
                } catch (e) {
                  debugPrint('Error parsing points from drawing field: $e');
                }
              }
            }
          }

          // 尝试从任何可能的字段中提取绘图数据
          if (recoveredPoints.isEmpty) {
            try {
              // 尝试将整个 dataMap 作为绘图数据处理
              if (dataMap.containsKey('points')) {
                final pointsData = dataMap['points'];
                if (pointsData is List) {
                  try {
                    final points = pointsData
                        .where((e) => e is Map<String, dynamic>)
                        .map((e) =>
                            DrawingPoint.fromJson(e as Map<String, dynamic>))
                        .toList();
                    if (points.isNotEmpty) {
                      recoveredPoints.addAll(points);
                      debugPrint(
                          'DrawingEmbedBuilder: Found drawing data in root map');
                      break;
                    }
                  } catch (e) {
                    debugPrint('Error parsing points from root map: $e');
                  }
                }
              }
            } catch (e) {
              debugPrint('Error checking root map for points: $e');
            }
          }
        }
      }

      return recoveredPoints;
    } catch (e) {
      debugPrint('Error searching for drawing data in document: $e');
      return [];
    }
  }

  /// Parse drawing data from a map and return a map with parsed values
  Map<String, dynamic> _parseDrawingData(dynamic data) {
    List<DrawingPoint> points = [];
    double height = 300.0;
    String drawingId = '';

    if (data is Map) {
      // Parse height
      if (data.containsKey('height')) {
        final heightValue = data['height'];
        if (heightValue is num) {
          height = heightValue.toDouble();
        } else if (heightValue is String) {
          try {
            height = double.parse(heightValue);
          } catch (e) {
            debugPrint('Error parsing height: $e');
          }
        }
      }

      // Parse drawing id
      if (data.containsKey('id')) {
        final idValue = data['id'];
        if (idValue is String) {
          drawingId = idValue;
        }
      }

      // Parse drawing points
      if (data.containsKey('points') && data['points'] is List) {
        final pointsList = data['points'] as List;
        points = pointsList
            .where((e) => e is Map<String, dynamic>)
            .map((e) => DrawingPoint.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }

    return {
      'points': points,
      'height': height,
      'drawingId': drawingId,
    };
  }
}

class DrawingWidget extends StatefulWidget {
  final List<DrawingPoint> initialPoints;
  final double height;
  final flutter_quill.EmbedContext embedContext;

  const DrawingWidget({
    Key? key,
    required this.initialPoints,
    required this.height,
    required this.embedContext,
  }) : super(key: key);

  @override
  State<DrawingWidget> createState() => _DrawingWidgetState();
}

class _DrawingWidgetState extends State<DrawingWidget> {
  late ValueNotifier<List<DrawingPoint>> _pointsNotifier;
  Color _currentColor = Colors.black;
  double _currentWidth = 3.0;
  late final ValueNotifier<bool> _isEraserModeNotifier;
  bool _isDrawing = false;
  bool _isDisposed = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    final initialPoints = _validateAndFilterPoints(widget.initialPoints);
    _pointsNotifier = ValueNotifier<List<DrawingPoint>>(initialPoints);
    _isEraserModeNotifier = ValueNotifier<bool>(false);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _debounceTimer?.cancel();
    _pointsNotifier.dispose();
    _isEraserModeNotifier.dispose();
    super.dispose();
  }

  /// 防抖自动保存
  void _debouncedSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1000), () {
      if (!_isDisposed) {
        saveDrawing();
      }
    });
  }

  /// 验证和过滤绘图点，确保所有点都是有效的
  List<DrawingPoint> _validateAndFilterPoints(List<DrawingPoint> points) {
    List<DrawingPoint> validPoints = [];

    for (final point in points) {
      if (point.isEndOfStroke) {
        validPoints.add(point);
        continue;
      }

      if (!point.offset.dx.isFinite || !point.offset.dy.isFinite) {
        continue;
      }

      validPoints.add(point);
    }

    return validPoints;
  }

  void _deleteDrawing() {
    if (_isDisposed) return;

    try {
      final controller = widget.embedContext.controller;
      final node = widget.embedContext.node;
      final offset = node.documentOffset;

      debugPrint('Delete drawing: offset=$offset');
      debugPrint(
          'Current document length: ${controller.document.toDelta().length}');

      // Delete the embed at the current node's offset
      controller.replaceText(
          offset, 1, '', TextSelection.collapsed(offset: offset));
      debugPrint('Drawing deleted at offset $offset');
    } catch (e) {
      debugPrint('Error deleting drawing: $e');
    }
  }

  @override
  void didUpdateWidget(covariant DrawingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPoints != oldWidget.initialPoints) {
      final initialPoints = _validateAndFilterPoints(widget.initialPoints);
      _pointsNotifier.value = initialPoints;
    }
    // 保持橡皮擦模式状态，避免在组件更新时被重置
  }

  void saveDrawing() {
    if (_isDisposed) {
      return;
    }

    try {
      final validPoints = _validateAndFilterPoints(_pointsNotifier.value);
      final pointsJson = validPoints.map((p) => p.toJson()).toList();

      final controller = widget.embedContext.controller;
      // Get the node from context slightly risky if document changed, but we will verify
      final currentNode = widget.embedContext.node;
      int offset = currentNode.documentOffset;

      // 验证文档结构，确保操作安全
      final doc = controller.document;
      final docLength = doc.length;

      // Safety check: if offset is out of bounds
      if (offset < 0 || offset >= docLength) {
        debugPrint('Invalid node offset: $offset, document length: $docLength');
        return;
      }

      // 验证当前节点是否存在且是嵌入节点
      final query = doc.queryChild(offset);
      final nodeAtOffset = query.node;

      // Critical Verification: specific drawing ID check
      // Try to get the ID from the current widget's context to verify we are updating the SAME node
      String currentDrawingId = '';
      try {
        final currentNodeValue = currentNode.value;
        if (currentNodeValue is flutter_quill.CustomBlockEmbed) {
          final dataStr = currentNodeValue.data;
          if (dataStr is String) {
            final data = jsonDecode(dataStr);
            if (data is Map && data.containsKey('id')) {
              currentDrawingId = data['id'];
            }
          }
        }
      } catch (_) {}

      // If we couldn't find ID in current context, try to find it in the node at the offset
      // This is to protect against the case where the document shifted and 'offset' points to something else

      String nodeAtOffsetId = '';
      if (nodeAtOffset != null && nodeAtOffset is flutter_quill.Leaf) {
        try {
          final val = nodeAtOffset.value;
          if (val is flutter_quill.CustomBlockEmbed) {
            final dataStr = val.data;
            if (dataStr is String) {
              final data = jsonDecode(dataStr);
              if (data is Map && data.containsKey('id')) {
                nodeAtOffsetId = data['id'];
              }
            }
          }
        } catch (_) {}
      }

      // If IDs don't match, or if we can't verify identity, SEARCH for the correct node
      if (currentDrawingId.isNotEmpty && currentDrawingId != nodeAtOffsetId) {
        debugPrint(
            'WARNING: Node at offset $offset (ID: $nodeAtOffsetId) does not match expected ID: $currentDrawingId. Searching document...');

        // Search the entire document for the node with the correct ID
        final delta = doc.toDelta();
        int currentScanOffset = 0;
        bool found = false;

        for (final op in delta.toList()) {
          if (op.data is Map) {
            try {
              // This is complex because we have to parse again, but necessary for correctness
              String scanId = '';
              final map = op.data as Map;

              if (map.containsKey('custom')) {
                final custom = map['custom'];
                if (custom is String) {
                  // custom is a JSON string
                  final d = jsonDecode(custom);
                  if (d is Map) {
                    if (d.containsKey('id')) {
                      scanId = d['id'];
                    } else if (d.containsKey('drawing')) {
                      // Handle nested drawing object
                      final drawingData = d['drawing'];
                      if (drawingData is Map && drawingData.containsKey('id')) {
                        scanId = drawingData['id'];
                      } else if (drawingData is String) {
                        final nested = jsonDecode(drawingData);
                        if (nested is Map && nested.containsKey('id')) {
                          scanId = nested['id'];
                        }
                      }
                    }
                  }
                } else if (custom is Map) {
                  if (custom.containsKey('id')) {
                    scanId = custom['id'];
                  } else if (custom.containsKey('drawing')) {
                    final drawingData = custom['drawing'];
                    if (drawingData is Map && drawingData.containsKey('id')) {
                      scanId = drawingData['id'];
                    } else if (drawingData is String) {
                      final nested = jsonDecode(drawingData);
                      if (nested is Map && nested.containsKey('id')) {
                        scanId = nested['id'];
                      }
                    }
                  }
                }
              } else if (map.containsKey('drawing')) {
                // Direct drawing key?
                final drawingData = map['drawing'];
                if (drawingData is Map && drawingData.containsKey('id')) {
                  scanId = drawingData['id'];
                } else if (drawingData is String) {
                  final nested = jsonDecode(drawingData);
                  if (nested is Map && nested.containsKey('id')) {
                    scanId = nested['id'];
                  }
                }
              }

              if (scanId == currentDrawingId) {
                offset = currentScanOffset;
                found = true;
                debugPrint('Found correct node at new offset: $offset');
                break;
              }
            } catch (e) {
              // debugPrint('Error parsing during scan: $e');
            }
          }
          currentScanOffset += op.length ?? 0;
        }

        if (!found) {
          debugPrint(
              'CRITICAL: Could not find original drawing node with ID: $currentDrawingId. Aborting save to prevent data loss or overwrite.');
          return;
        }
      }

      // Use the verified or corrected ID
      if (currentDrawingId.isEmpty) {
        currentDrawingId = 'gen_${DateTime.now().microsecondsSinceEpoch}';
      }

      final saveData = {
        'id': currentDrawingId,
        'points': pointsJson,
        'height': widget.height,
        'type': 'drawing'
      };

      final dataStr = jsonEncode(saveData);

      // 直接使用CustomBlockEmbed，确保数据格式一致
      final customEmbed = flutter_quill.CustomBlockEmbed('drawing', dataStr);

      // Save original state for potential rollback
      final originalDelta = controller.document.toDelta();
      final originalSelection = controller.selection;

      // 执行嵌入更新操作
      try {
        // 记录操作前的文档状态
        debugPrint(
            'Before save: document length = $docLength, offset = $offset');

        // 执行替换操作，确保只影响目标嵌入节点
        controller.replaceText(
          offset,
          1, // 嵌入节点长度始终为1
          customEmbed,
          null, // 不设置新选择，避免额外的文档变更
        );

        // 验证更新后的文档结构
        final afterDocLength = controller.document.length;
        debugPrint('After save: document length = $afterDocLength');

        // 检查文档长度是否保持不变
        if (afterDocLength != docLength) {
          debugPrint('Document length changed: $docLength -> $afterDocLength');
          // 长度变化表示文档结构被破坏，必须恢复
          controller.document = flutter_quill.Document.fromDelta(originalDelta);
          controller.updateSelection(
              originalSelection, flutter_quill.ChangeSource.local);
          debugPrint('Restored original document state due to length change');
          return;
        }

        // 验证更新后的节点是否正确
        final updatedNode = controller.document.queryChild(offset);
        if (updatedNode == null) {
          debugPrint('Node disappeared after update at offset: $offset');
          // 节点消失，恢复原始状态
          controller.document = flutter_quill.Document.fromDelta(originalDelta);
          controller.updateSelection(
              originalSelection, flutter_quill.ChangeSource.local);
          debugPrint('Restored original document state due to missing node');
          return;
        }

        debugPrint('Successfully saved drawing at offset $offset');
      } catch (e) {
        debugPrint('Error saving drawing: $e');

        // 尝试恢复到原始状态
        try {
          controller.document = flutter_quill.Document.fromDelta(originalDelta);
          controller.updateSelection(
              originalSelection, flutter_quill.ChangeSource.local);
          debugPrint('Restored original document state after error');
        } catch (e2) {
          debugPrint('Error restoring document: $e2');
        }
      }

      // 恢复原始选择
      if (originalSelection != null) {
        controller.updateSelection(
          originalSelection,
          flutter_quill.ChangeSource.local,
        );
      }
    } catch (e) {
      debugPrint('Critical error in saveDrawing: $e');
    }
  }

  void _eraseAt(Offset position) {
    final currentPoints = _pointsNotifier.value;
    if (currentPoints.isEmpty) return;

    final eraserRadiusSq = _currentWidth * _currentWidth * 4.0;
    final newPoints = <DrawingPoint>[];
    bool changed = false;

    for (var i = 0; i < currentPoints.length; i++) {
      final point = currentPoints[i];
      if (point.isEndOfStroke) {
        newPoints.add(point);
        continue;
      }

      final distSq = (point.offset - position).distanceSquared;
      if (distSq < eraserRadiusSq) {
        changed = true;
        if (newPoints.isNotEmpty && !newPoints.last.isEndOfStroke) {
          newPoints.add(DrawingPoint(
            offset: newPoints.last.offset,
            color: newPoints.last.color,
            width: newPoints.last.width,
            isEndOfStroke: true,
          ));
        }
      } else {
        newPoints.add(point);
      }
    }

    if (changed) {
      _pointsNotifier.value = newPoints;
      _debouncedSave();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toolbar
          Container(
            color: Colors.grey.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Brush button
                  ValueListenableBuilder<bool>(
                    valueListenable: _isEraserModeNotifier,
                    builder: (context, isEraserMode, child) {
                      return IconButton(
                        icon: Icon(Icons.brush,
                            size: 20,
                            color: !isEraserMode ? Colors.blue : Colors.black),
                        onPressed: () {
                          _isEraserModeNotifier.value = false;
                        },
                        tooltip: '画笔模式',
                      );
                    },
                  ),
                  // Eraser button
                  ValueListenableBuilder<bool>(
                    valueListenable: _isEraserModeNotifier,
                    builder: (context, isEraserMode, child) {
                      return IconButton(
                        icon: Icon(Icons.highlight_off,
                            size: 20,
                            color: isEraserMode ? Colors.blue : Colors.black),
                        onPressed: () {
                          _isEraserModeNotifier.value = true;
                        },
                        tooltip: '橡皮擦模式',
                      );
                    },
                  ),
                  const VerticalDivider(width: 8),
                  // Colors (Only show in brush mode)
                  ValueListenableBuilder<bool>(
                    valueListenable: _isEraserModeNotifier,
                    builder: (context, isEraserMode, child) {
                      if (!isEraserMode) {
                        return Row(
                          children: [
                            _buildColorButton(Colors.black),
                            _buildColorButton(Colors.red),
                            _buildColorButton(Colors.blue),
                            _buildColorButton(Colors.green),
                            _buildColorButton(Colors.orange),
                          ],
                        );
                      }
                      return Container();
                    },
                  ),
                  const VerticalDivider(width: 8),
                  // Width Slider
                  const Icon(Icons.line_weight, size: 16, color: Colors.grey),
                  SizedBox(
                    width: 100,
                    child: Slider(
                      value: _currentWidth,
                      min: 1.0,
                      max: 20.0,
                      onChanged: (value) {
                        setState(() {
                          _currentWidth = value;
                        });
                      },
                    ),
                  ),
                  const VerticalDivider(width: 8),
                  // Clear traces button
                  IconButton(
                    icon: const Icon(Icons.layers_clear, size: 20),
                    onPressed: () {
                      if (!_isDisposed) {
                        _pointsNotifier.value = [];
                      }
                    },
                    tooltip: '清除画布',
                  ),

                ],
              ),
            ),
          ),
          // Drawing Area
          Container(
            height: widget.height,
            width: double.infinity,
            color: Colors.white,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Drawing content
                ValueListenableBuilder<List<DrawingPoint>>(
                  valueListenable: _pointsNotifier,
                  builder: (context, points, child) {
                    return CustomPaint(
                      painter: DrawingPainter(points),
                      size: Size.infinite,
                    );
                  },
                ),
                // Drawing gesture detector
                ValueListenableBuilder<bool>(
                  valueListenable: _isEraserModeNotifier,
                  builder: (context, isEraserMode, child) {
                    return MouseRegion(
                      cursor: isEraserMode
                          ? SystemMouseCursors.cell
                          : SystemMouseCursors.precise,
                      child: GestureDetector(
                        onPanDown: (details) {
                          if (_isDisposed) return;
                          final position = details.localPosition;
                          if (!position.dx.isFinite || !position.dy.isFinite)
                            return;

                          if (isEraserMode) {
                            _isDrawing = true;
                            _eraseAt(position);
                          } else {
                            final currentPoints = _pointsNotifier.value;
                            final newPoints =
                                List<DrawingPoint>.from(currentPoints);
                            newPoints.add(DrawingPoint(
                              offset: position,
                              color: _currentColor,
                              width: _currentWidth,
                            ));
                            _pointsNotifier.value = newPoints;
                            _isDrawing = true;
                            _debouncedSave();
                          }
                        },
                        onPanUpdate: (details) {
                          if (!_isDrawing || _isDisposed) return;
                          final position = details.localPosition;
                          if (!position.dx.isFinite || !position.dy.isFinite)
                            return;

                          if (isEraserMode) {
                            _eraseAt(position);
                          } else {
                            if (position.dy >= 0 &&
                                position.dy <= widget.height &&
                                position.dx >= 0) {
                              final currentPoints = _pointsNotifier.value;
                              if (currentPoints.length >= 10000) return;

                              final newPoints =
                                  List<DrawingPoint>.from(currentPoints);
                              newPoints.add(DrawingPoint(
                                offset: position,
                                color: _currentColor,
                                width: _currentWidth,
                              ));
                              _pointsNotifier.value = newPoints;
                              _debouncedSave();
                            }
                          }
                        },
                        onPanEnd: (details) {
                          if (!_isDrawing) return;
                          if (!isEraserMode) {
                            final currentPoints = _pointsNotifier.value;
                            if (currentPoints.isNotEmpty) {
                              final newPoints =
                                  List<DrawingPoint>.from(currentPoints);
                              final lastPoint = newPoints.last;
                              newPoints.add(DrawingPoint(
                                offset: lastPoint.offset,
                                color: lastPoint.color,
                                width: lastPoint.width,
                                isEndOfStroke: true,
                              ));
                              _pointsNotifier.value = newPoints;
                              _debouncedSave();
                            }
                          }
                          _isDrawing = false;
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // Bottom clickable area
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              final controller = widget.embedContext.controller;
              final node = widget.embedContext.node;

              // Calculate the offset after this drawing embed
              // This allows users to type after the drawing
              final offset = node.documentOffset + 1;

              debugPrint('Setting cursor position to: $offset');

              // Set cursor position to just after the drawing
              controller.updateSelection(
                TextSelection.collapsed(offset: offset),
                flutter_quill.ChangeSource.local,
              );

              // Verify the selection was set correctly
              debugPrint('Selection after update: ${controller.selection}');
            },
            child: Container(
              height: 20,
              width: double.infinity,
              color: Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorButton(Color color) {
    final isSelected = _currentColor == color;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentColor = color;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: Colors.grey.shade600, width: 2)
              : Border.all(color: Colors.grey.shade300, width: 1),
        ),
      ),
    );
  }
}
