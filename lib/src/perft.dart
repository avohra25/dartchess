import 'board.dart';

/// Counts leaf nodes of the legal move tree to [depth]. This is the standard
/// way to validate a move generator against published reference numbers.
int perft(Board board, int depth) {
  if (depth == 0) return 1;
  final moves = board.legalMoves();
  if (depth == 1) return moves.length;
  var nodes = 0;
  for (final m in moves) {
    board.make(m);
    nodes += perft(board, depth - 1);
    board.unmake();
  }
  return nodes;
}

/// Per-root-move perft counts, keyed by UCI move, for debugging divergences
/// against another engine's `go perft` / `divide` output.
Map<String, int> divide(Board board, int depth) {
  if (depth < 1) throw ArgumentError.value(depth, 'depth', 'must be >= 1');
  final result = <String, int>{};
  for (final m in board.legalMoves()) {
    board.make(m);
    result[m.uci] = perft(board, depth - 1);
    board.unmake();
  }
  return result;
}
