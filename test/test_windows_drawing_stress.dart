import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moment_keep/presentation/components/journal_editor/simple_drawing_overlay.dart';
import 'package:moment_keep/presentation/components/journal_editor/drawing_point.dart';
import 'dart:async';

void main() {
  group('Windows Drawing Stress Tests', () {
    testWidgets('Stress: Rapid slider and drawing interaction',
        (WidgetTester tester) async {
      final brushWidthNotifier = ValueNotifier<double>(3.0);
      final drawingPointsNotifier = ValueNotifier<List<DrawingPoint>>([]);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SimpleDrawingOverlay(
            isDrawingMode: true,
            initialDrawingPoints: drawingPointsNotifier.value,
            brushColorNotifier: ValueNotifier<Color>(Colors.black),
            brushWidthNotifier: brushWidthNotifier,
            eraserWidthNotifier: ValueNotifier<double>(3.0),
            isEraserModeNotifier: ValueNotifier<bool>(false),
            showHorizontalLinesNotifier: ValueNotifier<bool>(false),
            onDrawingUpdated: (points) {
              drawingPointsNotifier.value = points;
            },
            onExitDrawingMode: () {},
          ),
        ),
      ));

      final center = tester.getCenter(find.byType(SimpleDrawingOverlay));
      final gesture = await tester.startGesture(center);

      // Simulate rapid slider changes and movements
      for (int i = 0; i < 50; i++) {
        brushWidthNotifier.value = 1.0 + (i % 19);
        await gesture.moveTo(Offset(center.dx + i, center.dy + i));
        await tester.pump();
      }

      await gesture.up();
      await tester.pumpAndSettle();

      expect(drawingPointsNotifier.value.length, greaterThan(0));
    });

    testWidgets('Stress: Rapid eraser scrubbing', (WidgetTester tester) async {
      final points = List.generate(
          1000,
          (i) => DrawingPoint(
                offset: Offset(i.toDouble(), 100),
                color: Colors.black,
                width: 3.0,
                isEndOfStroke: i % 10 == 9,
              ));

      final isEraserModeNotifier = ValueNotifier<bool>(true);
      final drawingPointsNotifier = ValueNotifier<List<DrawingPoint>>(points);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SimpleDrawingOverlay(
            isDrawingMode: true,
            initialDrawingPoints: points,
            brushColorNotifier: ValueNotifier<Color>(Colors.black),
            brushWidthNotifier: ValueNotifier<double>(3.0),
            eraserWidthNotifier: ValueNotifier<double>(3.0),
            isEraserModeNotifier: isEraserModeNotifier,
            showHorizontalLinesNotifier: ValueNotifier<bool>(false),
            onDrawingUpdated: (updatedPoints) {
              drawingPointsNotifier.value = updatedPoints;
            },
            onExitDrawingMode: () {},
          ),
        ),
      ));

      final center = tester.getCenter(find.byType(SimpleDrawingOverlay));

      // Perform rapid eraser scrubbing
      for (int i = 0; i < 100; i++) {
        await tester.dragFrom(
          Offset(i.toDouble(), 100),
          const Offset(5, 5),
        );
        await tester.pump();
      }

      await tester.pumpAndSettle();
    });
  });
}
