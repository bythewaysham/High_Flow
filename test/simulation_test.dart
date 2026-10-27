import 'package:flutter_test/flutter_test.dart';
import 'package:highflow/demo/hiveflow_demo.dart';
import 'package:highflow/simulation/warehouse_planner.dart';

void main() {
  group('Hungarian assignment', () {
    test('finds the minimum total cost assignment', () {
      const costs = [
        [4.0, 1.0, 3.0],
        [2.0, 0.0, 5.0],
        [3.0, 2.0, 2.0],
      ];

      final result = HungarianAssignment.solve(costs);

      expect(result, [1, 0, 2]);
      expect(
        List.generate(
          costs.length,
          (row) => costs[row][result[row]],
        ).reduce((first, second) => first + second),
        5,
      );
    });

    test('handles fewer jobs than robots', () {
      const costs = [
        [8.0],
        [2.0],
        [4.0],
      ];

      final result = HungarianAssignment.solve(costs);

      expect(result, [-1, 0, -1]);
    });

    test('rejects ragged cost matrices', () {
      expect(
        () => HungarianAssignment.solve([
          [1, 2],
          [3],
        ]),
        throwsArgumentError,
      );
    });
  });

  group('space-time route planning', () {
    const planner = SpaceTimePlanner();

    test('books routes without vertex or edge-swap conflicts', () {
      final reservations = ReservationTable();
      final firstPath = planner.findPath(
        start: const GridPoint(1, 4),
        goal: const GridPoint(14, 4),
        reservations: reservations,
        blocked: const {},
        useReservations: true,
        robotId: 'R-01',
      );
      expect(firstPath, isNotNull);
      reservations.reservePath('R-01', firstPath!, planner.horizon);

      final secondPath = planner.findPath(
        start: const GridPoint(14, 4),
        goal: const GridPoint(1, 4),
        reservations: reservations,
        blocked: const {},
        useReservations: true,
        robotId: 'R-02',
      );
      expect(secondPath, isNotNull);

      expect(
        planner.countConflicts({'R-01': firstPath, 'R-02': secondPath!}),
        0,
      );
    });

    test('routes around a blocked aisle and keeps wait steps valid', () {
      final path = planner.findPath(
        start: const GridPoint(4, 4),
        goal: const GridPoint(11, 4),
        reservations: ReservationTable(),
        blocked: {SpaceTimePlanner.aisleBlock},
        useReservations: false,
      );

      expect(path, isNotNull);
      expect(path, isNot(contains(SpaceTimePlanner.aisleBlock)));
    });

    test('lets a robot leave a cell that becomes blocked underneath it', () {
      final path = planner.findPath(
        start: SpaceTimePlanner.aisleBlock,
        goal: const GridPoint(8, 4),
        reservations: ReservationTable(),
        blocked: {SpaceTimePlanner.aisleBlock},
        useReservations: true,
        robotId: 'R-01',
      );

      expect(path, isNotNull);
      expect(path!.first, SpaceTimePlanner.aisleBlock);
      expect(path.last, const GridPoint(8, 4));
      expect(path.skip(1), isNot(contains(SpaceTimePlanner.aisleBlock)));
    });

    test('counts vertex collisions but not a robot waiting alone', () {
      expect(
        planner.countConflicts({
          'R-01': const [GridPoint(1, 1), GridPoint(1, 1)],
          'R-02': const [GridPoint(2, 1), GridPoint(2, 1)],
        }),
        0,
      );
      expect(
        planner.countConflicts({
          'R-01': const [GridPoint(1, 1), GridPoint(2, 1)],
          'R-02': const [GridPoint(3, 1), GridPoint(2, 1)],
        }),
        1,
      );
    });
  });

  group('local fleet simulation', () {
    late HiveFlowDemoController controller;

    setUp(() {
      controller = HiveFlowDemoController(autoStart: false);
    });

    tearDown(() {
      controller.dispose();
    });

    test('starts with deterministic assignments and conflict-free HiveFlow routes', () {
      expect(controller.isInitialized, isTrue);
      expect(controller.robots, hasLength(8));
      expect(
        controller.movingRobots,
        8,
        reason: controller.robots
            .map(
              (robot) =>
                  '${robot.id}: ${robot.state} task=${robot.task} position=(${robot.position.x},${robot.position.y}) goal=(${robot.goal.x},${robot.goal.y})',
            )
            .join(' | '),
      );
      expect(controller.hiveFlowComparisonConflicts, 0);
      expect(
        controller.robots.map((robot) => robot.task).toSet(),
        hasLength(8),
      );
      expect(
        controller.decisions.any(
          (decision) =>
              decision.title.startsWith('R-') &&
              decision.title.contains('assigned'),
        ),
        isTrue,
      );
    });

    test('a blocked aisle updates the route and decision log', () {
      controller.applyEvent(DemoEvent.blockAisle);

      expect(controller.isAisleBlocked, isTrue);
      expect(controller.lastEvent, contains('Aisle 3 blocked'));
      expect(controller.decisions.first.title, 'Aisle 3 marked blocked');
      expect(controller.hiveFlowComparisonConflicts, 0);
      for (final robot in controller.robots) {
        expect(robot.path, isNot(contains(SpaceTimePlanner.aisleBlock)));
      }
    });

    test('a failed robot transfers its order to another robot', () {
      final taskBeforeFailure = controller.robots.first.task;

      controller.applyEvent(DemoEvent.robotFailure);

      expect(controller.activeRobots, 7);
      expect(
        controller.robots.where((robot) => robot.state == RobotState.failed),
        hasLength(1),
      );
      expect(
        controller.robots.any(
          (robot) =>
              robot.state != RobotState.failed &&
              robot.task == taskBeforeFailure,
        ),
        isTrue,
      );
      expect(controller.hiveFlowComparisonConflicts, 0);
    });

    test('a rush order is assigned and explained', () {
      controller.applyEvent(DemoEvent.rushOrder);

      expect(controller.rushOrders, 1);
      expect(controller.robots.any((robot) => robot.isRush), isTrue);
      expect(
        controller.decisions.any(
          (decision) => decision.title.contains('prioritized'),
        ),
        isTrue,
      );
      expect(controller.hiveFlowComparisonConflicts, 0);
    });

    test('the running simulation stays conflict-free as orders repeat', () async {
      final runningController = HiveFlowDemoController();
      try {
        await Future<void>.delayed(const Duration(seconds: 9));

        expect(
          runningController.routeConflicts,
          0,
          reason: runningController.robots
              .map(
                (robot) =>
                    '${robot.id} ${robot.position} ${robot.state} ${robot.path}',
              )
              .join(' | '),
        );
        expect(runningController.activeRobots, 8);
        expect(runningController.completedOrders, greaterThan(0));
      } finally {
        runningController.dispose();
      }
    });
  });
}
