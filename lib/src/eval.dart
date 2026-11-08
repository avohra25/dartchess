import 'board.dart';
import 'types.dart';

/// Material values in centipawns, indexed by piece type.
const List<int> pieceValues = [0, 100, 320, 330, 500, 900, 0];

// Piece-square tables from White's point of view, laid out as you would see
// the board (a8 first). Values follow the well-known "simplified evaluation
// function" by Tomasz Michniewski.
const List<int> _pawnTable = [
  0, 0, 0, 0, 0, 0, 0, 0, //
  50, 50, 50, 50, 50, 50, 50, 50,
  10, 10, 20, 30, 30, 20, 10, 10,
  5, 5, 10, 25, 25, 10, 5, 5,
  0, 0, 0, 20, 20, 0, 0, 0,
  5, -5, -10, 0, 0, -10, -5, 5,
  5, 10, 10, -20, -20, 10, 10, 5,
  0, 0, 0, 0, 0, 0, 0, 0,
];
const List<int> _knightTable = [
  -50, -40, -30, -30, -30, -30, -40, -50, //
  -40, -20, 0, 0, 0, 0, -20, -40,
  -30, 0, 10, 15, 15, 10, 0, -30,
  -30, 5, 15, 20, 20, 15, 5, -30,
  -30, 0, 15, 20, 20, 15, 0, -30,
  -30, 5, 10, 15, 15, 10, 5, -30,
  -40, -20, 0, 5, 5, 0, -20, -40,
  -50, -40, -30, -30, -30, -30, -40, -50,
];
const List<int> _bishopTable = [
  -20, -10, -10, -10, -10, -10, -10, -20, //
  -10, 0, 0, 0, 0, 0, 0, -10,
  -10, 0, 5, 10, 10, 5, 0, -10,
  -10, 5, 5, 10, 10, 5, 5, -10,
  -10, 0, 10, 10, 10, 10, 0, -10,
  -10, 10, 10, 10, 10, 10, 10, -10,
  -10, 5, 0, 0, 0, 0, 5, -10,
  -20, -10, -10, -10, -10, -10, -10, -20,
];
const List<int> _rookTable = [
  0, 0, 0, 0, 0, 0, 0, 0, //
  5, 10, 10, 10, 10, 10, 10, 5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  0, 0, 0, 5, 5, 0, 0, 0,
];
const List<int> _queenTable = [
  -20, -10, -10, -5, -5, -10, -10, -20, //
  -10, 0, 0, 0, 0, 0, 0, -10,
  -10, 0, 5, 5, 5, 5, 0, -10,
  -5, 0, 5, 5, 5, 5, 0, -5,
  0, 0, 5, 5, 5, 5, 0, -5,
  -10, 5, 5, 5, 5, 5, 0, -10,
  -10, 0, 5, 0, 0, 0, 0, -10,
  -20, -10, -10, -5, -5, -10, -10, -20,
];
const List<int> _kingMiddle = [
  -30, -40, -40, -50, -50, -40, -40, -30, //
  -30, -40, -40, -50, -50, -40, -40, -30,
  -30, -40, -40, -50, -50, -40, -40, -30,
  -30, -40, -40, -50, -50, -40, -40, -30,
  -20, -30, -30, -40, -40, -30, -30, -20,
  -10, -20, -20, -20, -20, -20, -20, -10,
  20, 20, 0, 0, 0, 0, 20, 20,
  20, 30, 10, 0, 0, 10, 30, 20,
];
const List<int> _kingEnd = [
  -50, -40, -30, -20, -20, -30, -40, -50, //
  -30, -20, -10, 0, 0, -10, -20, -30,
  -30, -10, 20, 30, 30, 20, -10, -30,
  -30, -10, 30, 40, 40, 30, -10, -30,
  -30, -10, 30, 40, 40, 30, -10, -30,
  -30, -10, 20, 30, 30, 20, -10, -30,
  -30, -30, 0, 0, 0, 0, -30, -30,
  -50, -30, -30, -30, -30, -30, -30, -50,
];

const List<List<int>> _tables = [
  [],
  _pawnTable,
  _knightTable,
  _bishopTable,
  _rookTable,
  _queenTable,
  [],
];

/// Game phase weight of each piece type; 24 means "all pieces on the board".
const List<int> _phaseWeight = [0, 0, 1, 1, 2, 4, 0];

/// Static evaluation in centipawns from the side to move's point of view.
///
/// Material plus piece-square tables, a bishop pair bonus, and a king table
/// tapered between middlegame and endgame by remaining material.
int evaluate(Board board) {
  var score = 0; // White's perspective
  var phase = 0;
  final bishops = [0, 0];
  var kingMg = 0, kingEg = 0;
  for (var i = 0; i < 64; i++) {
    final p = board.pieceAt(from64(i));
    if (p == empty) continue;
    final type = pieceType(p), color = pieceColor(p);
    // Tables are written a8-first, so White reads them mirrored.
    final idx = color == white ? i ^ 56 : i;
    final sign = color == white ? 1 : -1;
    phase += _phaseWeight[type];
    if (type == king) {
      kingMg += sign * _kingMiddle[idx];
      kingEg += sign * _kingEnd[idx];
      continue;
    }
    if (type == bishop) bishops[color]++;
    score += sign * (pieceValues[type] + _tables[type][idx]);
  }
  if (phase > 24) phase = 24;
  score += (kingMg * phase + kingEg * (24 - phase)) ~/ 24;
  if (bishops[white] >= 2) score += 30;
  if (bishops[black] >= 2) score -= 30;
  return board.sideToMove == white ? score : -score;
}
