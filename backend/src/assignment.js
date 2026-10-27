export function solveAssignment(costs) {
  if (costs.length === 0) return [];
  const columnCount = costs[0].length;
  if (
    columnCount === 0 ||
    costs.some((row) => row.length !== columnCount) ||
    costs.some((row) => row.some((cost) => !Number.isFinite(cost)))
  ) {
    throw new TypeError('Assignment costs must be a non-empty rectangular matrix of finite numbers.');
  }

  const rowCount = costs.length;
  if (rowCount <= columnCount) return solveRows(costs);

  const transposed = Array.from({ length: columnCount }, (_, column) =>
    Array.from({ length: rowCount }, (_, row) => costs[row][column]),
  );
  const transposedAssignment = solveRows(transposed);
  const assignment = Array(rowCount).fill(-1);
  for (let column = 0; column < transposedAssignment.length; column++) {
    assignment[transposedAssignment[column]] = column;
  }
  return assignment;
}

function solveRows(costs) {
  const rows = costs.length;
  const columns = costs[0].length;
  const rowPotential = Array(rows + 1).fill(0);
  const columnPotential = Array(columns + 1).fill(0);
  const matchedRow = Array(columns + 1).fill(0);
  const previousColumn = Array(columns + 1).fill(0);

  for (let row = 1; row <= rows; row++) {
    matchedRow[0] = row;
    let currentColumn = 0;
    const minimumReducedCost = Array(columns + 1).fill(Infinity);
    const visited = Array(columns + 1).fill(false);

    do {
      visited[currentColumn] = true;
      const currentRow = matchedRow[currentColumn];
      let delta = Infinity;
      let nextColumn = 0;

      for (let column = 1; column <= columns; column++) {
        if (visited[column]) continue;
        const reducedCost =
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

      for (let column = 0; column <= columns; column++) {
        if (visited[column]) {
          rowPotential[matchedRow[column]] += delta;
          columnPotential[column] -= delta;
        } else {
          minimumReducedCost[column] -= delta;
        }
      }
      currentColumn = nextColumn;
    } while (matchedRow[currentColumn] !== 0);

    do {
      const priorColumn = previousColumn[currentColumn];
      matchedRow[currentColumn] = matchedRow[priorColumn];
      currentColumn = priorColumn;
    } while (currentColumn !== 0);
  }

  const assignment = Array(rows).fill(-1);
  for (let column = 1; column <= columns; column++) {
    if (matchedRow[column] !== 0) {
      assignment[matchedRow[column] - 1] = column - 1;
    }
  }
  return assignment;
}
