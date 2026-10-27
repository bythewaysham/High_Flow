import 'dart:math' as math;

class GridPoint {
  const GridPoint(this.x, this.y);

  final int x;
  final int y;

  int get manhattanDistance => x.abs() + y.abs();

  @override
  bool operator ==(Object other) =>
      other is GridPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x, $y)';
}

class ReservationTable {
  final Map<int, Map<GridPoint, String>> _vertices = {};
  final Map<int, Map<_Edge, String>> _edges = {};

  bool isCellFree(GridPoint point, int timestep, {String? exceptRobot}) {
    final owner = _vertices[timestep]?[point];
    return owner == null || owner == exceptRobot;
  }

  bool canTraverse(
    GridPoint from,
    GridPoint to,
    int timestep, {
    String? exceptRobot,
  }) {
    // A reverse edge is reserved when two robots would swap cells at once.
    final reverseEdge = _Edge(to, from);
    final owner = _edges[timestep]?[reverseEdge];
    return owner == null || owner == exceptRobot;
  }

  int countReservedCellsOnPath(List<GridPoint> path, {String? exceptRobot}) {
    var count = 0;
    for (var timestep = 0; timestep < path.length; timestep++) {
      final owner = _vertices[timestep]?[path[timestep]];
      if (owner != null && owner != exceptRobot) count++;
    }
    return count;
  }

  void reservePath(String robotId, List<GridPoint> path, int horizon) {
    if (path.isEmpty) return;

    // Reaching a destination reserves it for the rest of this planning window.
    for (var timestep = 0; timestep <= horizon; timestep++) {
      final from = path[math.min(timestep, path.length - 1)];
      _vertices.putIfAbsent(timestep, () => {})[from] = robotId;

      if (timestep < horizon) {
        final to = path[math.min(timestep + 1, path.length - 1)];
        _edges.putIfAbsent(timestep, () => {})[_Edge(from, to)] = robotId;
      }
    }
  }
}

class SpaceTimePlanner {
  const SpaceTimePlanner({
    this.columns = 16,
    this.rows = 10,
    this.horizon = 32,
  });

  final int columns;
  final int rows;
  final int horizon;

  static const aisleBlock = GridPoint(7, 4);
  static const _shelfColumns = {3, 6, 9, 12};
  static const _directions = [
    GridPoint(0, -1),
    GridPoint(1, 0),
    GridPoint(0, 1),
    GridPoint(-1, 0),
    GridPoint(0, 0),
  ];

  bool isWalkable(GridPoint point, {Set<GridPoint> blocked = const {}}) {
    return _isInWalkableGrid(point) && !blocked.contains(point);
  }

  List<GridPoint>? findPath({
    required GridPoint start,
    required GridPoint goal,
    required ReservationTable reservations,
    required Set<GridPoint> blocked,
    required bool useReservations,
    String? robotId,
  }) {
    if (!_isInWalkableGrid(start) || !isWalkable(goal, blocked: blocked)) {
      return null;
    }
    if (start == goal) return [start];

    final open = <_SearchNode>[];
    final startNode = _SearchNode(
      point: start,
      timestep: 0,
      cost: 0,
      estimate: start.manhattanDistanceTo(goal),
      previous: null,
    );
    open.add(startNode);
    final bestCosts = <_TimePoint, int>{_TimePoint(start, 0): 0};

    while (open.isNotEmpty) {
      final current = open.removeAt(0);
      if (current.point == goal) {
        final path = <GridPoint>[];
        _SearchNode? step = current;
        while (step != null) {
          path.add(step.point);
          step = step.previous;
        }
        return path.reversed.toList();
      }
      if (current.timestep >= horizon) continue;

      for (final direction in _directions) {
        final next = GridPoint(
          current.point.x + direction.x,
          current.point.y + direction.y,
        );
        final nextTime = current.timestep + 1;
        if (!isWalkable(next, blocked: blocked)) continue;
        if (useReservations &&
            (!reservations.isCellFree(next, nextTime, exceptRobot: robotId) ||
                !reservations.canTraverse(
                  current.point,
                  next,
                  current.timestep,
                  exceptRobot: robotId,
                ))) {
          continue;
        }

        final state = _TimePoint(next, nextTime);
        final cost = current.cost + 1;
        if (cost >= (bestCosts[state] ?? 1 << 30)) continue;
        bestCosts[state] = cost;

        final node = _SearchNode(
          point: next,
          timestep: nextTime,
          cost: cost,
          estimate: cost + next.manhattanDistanceTo(goal),
          previous: current,
        );
        final insertIndex = open.indexWhere(
          (existing) => existing.estimate > node.estimate,
        );
        if (insertIndex < 0) {
          open.add(node);
        } else {
          open.insert(insertIndex, node);
        }
      }
    }

    return null;
  }

  bool _isInWalkableGrid(GridPoint point) {
    return point.x >= 0 &&
        point.x < columns &&
        point.y >= 0 &&
        point.y < rows &&
        (!_shelfColumns.contains(point.x) ||
            point.y == 0 ||
            point.y == 4 ||
            point.y >= 8);
  }

  int countConflicts(Map<String, List<GridPoint>> paths) {
    if (paths.length < 2) return 0;
    var conflicts = 0;
    final pathsByRobot = paths.entries.toList();

    for (var first = 0; first < pathsByRobot.length; first++) {
      for (var second = first + 1; second < pathsByRobot.length; second++) {
        final firstPath = pathsByRobot[first].value;
        final secondPath = pathsByRobot[second].value;
        final steps = math.max(firstPath.length, secondPath.length);

        for (var timestep = 0; timestep < steps; timestep++) {
          final firstFrom = firstPath[math.min(timestep, firstPath.length - 1)];
          final secondFrom =
              secondPath[math.min(timestep, secondPath.length - 1)];
          if (firstFrom == secondFrom) conflicts++;

          if (timestep + 1 >= steps) continue;
          final firstTo =
              firstPath[math.min(timestep + 1, firstPath.length - 1)];
          final secondTo =
              secondPath[math.min(timestep + 1, secondPath.length - 1)];
          if (firstFrom == secondTo && secondFrom == firstTo) {
            conflicts++;
          }
        }
      }
    }
    return conflicts;
  }
}

class HungarianAssignment {
  const HungarianAssignment._();

  static List<int> solve(List<List<double>> costs) {
    if (costs.isEmpty) return [];
    final columnCount = costs.first.length;
    if (columnCount == 0 || costs.any((row) => row.length != columnCount)) {
      throw ArgumentError('The cost matrix must be rectangular and non-empty.');
    }
    if (costs.any((row) => row.any((cost) => !cost.isFinite))) {
      throw ArgumentError('The cost matrix must contain finite values.');
    }

    final rowCount = costs.length;
    if (rowCount <= columnCount) {
      return _solveRows(costs);
    }

    final transposed = List.generate(
      columnCount,
      (column) => List.generate(rowCount, (row) => costs[row][column]),
    );
    final transposedAssignment = _solveRows(transposed);
    final assignment = List.filled(rowCount, -1);
    for (var column = 0; column < transposedAssignment.length; column++) {
      assignment[transposedAssignment[column]] = column;
    }
    return assignment;
  }

  static List<int> _solveRows(List<List<double>> costs) {
    final rows = costs.length;
    final columns = costs.first.length;
    final rowPotential = List.filled(rows + 1, 0.0);
    final columnPotential = List.filled(columns + 1, 0.0);
    final matchedRow = List.filled(columns + 1, 0);
    final previousColumn = List.filled(columns + 1, 0);

    for (var row = 1; row <= rows; row++) {
      matchedRow[0] = row;
      var currentColumn = 0;
      final minimumReducedCost = List.filled(columns + 1, double.infinity);
      final visited = List.filled(columns + 1, false);

      do {
        visited[currentColumn] = true;
        final currentRow = matchedRow[currentColumn];
        var delta = double.infinity;
        var nextColumn = 0;

        for (var column = 1; column <= columns; column++) {
          if (visited[column]) continue;
          final reducedCost =
              costs[currentRow - 1][column - 1] -
              rowPotential[currentRow] -
              columnPotential[column];
          if (reducedCost < minimumReducedCost[column]) {
            minimumReducedCost[column] = reducedCost;
            previousColumn[column] = currentColumn;
          }
          if (minimumReducedCost[column] < delta) {
            delta = minimumReducedCost[column];
            nextColumn = column;
          }
        }

        for (var column = 0; column <= columns; column++) {
          if (visited[column]) {
            rowPotential[matchedRow[column]] += delta;
            columnPotential[column] -= delta;
          } else {
            minimumReducedCost[column] -= delta;
          }
        }
        currentColumn = nextColumn;
      } while (matchedRow[currentColumn] != 0);

      do {
        final priorColumn = previousColumn[currentColumn];
        matchedRow[currentColumn] = matchedRow[priorColumn];
        currentColumn = priorColumn;
      } while (currentColumn != 0);
    }

    final assignment = List.filled(rows, -1);
    for (var column = 1; column <= columns; column++) {
      if (matchedRow[column] != 0) {
        assignment[matchedRow[column] - 1] = column - 1;
      }
    }
    return assignment;
  }
}

class _Edge {
  const _Edge(this.from, this.to);

  final GridPoint from;
  final GridPoint to;

  @override
  bool operator ==(Object other) =>
      other is _Edge && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

class _SearchNode {
  const _SearchNode({
    required this.point,
    required this.timestep,
    required this.cost,
    required this.estimate,
    required this.previous,
  });

  final GridPoint point;
  final int timestep;
  final int cost;
  final int estimate;
  final _SearchNode? previous;
}

class _TimePoint {
  const _TimePoint(this.point, this.timestep);

  final GridPoint point;
  final int timestep;

  @override
  bool operator ==(Object other) =>
      other is _TimePoint && other.point == point && other.timestep == timestep;

  @override
  int get hashCode => Object.hash(point, timestep);
}

extension on GridPoint {
  int manhattanDistanceTo(GridPoint other) =>
      (x - other.x).abs() + (y - other.y).abs();
}
