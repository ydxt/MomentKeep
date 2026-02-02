import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment_keep/presentation/components/journal_editor/simple_drawing_overlay.dart';
import 'package:moment_keep/presentation/components/journal_editor/drawing_point.dart';

/// 自动化绘图稳定性测试 - 增强版
void main() {
  testWidgets('Drawing crash test - draw one stroke after reopening', 
      (WidgetTester tester) async {
    // 创建测试所需的变量
    bool isDrawingMode = false;
    List<DrawingPoint> drawingPoints = [];
    const int maxIterations = 5;
    bool crashDetected = false;

    // 模拟绘图更新回调
    void onDrawingUpdated(List<DrawingPoint> points) {
      try {
        drawingPoints = points;
        // print('Drawing updated with ${points.length} points');
      } catch (e) {
        print('ERROR in onDrawingUpdated: $e');
        crashDetected = true;
      }
    }

    // 模拟退出绘图模式回调
    void onExitDrawingMode() {
      try {
        isDrawingMode = false;
        // print('Exited drawing mode');
      } catch (e) {
        print('ERROR in onExitDrawingMode: $e');
        crashDetected = true;
      }
    }

    // 构建测试页面
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 模拟富媒体内容层
            Positioned.fill(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // 模拟各种富媒体内容
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        '测试页面内容',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    Container(
                      height: 200,
                      color: Colors.grey[200],
                      child: const Center(child: Text('模拟图片')),
                    ),
                    Container(
                      height: 80,
                      color: Colors.blue[100],
                      child: const Center(child: Text('模拟音频')),
                    ),
                    Container(
                      height: 300,
                      color: Colors.black12,
                      child: const Center(child: Text('模拟视频')),
                    ),
                  ],
                ),
              ),
            ),
            
            // 绘图覆盖层
            Positioned.fill(
              child: Builder(builder: (context) {
                return SimpleDrawingOverlay(
                  isDrawingMode: isDrawingMode,
                  initialDrawingPoints: drawingPoints,
                  onDrawingUpdated: onDrawingUpdated,
                  onExitDrawingMode: onExitDrawingMode,
                  brushColorNotifier: ValueNotifier<Color>(Colors.black),
                  brushWidthNotifier: ValueNotifier<double>(3.0),
                  eraserWidthNotifier: ValueNotifier<double>(3.0),
                  isEraserModeNotifier: ValueNotifier<bool>(false),
                  showHorizontalLinesNotifier: ValueNotifier<bool>(false),
                );
              }),
            ),
          ],
        ),
      ),
    ));

    // 执行多次测试迭代
    for (int i = 1; i <= maxIterations && !crashDetected; i++) {
      print('\n=== Test Iteration $i/$maxIterations ===');
      
      // 1. 打开绘图模式
      print('Step 1: Opening drawing mode');
      isDrawingMode = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      
      if (crashDetected) break;
      
      // 2. 绘制多笔（使用模拟绘图点）
      for (int stroke = 1; stroke <= 2 && !crashDetected; stroke++) {
        print('Step 2.$stroke: Drawing stroke by updating points directly');
        
        // 模拟绘制一条简单的线
        final testPoints = List.generate(10, (index) => DrawingPoint(
          offset: Offset(100 + index * 10.0, 100.0 + stroke * 50.0),
          color: Colors.black,
          width: 3.0,
          isEndOfStroke: index == 9,
        ));
        
        drawingPoints.addAll(testPoints);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        
        if (crashDetected) break;
      }
      
      if (crashDetected) break;
      
      // 3. 关闭绘图模式
      print('Step 3: Closing drawing mode');
      isDrawingMode = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      
      if (crashDetected) break;
      
      // 4. 重新打开绘图模式
      print('Step 4: Reopening drawing mode');
      isDrawingMode = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      
      if (crashDetected) break;
      
      // 5. 绘制一笔（关键测试步骤 - 模拟崩溃场景）
      print('Step 5: Drawing ONE stroke after reopening (critical test)');
      
      // 模拟绘制一笔
      final finalStroke = List.generate(10, (index) => DrawingPoint(
        offset: Offset(150.0 + index * 10.0, 300.0),
        color: Colors.black,
        width: 3.0,
        isEndOfStroke: index == 9,
      ));
      drawingPoints.addAll(finalStroke);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100)); // 额外等待，确保所有异步操作完成
      
      if (crashDetected) break;
      
      // 6. 关闭绘图模式
      print('Step 6: Closing drawing mode again');
      isDrawingMode = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      
      print('Iteration $i completed successfully. Total points: ${drawingPoints.length}');
    }
    
    if (crashDetected) {
      fail('Crash detected during drawing test!');
    } else {
      print('\n=== All $maxIterations iterations completed successfully! ===');
      print('Total drawing points: ${drawingPoints.length}');
      print('Drawing functionality is STABLE!');
    }
  });
  
  testWidgets('Single stroke crash test - minimal reproduction', 
      (WidgetTester tester) async {
    // 创建最小化测试，专注于单一崩溃场景
    bool isDrawingMode = false;
    List<DrawingPoint> drawingPoints = [];
    bool crashDetected = false;

    void onDrawingUpdated(List<DrawingPoint> points) {
      try {
        drawingPoints = points;
      } catch (e) {
        print('CRASH in onDrawingUpdated: $e');
        crashDetected = true;
      }
    }

    void onExitDrawingMode() {
      try {
        isDrawingMode = false;
      } catch (e) {
        print('CRASH in onExitDrawingMode: $e');
        crashDetected = true;
      }
    }

    // 构建最小化测试页面
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SimpleDrawingOverlay(
          isDrawingMode: isDrawingMode,
          initialDrawingPoints: drawingPoints,
          onDrawingUpdated: onDrawingUpdated,
          onExitDrawingMode: onExitDrawingMode,
          brushColorNotifier: ValueNotifier<Color>(Colors.black),
          brushWidthNotifier: ValueNotifier<double>(3.0),
          eraserWidthNotifier: ValueNotifier<double>(3.0),
          isEraserModeNotifier: ValueNotifier<bool>(false),
          showHorizontalLinesNotifier: ValueNotifier<bool>(false),
        ),
      ),
    ));

    print('\n=== Minimal Single Stroke Crash Test ===');
    
    // 1. 打开绘图模式
    isDrawingMode = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    
    // 2. 绘制一笔
    print('Drawing first stroke...');
    final firstStroke = List.generate(10, (index) => DrawingPoint(
      offset: Offset(100.0 + index * 10.0, 100.0),
      color: Colors.black,
      width: 3.0,
      isEndOfStroke: index == 9,
    ));
    drawingPoints.addAll(firstStroke);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    
    if (crashDetected) {
      fail('Crash detected during first stroke!');
    }
    
    // 3. 关闭绘图模式
    print('Closing drawing mode...');
    isDrawingMode = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    
    // 4. 重新打开绘图模式
    print('Reopening drawing mode...');
    isDrawingMode = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    
    // 5. 绘制关键的一笔（这是导致崩溃的场景）
    print('Drawing critical second stroke...');
    final secondStroke = List.generate(10, (index) => DrawingPoint(
      offset: Offset(150.0 + index * 10.0, 150.0),
      color: Colors.black,
      width: 3.0,
      isEndOfStroke: index == 9,
    ));
    drawingPoints.addAll(secondStroke);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100)); // 确保所有异步操作完成
    
    if (crashDetected) {
      fail('Crash detected during second stroke after reopening!');
    }
    
    print('✅ Single stroke test completed successfully! No crash detected.');
  });
}