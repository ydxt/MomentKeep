import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment_keep/presentation/components/journal_editor/simple_drawing_overlay.dart';
import 'package:moment_keep/presentation/components/journal_editor/drawing_point.dart';

/// Windows端绘图崩溃测试
void main() {
  group('Windows Drawing Stability Tests', () {
    /// 测试Windows端绘制一笔后是否崩溃
    testWidgets('Windows: Draw one stroke without crash', (WidgetTester tester) async {
      debugPrint('=== Windows Drawing Test: Draw one stroke ===');
      
      // 跟踪绘图点更新
      List<DrawingPoint> receivedPoints = [];
      
      // 构建测试Widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SimpleDrawingOverlay(
              isDrawingMode: true,
              initialDrawingPoints: [],
              onDrawingUpdated: (points) {
                receivedPoints = points;
                debugPrint('Received drawing points: ${points.length}');
              },
              onExitDrawingMode: () {},
              brushColorNotifier: ValueNotifier<Color>(Colors.black),
              brushWidthNotifier: ValueNotifier<double>(3.0),
              eraserWidthNotifier: ValueNotifier<double>(3.0),
              isEraserModeNotifier: ValueNotifier<bool>(false),
              showHorizontalLinesNotifier: ValueNotifier<bool>(false),
            ),
          ),
        ),
      );
      
      // 模拟Windows端触摸事件序列
      final center = tester.getCenter(find.byType(SimpleDrawingOverlay));
      
      debugPrint('Step 1: PointerDown event');
      await tester.pump();
      await tester.startGesture(Offset(center.dx - 100, center.dy), pointer: 1);
      
      debugPrint('Step 2: PointerMove events (simulating quick drag on Windows)');
      await tester.pump();
      
      debugPrint('Step 3: PointerUp event (critical for Windows crash test)');
      await tester.pump();
      
      // 等待所有异步操作完成
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      
      debugPrint('Test completed successfully! Drawing points: ${receivedPoints.length}');
      debugPrint('=== Windows Drawing Test: Passed ===');
      
      // 验证测试结果
      expect(receivedPoints.length, greaterThan(0), reason: 'Should have received drawing points');
    });
    
    /// 测试Windows端快速绘制多笔后是否崩溃
    testWidgets('Windows: Draw multiple strokes quickly without crash', (WidgetTester tester) async {
      debugPrint('=== Windows Drawing Test: Draw multiple strokes quickly ===');
      
      // 跟踪绘图点更新
      List<DrawingPoint> receivedPoints = [];
      int updateCount = 0;
      
      // 构建测试Widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SimpleDrawingOverlay(
              isDrawingMode: true,
              initialDrawingPoints: [],
              onDrawingUpdated: (points) {
                receivedPoints = points;
                updateCount++;
                debugPrint('Update $updateCount: Received drawing points: ${points.length}');
              },
              onExitDrawingMode: () {},
              brushColorNotifier: ValueNotifier<Color>(Colors.black),
              brushWidthNotifier: ValueNotifier<double>(3.0),
              eraserWidthNotifier: ValueNotifier<double>(3.0),
              isEraserModeNotifier: ValueNotifier<bool>(false),
              showHorizontalLinesNotifier: ValueNotifier<bool>(false),
            ),
          ),
        ),
      );
      
      final center = tester.getCenter(find.byType(SimpleDrawingOverlay));
      
      // 模拟快速绘制3笔
      for (int stroke = 1; stroke <= 3; stroke++) {
        debugPrint('=== Stroke $stroke ===');
        
        // 快速绘制一笔
        await tester.pump();
        await tester.startGesture(Offset(center.dx - 100, center.dy + (stroke - 2) * 50), pointer: 1);
        await tester.pump(const Duration(milliseconds: 50)); // 模拟Windows端的短延迟
      }
      
      // 等待所有异步操作完成
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      
      debugPrint('Test completed successfully! Total drawing points: ${receivedPoints.length}, Total updates: $updateCount');
      debugPrint('=== Windows Drawing Test: Passed ===');
      
      // 验证测试结果
      expect(receivedPoints.length, greaterThan(0), reason: 'Should have received drawing points');
      expect(updateCount, greaterThan(0), reason: 'Should have received drawing updates');
    });
    
    /// 测试Windows端重新进入绘图模式绘制一笔后是否崩溃
    testWidgets('Windows: Re-enter drawing mode and draw one stroke without crash', (WidgetTester tester) async {
      debugPrint('=== Windows Drawing Test: Re-enter drawing mode ===');
      
      // 跟踪绘图点更新
      List<DrawingPoint> receivedPoints = [];
      
      // 构建测试Widget
      bool isDrawingMode = true;
      
      // 创建必需的 ValueNotifier
      final brushColorNotifier = ValueNotifier<Color>(Colors.black);
      final brushWidthNotifier = ValueNotifier<double>(3.0);
      final eraserWidthNotifier = ValueNotifier<double>(3.0);
      final isEraserModeNotifier = ValueNotifier<bool>(false);
      final showHorizontalLinesNotifier = ValueNotifier<bool>(false);
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    Expanded(
                      child: SimpleDrawingOverlay(
                        isDrawingMode: isDrawingMode,
                        initialDrawingPoints: receivedPoints,
                        onDrawingUpdated: (points) {
                          receivedPoints = points;
                          debugPrint('Received drawing points: ${points.length}');
                        },
                        onExitDrawingMode: () {
                          setState(() {
                            isDrawingMode = false;
                          });
                        },
                        brushColorNotifier: brushColorNotifier,
                        brushWidthNotifier: brushWidthNotifier,
                        eraserWidthNotifier: eraserWidthNotifier,
                        isEraserModeNotifier: isEraserModeNotifier,
                        showHorizontalLinesNotifier: showHorizontalLinesNotifier,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          isDrawingMode = !isDrawingMode;
                        });
                      },
                      child: Text(isDrawingMode ? 'Exit Drawing Mode' : 'Enter Drawing Mode'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      
      final center = tester.getCenter(find.byType(SimpleDrawingOverlay));
      
      // 第一次进入绘图模式，绘制一笔
      debugPrint('Step 1: First drawing session - draw one stroke');
      await tester.pump();
      await tester.startGesture(Offset(center.dx - 100, center.dy - 50), pointer: 1);
      await tester.pump(const Duration(milliseconds: 100));
      
      // 退出绘图模式
      debugPrint('Step 2: Exit drawing mode');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump(const Duration(milliseconds: 100));
      
      // 重新进入绘图模式
      debugPrint('Step 3: Re-enter drawing mode');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump(const Duration(milliseconds: 100));
      
      // 重新进入绘图模式后，绘制一笔（这是Windows端崩溃的关键场景）
      debugPrint('Step 4: Draw ONE stroke after re-entering (critical Windows test)');
      await tester.pump();
      await tester.startGesture(Offset(center.dx - 100, center.dy + 50), pointer: 1);
      await tester.pump(const Duration(milliseconds: 100));
      
      // 等待所有异步操作完成
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      
      debugPrint('Test completed successfully! Total drawing points: ${receivedPoints.length}');
      debugPrint('=== Windows Drawing Test: Passed ===');
      
      // 验证测试结果
      expect(receivedPoints.length, greaterThan(0), reason: 'Should have received drawing points after re-entry');
    });
    
    /// 测试Windows端重新进入绘图模式绘制一笔后是否崩溃（简化版）
    testWidgets('Windows: Simple re-enter drawing mode test', (WidgetTester tester) async {
      debugPrint('=== Windows Drawing Test: Simple re-enter drawing mode ===');
      
      // 跟踪绘图点更新
      List<DrawingPoint> receivedPoints = [];
      
      // 创建必需的 ValueNotifier
      final brushColorNotifier = ValueNotifier<Color>(Colors.black);
      final brushWidthNotifier = ValueNotifier<double>(3.0);
      final eraserWidthNotifier = ValueNotifier<double>(3.0);
      final isEraserModeNotifier = ValueNotifier<bool>(false);
      final showHorizontalLinesNotifier = ValueNotifier<bool>(false);
      
      // 构建测试Widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SimpleDrawingOverlay(
              isDrawingMode: true,
              initialDrawingPoints: [],
              onDrawingUpdated: (points) {
                receivedPoints = points;
                debugPrint('Received drawing points: ${points.length}');
              },
              onExitDrawingMode: () {},
              brushColorNotifier: brushColorNotifier,
              brushWidthNotifier: brushWidthNotifier,
              eraserWidthNotifier: eraserWidthNotifier,
              isEraserModeNotifier: isEraserModeNotifier,
              showHorizontalLinesNotifier: showHorizontalLinesNotifier,
            ),
          ),
        ),
      );
      
      final center = tester.getCenter(find.byType(SimpleDrawingOverlay));
      
      // 第一次绘制
      debugPrint('Step 1: Draw first stroke');
      await tester.pump();
      await tester.startGesture(Offset(center.dx - 100, center.dy), pointer: 1);
      await tester.pump(const Duration(milliseconds: 50));
      
      // 退出绘图模式
      debugPrint('Step 2: Exit drawing mode');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SimpleDrawingOverlay(
              isDrawingMode: false,
              initialDrawingPoints: receivedPoints,
              onDrawingUpdated: (points) {
                receivedPoints = points;
              },
              onExitDrawingMode: () {},
              brushColorNotifier: brushColorNotifier,
              brushWidthNotifier: brushWidthNotifier,
              eraserWidthNotifier: eraserWidthNotifier,
              isEraserModeNotifier: isEraserModeNotifier,
              showHorizontalLinesNotifier: showHorizontalLinesNotifier,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      
      // 重新进入绘图模式
      debugPrint('Step 3: Re-enter drawing mode');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SimpleDrawingOverlay(
              isDrawingMode: true,
              initialDrawingPoints: receivedPoints,
              onDrawingUpdated: (points) {
                receivedPoints = points;
              },
              onExitDrawingMode: () {},
              brushColorNotifier: brushColorNotifier,
              brushWidthNotifier: brushWidthNotifier,
              eraserWidthNotifier: eraserWidthNotifier,
              isEraserModeNotifier: isEraserModeNotifier,
              showHorizontalLinesNotifier: showHorizontalLinesNotifier,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      
      // 重新进入后绘制一笔
      debugPrint('Step 4: Draw stroke after re-entry');
      await tester.pump();
      await tester.startGesture(Offset(center.dx + 100, center.dy), pointer: 1);
      await tester.pump(const Duration(milliseconds: 50));
      
      // 等待所有异步操作完成
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      
      debugPrint('Test completed successfully! Total drawing points: ${receivedPoints.length}');
      debugPrint('=== Windows Drawing Test: Passed ===');
      
      // 验证测试结果
      expect(receivedPoints.length, greaterThan(0), reason: 'Should have received drawing points after re-entry');
    });
  });
}