import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../demo/hiveflow_demo.dart';
import '../theme/hiveflow_palette.dart';

class WarehouseMap extends StatelessWidget {
  const WarehouseMap({
    required this.robots,
    required this.isAisleBlocked,
    required this.mode,
    super.key,
  });

  final List<FleetRobot> robots;
  final bool isAisleBlocked;
  final PlannerMode mode;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WarehousePainter(
        robots: robots,
        isAisleBlocked: isAisleBlocked,
        mode: mode,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _WarehousePainter extends CustomPainter {
  const _WarehousePainter({
    required this.robots,
    required this.isAisleBlocked,
    required this.mode,
  });

  final List<FleetRobot> robots;
  final bool isAisleBlocked;
  final PlannerMode mode;

  static const _cols = 16;
  static const _rows = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / _cols;
    final cellHeight = size.height / _rows;
    final cellSize = Size(cellWidth, cellHeight);

    final gridPaint = Paint()
      ..color = const Color(0xFF24364A)
      ..strokeWidth = 0.7;
    for (var x = 0; x <= _cols; x++) {
      canvas.drawLine(
        Offset(x * cellWidth, 0),
        Offset(x * cellWidth, size.height),
        gridPaint,
      );
    }
    for (var y = 0; y <= _rows; y++) {
      canvas.drawLine(
        Offset(0, y * cellHeight),
        Offset(size.width, y * cellHeight),
        gridPaint,
      );
    }

    _drawShelves(canvas, cellWidth, cellHeight, cellSize);
    _drawRoute(canvas, cellWidth, cellHeight);
    if (isAisleBlocked) {
      _drawBlockMarker(canvas, cellWidth, cellHeight);
    }
    _drawStations(canvas, cellWidth, cellHeight);
    for (final robot in robots) {
      _drawRobot(canvas, cellWidth, cellHeight, cellSize, robot);
    }
  }

  void _drawShelves(
    Canvas canvas,
    double cellWidth,
    double cellHeight,
    Size cellSize,
  ) {
    const shelfColumns = [3, 6, 9, 12];
    final shelfPaint = Paint()..color = const Color(0xFF1A2A3B);
    final shelfEdge = Paint()
      ..color = const Color(0xFF2E4358)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final column in shelfColumns) {
      for (final startRow in [1, 5]) {
        const height = 3;
        final rect = Rect.fromLTWH(
          column * cellWidth + cellWidth * 0.12,
          startRow * cellHeight + cellHeight * 0.12,
          cellWidth * 0.76,
          height * cellHeight * 0.76,
        );
        final rounded = RRect.fromRectAndRadius(
          rect,
          Radius.circular(cellWidth * 0.16),
        );
        canvas.drawRRect(rounded, shelfPaint);
        canvas.drawRRect(rounded, shelfEdge);
        _drawLabel(
          canvas,
          'RACK ${column.toString().padLeft(2, '0')}',
          Offset(rect.left + 3, rect.top + 4),
          HiveFlowPalette.muted.withValues(alpha: 0.6),
          fontSize: 6,
          bold: true,
        );
        for (var shelf = 1; shelf <= 2; shelf++) {
          final shelfY = rect.top + rect.height * shelf / 3;
          canvas.drawLine(
            Offset(rect.left + 3, shelfY),
            Offset(rect.right - 3, shelfY),
            shelfEdge,
          );
        }
      }
    }
  }

  void _drawRoute(Canvas canvas, double cellWidth, double cellHeight) {
    for (final robot in robots) {
      if (robot.state == RobotState.failed || robot.path.length < 2) continue;
      final color = mode == PlannerMode.hiveflow
          ? _robotColor(robot.id)
          : HiveFlowPalette.subtle;
      final path = Path();
      final points = <Offset>[];
      for (final point in robot.path) {
        points.add(
          Offset((point.x + 0.5) * cellWidth, (point.y + 0.5) * cellHeight),
        );
      }
      for (var index = 0; index < points.length; index++) {
        if (index == 0) {
          path.moveTo(points[index].dx, points[index].dy);
        } else {
          path.lineTo(points[index].dx, points[index].dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = HiveFlowPalette.canvas.withValues(alpha: 0.92)
          ..strokeWidth = 6
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.95)
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      _drawRouteArrow(canvas, points, color);
    }
  }

  void _drawRouteArrow(Canvas canvas, List<Offset> points, Color color) {
    if (points.length < 2) return;
    final previous = points[points.length - 2];
    final target = points.last;
    final direction = target - previous;
    if (direction.distance == 0) return;
    final unit = direction / direction.distance;
    final perpendicular = Offset(-unit.dy, unit.dx);
    final tip = target - unit * 7;
    final arrow = Path()
      ..moveTo(tip.dx + unit.dx * 4, tip.dy + unit.dy * 4)
      ..lineTo(
        tip.dx - unit.dx * 5 + perpendicular.dx * 4,
        tip.dy - unit.dy * 5 + perpendicular.dy * 4,
      )
      ..lineTo(
        tip.dx - unit.dx * 5 - perpendicular.dx * 4,
        tip.dy - unit.dy * 5 - perpendicular.dy * 4,
      )
      ..close();
    canvas.drawPath(arrow, Paint()..color = color);
  }

  void _drawBlockMarker(Canvas canvas, double cellWidth, double cellHeight) {
    final blockPaint = Paint()
      ..color = HiveFlowPalette.red.withValues(alpha: 0.16);
    canvas.drawRect(
      Rect.fromLTWH(7 * cellWidth, 4 * cellHeight, cellWidth, cellHeight),
      blockPaint,
    );
    final blockRect = Rect.fromLTWH(
      7 * cellWidth,
      4 * cellHeight,
      cellWidth,
      cellHeight,
    );
    canvas.drawLine(
      blockRect.topLeft,
      blockRect.bottomRight,
      Paint()
        ..color = HiveFlowPalette.red
        ..strokeWidth = 2.6,
    );
    canvas.drawLine(
      blockRect.topRight,
      blockRect.bottomLeft,
      Paint()
        ..color = HiveFlowPalette.red
        ..strokeWidth = 2.6,
    );
  }

  void _drawStations(Canvas canvas, double cellWidth, double cellHeight) {
    _drawStation(
      canvas,
      Offset(0.55 * cellWidth, 0.55 * cellHeight),
      'IN',
      HiveFlowPalette.blue,
    );
    _drawStation(
      canvas,
      Offset(15.45 * cellWidth, 9.35 * cellHeight),
      'OUT',
      HiveFlowPalette.lime,
    );
  }

  void _drawStation(Canvas canvas, Offset center, String label, Color color) {
    final paint = Paint()..color = color.withValues(alpha: 0.16);
    canvas.drawCircle(center, 13, paint);
    final marker = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 18, height: 18),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      marker,
      Paint()
        ..color = HiveFlowPalette.surfaceRaised
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      marker,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    _drawLabel(
      canvas,
      label == 'IN' ? '↓' : '↑',
      center,
      color,
      fontSize: 11,
      bold: true,
      centered: true,
    );
    _drawLabel(
      canvas,
      label,
      Offset(center.dx + 2, center.dy - 17),
      color,
      fontSize: 8,
      bold: true,
    );
  }

  void _drawRobot(
    Canvas canvas,
    double cellWidth,
    double cellHeight,
    Size cellSize,
    FleetRobot robot,
  ) {
    final center = Offset(
      (robot.position.x + 0.5) * cellWidth,
      (robot.position.y + 0.5) * cellHeight,
    );
    final color = robot.state == RobotState.failed
        ? HiveFlowPalette.red
        : _robotColor(robot.id);
    final width = (cellSize.shortestSide * 0.8).clamp(20.0, 30.0);
    final height = (cellSize.shortestSide * 0.62).clamp(16.0, 23.0);
    final heading = _robotHeading(robot);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(heading);
    canvas.drawCircle(
      Offset.zero,
      width * 0.68,
      Paint()..color = color.withValues(alpha: 0.14),
    );
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: width, height: height),
      const Radius.circular(6),
    );
    final wheels = Paint()..color = HiveFlowPalette.canvas;
    for (final side in [-1.0, 1.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(side * width * 0.33, 0),
            width: 4,
            height: height * 0.76,
          ),
          const Radius.circular(2),
        ),
        wheels,
      );
    }
    canvas.drawRRect(body, Paint()..color = color);
    canvas.drawRRect(
      body,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 1.7
        ..style = PaintingStyle.stroke,
    );
    final deck = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: width * 0.33,
        height: height * 0.48,
      ),
      const Radius.circular(2),
    );
    canvas.drawRRect(deck, Paint()..color = HiveFlowPalette.sidebar);
    canvas.drawRRect(
      deck,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    final nose = Path()
      ..moveTo(width * 0.5, 0)
      ..lineTo(width * 0.5 - 5, -4)
      ..lineTo(width * 0.5 - 5, 4)
      ..close();
    canvas.drawPath(nose, Paint()..color = HiveFlowPalette.text);
    canvas.restore();

    _drawPin(
      canvas,
      Offset(
        (robot.goal.x + 0.5) * cellWidth,
        (robot.goal.y + 0.5) * cellHeight,
      ),
      cellSize,
      robot,
      color,
    );
    _drawRobotLabel(canvas, center, cellSize, robot, color);
  }

  double _robotHeading(FleetRobot robot) {
    if (robot.path.length < 2) return 0;
    final next = robot.path[1];
    if (next.x > robot.position.x) return 0;
    if (next.x < robot.position.x) return math.pi;
    if (next.y > robot.position.y) return math.pi / 2;
    if (next.y < robot.position.y) return -math.pi / 2;
    return 0;
  }

  void _drawPin(
    Canvas canvas,
    Offset center,
    Size cellSize,
    FleetRobot robot,
    Color color,
  ) {
    final pinCenter = center + Offset(0, -cellSize.height * 0.19);
    final pin = Path()
      ..moveTo(pinCenter.dx, pinCenter.dy + 6)
      ..cubicTo(
        pinCenter.dx - 8,
        pinCenter.dy - 3,
        pinCenter.dx - 5,
        pinCenter.dy - 11,
        pinCenter.dx,
        pinCenter.dy - 11,
      )
      ..cubicTo(
        pinCenter.dx + 5,
        pinCenter.dy - 11,
        pinCenter.dx + 8,
        pinCenter.dy - 3,
        pinCenter.dx,
        pinCenter.dy + 6,
      )
      ..close();
    canvas.drawPath(
      pin,
      Paint()..color = HiveFlowPalette.canvas.withValues(alpha: 0.92),
    );
    canvas.drawPath(pin, Paint()..color = color);
    canvas.drawCircle(
      Offset(pinCenter.dx, pinCenter.dy - 3),
      2,
      Paint()..color = HiveFlowPalette.sidebar,
    );
    _drawLabel(
      canvas,
      'P',
      Offset(pinCenter.dx, pinCenter.dy - 3),
      HiveFlowPalette.text,
      fontSize: 4,
      bold: true,
      centered: true,
    );
  }

  void _drawRobotLabel(
    Canvas canvas,
    Offset center,
    Size cellSize,
    FleetRobot robot,
    Color color,
  ) {
    final text = robot.id;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: HiveFlowPalette.text,
          fontSize: 7,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final width = painter.width + 8;
    final height = painter.height + 5;
    final rect = Rect.fromCenter(
      center: center + Offset(0, cellSize.height * 0.34),
      width: width,
      height: height,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = HiveFlowPalette.canvas.withValues(alpha: 0.96),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()
        ..color = color.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    painter.paint(
      canvas,
      Offset(
        rect.center.dx - painter.width / 2,
        rect.center.dy - painter.height / 2,
      ),
    );
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset offset,
    Color color, {
    double fontSize = 10,
    bool bold = false,
    bool centered = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      centered
          ? Offset(
              offset.dx - painter.width / 2,
              offset.dy - painter.height / 2,
            )
          : offset,
    );
  }

  Color _robotColor(String id) {
    final colors = [
      HiveFlowPalette.mint,
      HiveFlowPalette.blue,
      HiveFlowPalette.amber,
      HiveFlowPalette.violet,
      const Color(0xFF4DE3D1),
      const Color(0xFFFF8FA3),
      const Color(0xFFB8F28B),
      const Color(0xFF86A7FF),
    ];
    final index = int.tryParse(id.substring(2)) ?? 1;
    return colors[(index - 1) % colors.length];
  }

  @override
  bool shouldRepaint(covariant _WarehousePainter oldDelegate) {
    return oldDelegate.robots != robots ||
        oldDelegate.isAisleBlocked != isAisleBlocked ||
        oldDelegate.mode != mode;
  }
}
