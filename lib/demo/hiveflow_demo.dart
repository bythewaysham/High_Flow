import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../simulation/warehouse_planner.dart';

export '../simulation/warehouse_planner.dart' show GridPoint;

enum PlannerMode { hiveflow, baseline }

enum RobotState { moving, picking, idle, failed }

enum DemoEvent { blockAisle, robotFailure, rushOrder }

class FleetRobot {
  const FleetRobot({
    required this.id,
    required this.position,
    required this.battery,
    required this.state,
    required this.task,
    this.load = '',
    required this.path,
    required this.goal,
    this.isRush = false,
  });

  final String id;
  final GridPoint position;
  final int battery;
  final RobotState state;
  final String task;
  final String load;
  final List<GridPoint> path;
  final GridPoint goal;
  final bool isRush;

  FleetRobot copyWith({
    GridPoint? position,
    int? battery,
    RobotState? state,
    String? task,
    String? load,
    List<GridPoint>? path,
    GridPoint? goal,
    bool? isRush,
  }) {
    return FleetRobot(
      id: id,
      position: position ?? this.position,
      battery: battery ?? this.battery,
      state: state ?? this.state,
      task: task ?? this.task,
      load: load ?? this.load,
      path: path ?? this.path,
      goal: goal ?? this.goal,
      isRush: isRush ?? this.isRush,
    );
  }
}

class DecisionEntry {
  const DecisionEntry({
    required this.title,
    required this.description,
    required this.time,
    required this.icon,
    required this.color,
  });

  final String title;
  final String description;
  final String time;
  final IconData icon;
  final int color;
}

class HiveFlowDemoController extends ChangeNotifier {
  HiveFlowDemoController({bool autoStart = true}) : _autoStart = autoStart {
    reset(notify: false);
    if (autoStart) _startTimer();
  }

  static const _planner = SpaceTimePlanner();
  static const _blockedCell = SpaceTimePlanner.aisleBlock;

  final bool _autoStart;
  final List<_FleetTask> _queuedTasks = [];
  final Map<String, int> _pickCountdowns = {};
  Timer? _timer;
  int _runTicks = 0;
  int _nextRushNumber = 1;
  int _nextBatchNumber = 1;
  bool _initialized = false;
  bool _disposed = false;

  PlannerMode mode = PlannerMode.hiveflow;
  bool isRunning = true;
  bool isAisleBlocked = false;
  int rushOrders = 0;
  int completedOrders = 0;
  int distanceTravelled = 0;
  int activeTab = 0;
  int routeConflicts = 0;
  String lastEvent = 'Simulation ready · local sample fleet';

  late List<FleetRobot> robots;
  late List<DecisionEntry> decisions;
  Map<String, List<GridPoint>> hiveFlowComparisonPaths = {};
  Map<String, List<GridPoint>> baselineComparisonPaths = {};

  int get activeRobots =>
      robots.where((robot) => robot.state != RobotState.failed).length;

  int get movingRobots =>
      robots.where((robot) => robot.state == RobotState.moving).length;

  int get hiveFlowComparisonConflicts =>
      _planner.countConflicts(hiveFlowComparisonPaths);

  int get baselineComparisonConflicts =>
      _planner.countConflicts(baselineComparisonPaths);

  bool get isInitialized => _initialized;

  Set<GridPoint> get _blockedCells =>
      isAisleBlocked ? {_blockedCell} : const {};

  List<FleetRobot> comparisonRobots(PlannerMode plannerMode) {
    final paths = plannerMode == PlannerMode.hiveflow
        ? hiveFlowComparisonPaths
        : baselineComparisonPaths;
    return [
      for (final robot in robots)
        robot.copyWith(path: paths[robot.id] ?? [robot.position]),
    ];
  }

  void setTab(int index) {
    activeTab = index;
    notifyListeners();
  }

  void setMode(PlannerMode value) {
    if (mode == value) return;
    mode = value;
    _planAffected(robots.map((robot) => robot.id).toSet());
    _record(
      title: value == PlannerMode.hiveflow
          ? 'HiveFlow planner selected'
          : 'Baseline planner selected',
      description: value == PlannerMode.hiveflow
          ? 'Routes use space-time reservations, including wait steps and edge-swap checks.'
          : 'Routes use shortest paths without fleet reservations; collisions are measured in the preview.',
      icon: Icons.route_rounded,
      color: 0xFF5C83D6,
    );
    lastEvent = '${value.name} planner · local simulation';
    notifyListeners();
  }

  void toggleRun() {
    isRunning = !isRunning;
    if (isRunning) _startTimer();
    lastEvent = isRunning
        ? 'Simulation running · local sample fleet'
        : 'Simulation paused';
    notifyListeners();
  }

  void applyEvent(DemoEvent event) {
    switch (event) {
      case DemoEvent.blockAisle:
        _toggleAisleBlock();
        break;
      case DemoEvent.robotFailure:
        _simulateRobotFailure();
        break;
      case DemoEvent.rushOrder:
        _addRushOrder();
        break;
    }

    notifyListeners();
  }

  void _toggleAisleBlock() {
    isAisleBlocked = !isAisleBlocked;
    if (isAisleBlocked) {
      final affected = robots
          .where(
            (robot) =>
                robot.state != RobotState.failed &&
                robot.path.contains(_blockedCell),
          )
          .map((robot) => robot.id)
          .toSet();
      _planAffected(
        mode == PlannerMode.hiveflow
            ? affected
            : robots.map((robot) => robot.id).toSet(),
      );
      final robotLabel = affected.isEmpty
          ? 'No current route crossed the blocked cell.'
          : '${affected.length} affected robot${affected.length == 1 ? '' : 's'} replanned; other HiveFlow routes were kept.';
      _record(
        title: 'Aisle 3 marked blocked',
        description:
            '$robotLabel This local simulation does not control hardware.',
        icon: Icons.block_rounded,
        color: 0xFFE99B47,
      );
      lastEvent = 'Aisle 3 blocked · local simulation';
    } else {
      _planAffected(robots.map((robot) => robot.id).toSet());
      _record(
        title: 'Aisle 3 reopened',
        description: 'Routes were planned again around the open aisle.',
        icon: Icons.check_circle_outline_rounded,
        color: 0xFF3B8E75,
      );
      lastEvent = 'Aisle 3 reopened · local simulation';
    }
  }

  void _simulateRobotFailure() {
    final failedIndex = robots.indexWhere(
      (robot) => robot.state != RobotState.failed,
    );
    if (failedIndex < 0) {
      _record(
        title: 'No robot available to fail',
        description: 'All sample robots are already unavailable.',
        icon: Icons.info_outline,
        color: 0xFFE99B47,
      );
      lastEvent = 'All sample robots are unavailable';
      return;
    }

    final failedRobot = robots[failedIndex];
    final failedTask = _taskFromRobot(failedRobot);
    robots[failedIndex] = failedRobot.copyWith(
      state: RobotState.failed,
      path: [failedRobot.position],
    );
    final available = robots
        .where((robot) => robot.state != RobotState.failed)
        .toList();

    if (failedTask != null && available.isNotEmpty) {
      final costs = available
          .map((robot) => [_assignmentCost(robot, failedTask)])
          .toList();
      final matching = HungarianAssignment.solve(costs);
      final replacementIndex = matching.indexOf(0);
      final replacement = available[replacementIndex];
      final originalIndex = robots.indexWhere(
        (robot) => robot.id == replacement.id,
      );
      final replacedTask = _taskFromRobot(replacement);
      if (replacedTask != null) _queuedTasks.add(replacedTask);

      final taskCompletedAtReplacement =
          replacement.position == failedTask.goal;
      if (taskCompletedAtReplacement) {
        completedOrders++;
        if (failedTask.isRush && rushOrders > 0) rushOrders--;
      }
      robots[originalIndex] = replacement.copyWith(
        task: taskCompletedAtReplacement ? 'STANDBY' : failedRobot.task,
        load: taskCompletedAtReplacement ? '' : failedTask.load,
        goal: taskCompletedAtReplacement
            ? replacement.position
            : failedTask.goal,
        isRush: taskCompletedAtReplacement ? false : failedTask.isRush,
        state: taskCompletedAtReplacement ? RobotState.idle : RobotState.moving,
        path: taskCompletedAtReplacement
            ? [replacement.position]
            : replacement.path,
      );
      if (mode == PlannerMode.hiveflow) {
        if (!taskCompletedAtReplacement) {
          _planAffected({replacement.id});
        } else {
          _refreshReservationsAndConflicts();
        }
      } else {
        _planAffected(robots.map((robot) => robot.id).toSet());
      }

      _record(
        title: '${failedRobot.id} reported unavailable',
        description: taskCompletedAtReplacement
            ? '${failedRobot.task} was transferred to ${replacement.id}, who was already at its destination.'
            : '${failedRobot.task} was reassigned to ${replacement.id}; only that replacement route was recalculated.',
        icon: Icons.power_settings_new_rounded,
        color: 0xFFE86C68,
      );
      lastEvent = '${failedRobot.id} unavailable · task recovered locally';
    } else {
      if (failedTask != null) _queuedTasks.add(failedTask);
      _record(
        title: '${failedRobot.id} reported unavailable',
        description: failedTask == null
            ? 'The robot was removed from the local preview.'
            : 'Its task returned to the queue; no working robot is available yet.',
        icon: Icons.power_settings_new_rounded,
        color: 0xFFE86C68,
      );
      lastEvent = '${failedRobot.id} unavailable · local simulation';
    }
  }

  void _addRushOrder() {
    const rushDestinations = [
      GridPoint(0, 0),
      GridPoint(15, 0),
      GridPoint(0, 9),
      GridPoint(15, 9),
      GridPoint(2, 4),
      GridPoint(14, 4),
    ];
    final rushGoal = rushDestinations.firstWhere(
      (goal) => robots.every(
        (robot) => robot.state == RobotState.failed || robot.position != goal,
      ),
      orElse: () => const GridPoint(14, 8),
    );
    final rushTask = _FleetTask(
      id: 'RUSH-${(_nextRushNumber++).toString().padLeft(3, '0')}',
      goal: rushGoal,
      load: 'Priority tote',
      isRush: true,
    );
    final candidates = robots
        .where((robot) => robot.state != RobotState.failed && !robot.isRush)
        .toList();

    if (candidates.isEmpty) {
      _queuedTasks.add(rushTask);
      rushOrders++;
      _record(
        title: 'Rush order queued',
        description: 'No available robot can take it now; the order stays in the local queue.',
        icon: Icons.bolt_rounded,
        color: 0xFF8A78D4,
      );
      lastEvent = 'Rush order queued · no eligible robot';
      return;
    }

    final costs = candidates
        .map((robot) => [_assignmentCost(robot, rushTask)])
        .toList();
    final assignment = HungarianAssignment.solve(costs);
    final selectedIndex = assignment.indexOf(0);
    final selected = candidates[selectedIndex];
    if (selected.position == rushTask.goal) {
      completedOrders++;
      _record(
        title: '${rushTask.id} completed at current position',
        description:
            '${selected.id} was already at the rush-order destination, so it was completed without a travel step.',
        icon: Icons.task_alt_rounded,
        color: 0xFF3B8E75,
      );
      lastEvent =
          '${rushTask.id} completed at ${selected.id} · local simulation';
      return;
    }

    final robotIndex = robots.indexWhere((robot) => robot.id == selected.id);
    final displacedTask = _taskFromRobot(selected);
    if (displacedTask != null) _queuedTasks.add(displacedTask);

    robots[robotIndex] = selected.copyWith(
      task: rushTask.id,
      load: rushTask.load,
      goal: rushTask.goal,
      isRush: true,
      state: RobotState.moving,
    );
    rushOrders++;

    if (mode == PlannerMode.hiveflow) {
      _planAffected({selected.id});
    } else {
      _planAffected(robots.map((robot) => robot.id).toSet());
    }

    _record(
      title: '${rushTask.id} prioritized',
      description: displacedTask == null
          ? '${selected.id} was selected from the idle fleet for the urgent order.'
          : '${selected.id} was selected using travel distance and battery cost; its previous task returned to the queue.',
      icon: Icons.bolt_rounded,
      color: 0xFF8A78D4,
    );
    lastEvent = '${rushTask.id} assigned to ${selected.id} · local simulation';
  }

  void _planAffected(Set<String> affectedRobotIds) {
    final active = robots
        .where((robot) => robot.state != RobotState.failed)
        .toList();
    final affected =
        active.where((robot) => affectedRobotIds.contains(robot.id)).toList()
          ..sort((first, second) {
            if (first.isRush != second.isRush) {
              return first.isRush ? -1 : 1;
            }
            return first.id.compareTo(second.id);
          });

    final reservations = ReservationTable();
    if (mode == PlannerMode.hiveflow) {
      for (final robot in active) {
        if (!affectedRobotIds.contains(robot.id)) {
          reservations.reservePath(robot.id, robot.path, _planner.horizon);
        }
      }
    }

    for (final robot in affected) {
      final path = _planner.findPath(
        start: robot.position,
        goal: robot.goal,
        reservations: reservations,
        blocked: _blockedCells,
        useReservations: mode == PlannerMode.hiveflow,
        robotId: robot.id,
      );

      if (path == null) {
        final wasAlreadyYielding =
            robot.state == RobotState.idle && robot.path.length == 1;
        reservations.reservePath(robot.id, [robot.position], _planner.horizon);
        _replaceRobot(
          robot.copyWith(path: [robot.position], state: RobotState.idle),
        );
        if (!wasAlreadyYielding) {
          _record(
            title: '${robot.id} yielding for a clear route',
            description: 'The bounded reservation search found no safe route yet. The robot holds its cell and retries after the fleet moves.',
            icon: Icons.hourglass_bottom_rounded,
            color: 0xFFE99B47,
          );
        }
        continue;
      }

      reservations.reservePath(robot.id, path, _planner.horizon);
      _replaceRobot(
        robot.copyWith(
          path: path,
          state: robot.state == RobotState.picking
              ? RobotState.picking
              : path.length > 1
              ? RobotState.moving
              : RobotState.idle,
        ),
      );
      final waitSteps = _countWaitSteps(path);
      _record(
        title: mode == PlannerMode.hiveflow
            ? 'Reserved route for ${robot.id}'
            : 'Baseline route for ${robot.id}',
        description:
            '${path.length - 1} grid steps to ${robot.task}; ${waitSteps == 0 ? 'no wait steps' : '$waitSteps wait step${waitSteps == 1 ? '' : 's'}'}${mode == PlannerMode.hiveflow ? ', checked against vertex and edge reservations' : ', reservations disabled in baseline'}.',
        icon: Icons.route_rounded,
        color: 0xFF5C83D6,
      );
    }

    routeConflicts = _planner.countConflicts({
      for (final robot in robots)
        if (robot.state != RobotState.failed) robot.id: robot.path,
    });
    _updateComparisonPaths();
  }

  void _advanceSimulation() {
    _runTicks++;
    final updatedRobots = <FleetRobot>[];
    var freedRobots = <String>[];
    for (final robot in robots) {
      if (robot.state == RobotState.failed) {
        updatedRobots.add(robot);
        continue;
      }

      if (robot.state == RobotState.picking) {
        final remainingTicks = (_pickCountdowns[robot.id] ?? 1) - 1;
        if (remainingTicks > 0) {
          _pickCountdowns[robot.id] = remainingTicks;
          updatedRobots.add(robot);
          continue;
        }

        _pickCountdowns.remove(robot.id);
        completedOrders++;
        if (robot.isRush && rushOrders > 0) rushOrders--;
        freedRobots.add(robot.id);
        updatedRobots.add(
          robot.copyWith(
            state: RobotState.idle,
            task: 'STANDBY',
            load: '',
            path: [robot.position],
            isRush: false,
          ),
        );
        continue;
      }

      if (robot.state != RobotState.moving || robot.path.length < 2) {
        updatedRobots.add(robot);
        continue;
      }

      final nextPosition = robot.path[1];
      distanceTravelled++;
      final battery = _runTicks % 12 == 0
          ? math.max(0, robot.battery - 1)
          : robot.battery;
      final remainingPath = robot.path.sublist(1);
      if (nextPosition == robot.goal) {
        _pickCountdowns[robot.id] = 1;
        updatedRobots.add(
          robot.copyWith(
            position: nextPosition,
            battery: battery,
            state: RobotState.picking,
            path: [nextPosition],
          ),
        );
      } else {
        updatedRobots.add(
          robot.copyWith(
            position: nextPosition,
            battery: battery,
            path: remainingPath,
          ),
        );
      }
    }

    robots = updatedRobots;
    for (final robotId in freedRobots) {
      _record(
        title: 'Task completed by $robotId',
        description:
            'The robot reached its reserved destination; $distanceTravelled grid steps have been travelled this run.',
        icon: Icons.task_alt_rounded,
        color: 0xFF3B8E75,
      );
    }

    _dispatchQueuedTasks();
    final waitingForRoute = robots
        .where(
          (robot) =>
              robot.state == RobotState.idle &&
              robot.task != 'STANDBY' &&
              robot.state != RobotState.failed,
        )
        .map((robot) => robot.id)
        .toSet();
    if (waitingForRoute.isNotEmpty) {
      _planAffected(waitingForRoute);
    }
    if (_queuedTasks.isEmpty &&
        completedOrders > 0 &&
        activeRobots > 0 &&
        robots
            .where((robot) => robot.state != RobotState.failed)
            .every(
              (robot) =>
                  robot.state == RobotState.idle && robot.task == 'STANDBY',
            )) {
      _enqueueNextOrderBatch();
      _dispatchQueuedTasks();
    }
    _refreshReservationsAndConflicts();
    notifyListeners();
  }

  void _enqueueNextOrderBatch() {
    final batchNumber = _nextBatchNumber++;
    const destinations = [
      GridPoint(1, 8),
      GridPoint(5, 8),
      GridPoint(14, 8),
      GridPoint(1, 1),
      GridPoint(8, 0),
      GridPoint(13, 1),
      GridPoint(10, 8),
      GridPoint(2, 0),
      GridPoint(0, 1),
      GridPoint(4, 1),
      GridPoint(7, 1),
      GridPoint(10, 1),
      GridPoint(15, 2),
      GridPoint(4, 5),
      GridPoint(8, 6),
      GridPoint(15, 8),
      GridPoint(0, 8),
      GridPoint(2, 5),
      GridPoint(5, 5),
      GridPoint(7, 7),
      GridPoint(8, 2),
      GridPoint(11, 6),
      GridPoint(14, 5),
      GridPoint(15, 1),
    ];
    final firstDestination = (batchNumber * 8) % destinations.length;
    for (var index = 0; index < destinations.length; index++) {
      _queuedTasks.add(
        _FleetTask(
          id: 'B${batchNumber.toString().padLeft(2, '0')}-${(index + 1).toString().padLeft(2, '0')}',
          goal: destinations[(firstDestination + index) % destinations.length],
          load: _sampleLoads[index % _sampleLoads.length],
        ),
      );
    }
    _record(
      title: 'Seeded order batch $batchNumber released',
      description:
          'Eight reproducible sample pick orders entered the local queue.',
      icon: Icons.inventory_2_outlined,
      color: 0xFF5C83D6,
    );
  }

  void _dispatchQueuedTasks() {
    final idleRobots = robots
        .where(
          (robot) => robot.state == RobotState.idle && robot.task == 'STANDBY',
        )
        .toList();
    if (idleRobots.isEmpty || _queuedTasks.isEmpty) return;

    final dispatchCount = math.min(idleRobots.length, _queuedTasks.length);
    final candidates = idleRobots.take(dispatchCount).toList();
    final costs = candidates
        .map(
          (robot) =>
              _queuedTasks.map((task) => _assignmentCost(robot, task)).toList(),
        )
        .toList();
    final assignment = HungarianAssignment.solve(costs);
    final claimedTasks = <int>{};
    final replanned = <String>{};

    for (var index = 0; index < candidates.length; index++) {
      final taskIndex = assignment[index];
      if (taskIndex < 0) continue;
      claimedTasks.add(taskIndex);
      final robot = candidates[index];
      final task = _queuedTasks[taskIndex];
      replanned.add(robot.id);
      _record(
        title: '${robot.id} assigned to ${task.id}',
        description:
            'Assignment cost ${costs[index][taskIndex].toStringAsFixed(1)} combines ${_distance(robot.position, task.goal)} grid steps, ${robot.battery}% battery, the reservation-table congestion forecast${task.isRush ? ', and rush priority' : ''}.',
        icon: task.isRush
            ? Icons.bolt_rounded
            : Icons.assignment_turned_in_outlined,
        color: task.isRush ? 0xFF8A78D4 : 0xFF3B8E75,
      );
      if (robot.position == task.goal) {
        completedOrders++;
        if (task.isRush && rushOrders > 0) rushOrders--;
        replanned.remove(robot.id);
        _replaceRobot(
          robot.copyWith(
            task: 'STANDBY',
            load: '',
            goal: robot.position,
            path: [robot.position],
            isRush: false,
            state: RobotState.idle,
          ),
        );
        _record(
          title: '${task.id} completed at current position',
          description:
              '${robot.id} was already at the order destination, so it was completed without a travel step.',
          icon: Icons.task_alt_rounded,
          color: 0xFF3B8E75,
        );
        continue;
      }

      _replaceRobot(
        robot.copyWith(
          task: task.id,
          load: task.load,
          goal: task.goal,
          isRush: task.isRush,
          state: RobotState.moving,
        ),
      );
    }
    for (final index in claimedTasks.toList()..sort((a, b) => b.compareTo(a))) {
      _queuedTasks.removeAt(index);
    }
    _planAffected(
      mode == PlannerMode.hiveflow
          ? replanned
          : robots.map((robot) => robot.id).toSet(),
    );
  }

  void _refreshReservationsAndConflicts() {
    routeConflicts = _planner.countConflicts({
      for (final robot in robots)
        if (robot.state != RobotState.failed) robot.id: robot.path,
    });
    _updateComparisonPaths();
  }

  void _updateComparisonPaths() {
    hiveFlowComparisonPaths = _comparisonPaths(PlannerMode.hiveflow);
    baselineComparisonPaths = _comparisonPaths(PlannerMode.baseline);
  }

  Map<String, List<GridPoint>> _comparisonPaths(PlannerMode plannerMode) {
    final active =
        robots.where((robot) => robot.state != RobotState.failed).toList()
          ..sort((first, second) {
            if (first.isRush != second.isRush) {
              return first.isRush ? -1 : 1;
            }
            return first.id.compareTo(second.id);
          });
    final reservations = ReservationTable();
    final paths = <String, List<GridPoint>>{};

    for (final robot in active) {
      final path =
          _planner.findPath(
            start: robot.position,
            goal: robot.goal,
            reservations: reservations,
            blocked: _blockedCells,
            useReservations: plannerMode == PlannerMode.hiveflow,
            robotId: robot.id,
          ) ??
          [robot.position];
      paths[robot.id] = path;
      if (plannerMode == PlannerMode.hiveflow) {
        reservations.reservePath(robot.id, path, _planner.horizon);
      }
    }

    return paths;
  }

  double _assignmentCost(FleetRobot robot, _FleetTask task) {
    final distance = _distance(robot.position, task.goal);
    final batteryCost = (100 - robot.battery) * 0.08;
    final reservationForecast = ReservationTable();
    for (final other in robots) {
      if (other.id == robot.id || other.state == RobotState.failed) continue;
      reservationForecast.reservePath(other.id, other.path, _planner.horizon);
    }
    final unreservedPath = _planner.findPath(
      start: robot.position,
      goal: task.goal,
      reservations: ReservationTable(),
      blocked: _blockedCells,
      useReservations: false,
      robotId: robot.id,
    );
    final congestionCost = unreservedPath == null
        ? _planner.horizon * 4.0
        : reservationForecast.countReservedCellsOnPath(
                unreservedPath,
                exceptRobot: robot.id,
              ) *
              2.0;
    final detourCost = math
        .max(0, (unreservedPath?.length ?? 1) - 1 - distance)
        .toDouble();
    final blockedGoalCost = _blockedCells.contains(task.goal) ? 1000.0 : 0.0;
    final priorityBenefit = task.isRush ? -12.0 : 0.0;
    return distance +
        batteryCost +
        congestionCost +
        detourCost +
        blockedGoalCost +
        priorityBenefit;
  }

  int _distance(GridPoint first, GridPoint second) =>
      (first.x - second.x).abs() + (first.y - second.y).abs();

  int _countWaitSteps(List<GridPoint> path) {
    var waits = 0;
    for (var index = 1; index < path.length; index++) {
      if (path[index] == path[index - 1]) waits++;
    }
    return waits;
  }

  _FleetTask? _taskFromRobot(FleetRobot robot) {
    if (robot.task == 'STANDBY' ||
        robot.task == 'Completed' ||
        robot.task.isEmpty) {
      return null;
    }
    return _FleetTask(
      id: robot.task,
      goal: robot.goal,
      load: robot.load,
      isRush: robot.isRush,
    );
  }

  void _replaceRobot(FleetRobot replacement) {
    final index = robots.indexWhere((robot) => robot.id == replacement.id);
    if (index >= 0) robots[index] = replacement;
  }

  void _record({
    required String title,
    required String description,
    required IconData icon,
    required int color,
  }) {
    final now = DateTime.now();
    decisions.insert(
      0,
      DecisionEntry(
        title: title,
        description: description,
        time:
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
        icon: icon,
        color: color,
      ),
    );
    if (decisions.length > 30) {
      decisions = decisions.take(30).toList();
    }
  }

  void _startTimer() {
    _timer ??= Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (!_disposed && isRunning && _initialized) _advanceSimulation();
    });
  }

  void reset({bool notify = true}) {
    _timer?.cancel();
    _timer = null;
    _queuedTasks.clear();
    _runTicks = 0;
    _nextRushNumber = 1;
    _pickCountdowns.clear();
    _nextBatchNumber = 1;
    _initialized = false;
    mode = PlannerMode.hiveflow;
    isRunning = _autoStart;
    isAisleBlocked = false;
    completedOrders = 0;
    distanceTravelled = 0;
    routeConflicts = 0;
    lastEvent = 'Simulation ready · local sample fleet';

    robots = [
      _seedRobot('R-01', 1, 2, 91),
      _seedRobot('R-02', 5, 1, 76),
      _seedRobot('R-03', 13, 2, 68),
      _seedRobot('R-04', 2, 7, 80),
      _seedRobot('R-05', 7, 8, 54),
      _seedRobot('R-06', 14, 7, 87),
      _seedRobot('R-07', 8, 1, 63),
      _seedRobot('R-08', 0, 5, 43),
    ];

    decisions = [
      DecisionEntry(
        title: 'Seeded fleet simulation started',
        description: 'Preparing eight sample orders and planning safe routes for the fleet.',
        time: _timeNow(),
        icon: Icons.play_circle_outline_rounded,
        color: 0xFF3B8E75,
      ),
    ];
    _queuedTasks.addAll(const [
      _FleetTask(
        id: 'PICK-108',
        goal: GridPoint(1, 8),
        load: 'Tote 108 · bolts',
      ),
      _FleetTask(
        id: 'PICK-112',
        goal: GridPoint(5, 8),
        load: 'Tote 112 · sensors',
      ),
      _FleetTask(
        id: 'PICK-115',
        goal: GridPoint(14, 8),
        load: 'Tote 115 · motors',
      ),
      _FleetTask(
        id: 'PICK-119',
        goal: GridPoint(1, 1),
        load: 'Tote 119 · cables',
      ),
      _FleetTask(
        id: 'PICK-121',
        goal: GridPoint(8, 0),
        load: 'Tote 121 · wheels',
      ),
      _FleetTask(
        id: 'PICK-124',
        goal: GridPoint(13, 1),
        load: 'Tote 124 · grippers',
      ),
      _FleetTask(
        id: 'PICK-128',
        goal: GridPoint(10, 8),
        load: 'Tote 128 · batteries',
      ),
      _FleetTask(
        id: 'PICK-131',
        goal: GridPoint(2, 0),
        load: 'Tote 131 · brackets',
      ),
    ]);
    rushOrders = 0;
    _dispatchQueuedTasks();
    _updateComparisonPaths();
    _initialized = true;
    if (isRunning) _startTimer();
    if (notify) notifyListeners();
  }

  String _timeNow() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  FleetRobot _seedRobot(String id, int x, int y, int battery) {
    final position = GridPoint(x, y);
    return FleetRobot(
      id: id,
      position: position,
      battery: battery,
      state: RobotState.idle,
      task: 'STANDBY',
      load: '',
      path: [position],
      goal: position,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

class _FleetTask {
  const _FleetTask({
    required this.id,
    required this.goal,
    this.load = 'Warehouse parcel',
    this.isRush = false,
  });

  final String id;
  final GridPoint goal;
  final String load;
  final bool isRush;
}

const _sampleLoads = [
  'Tote · bolts',
  'Tote · sensors',
  'Tote · motors',
  'Tote · cables',
  'Tote · wheels',
  'Tote · grippers',
  'Tote · batteries',
  'Tote · brackets',
];
