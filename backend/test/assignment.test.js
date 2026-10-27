import test from 'node:test';
import assert from 'node:assert/strict';

import { solveAssignment } from '../src/assignment.js';

test('finds the minimum total cost assignment', () => {
  const costs = [
    [4, 1, 3],
    [2, 0, 5],
    [3, 2, 2],
  ];
  const assignment = solveAssignment(costs);
  assert.deepEqual(assignment, [1, 0, 2]);
  assert.equal(
    assignment.reduce((sum, column, row) => sum + costs[row][column], 0),
    5,
  );
});

test('leaves robots without a job unmatched', () => {
  assert.deepEqual(
    solveAssignment([
      [8],
      [2],
      [4],
    ]),
    [-1, 0, -1],
  );
});

test('rejects invalid cost matrices', () => {
  assert.throws(() => solveAssignment([[1, 2], [3]]), TypeError);
  assert.throws(() => solveAssignment([[1, Infinity]]), TypeError);
});
