import 'board.dart';
import 'move.dart';
import 'types.dart';

/// Standard Algebraic Notation for [move] in [board]'s current position,
/// including minimal disambiguation and a `+`/`#` suffix. [move] must be
/// legal in [board]; the board is left unchanged.
String toSan(Board board, Move move) {
  final sb = StringBuffer();
  final piece = board.pieceAt(move.from);
  final type = pieceType(piece);
  if (move.isCastling) {
    sb.write(move.to > move.from ? 'O-O' : 'O-O-O');
  } else if (type == pawn) {
    if (move.isCapture) {
      sb.write('${squareName(move.from)[0]}x');
    }
    sb.write(squareName(move.to));
    if (move.isPromotion) sb.write('=${' PNBRQK'[move.promotion]}');
  } else {
    sb.write(' PNBRQK'[type]);
    // Disambiguate against other pieces of the same kind that can also
    // legally reach the target square.
    var sameFile = false, sameRank = false, ambiguous = false;
    for (final other in board.legalMoves()) {
      if (other.to != move.to ||
          other.from == move.from ||
          board.pieceAt(other.from) != piece) {
        continue;
      }
      ambiguous = true;
      if (fileOf(other.from) == fileOf(move.from)) sameFile = true;
      if (rankOf(other.from) == rankOf(move.from)) sameRank = true;
    }
    if (ambiguous) {
      final name = squareName(move.from);
      if (!sameFile) {
        sb.write(name[0]);
      } else if (!sameRank) {
        sb.write(name[1]);
      } else {
        sb.write(name);
      }
    }
    if (move.isCapture) sb.write('x');
    sb.write(squareName(move.to));
  }
  board.make(move);
  if (board.inCheck) sb.write(board.hasLegalMove ? '+' : '#');
  board.unmake();
  return sb.toString();
}

final RegExp _annotations = RegExp(r'[+#!?]+$');

/// Parses SAN (e.g. `Nbd7`, `exd6`, `e8=Q+`, `O-O`) into the matching legal
/// move. Accepts `0-0` for castling, a missing `=` before the promotion piece,
/// and trailing check/annotation symbols. Throws [FormatException] if the
/// text matches no legal move, or more than one.
Move parseSan(Board board, String san) {
  var text = san.trim().replaceAll(_annotations, '');
  text = text.replaceAll('0', 'O');
  final promo = RegExp(r'^([a-h][18])([NBRQ])$').firstMatch(text) ??
      RegExp(r'^([a-h]x[a-h][18])([NBRQ])$').firstMatch(text);
  if (promo != null) text = '${promo[1]}=${promo[2]}';
  Move? found;
  for (final m in board.legalMoves()) {
    if (toSan(board, m).replaceAll(_annotations, '') == text) {
      if (found != null) throw FormatException('ambiguous SAN', san);
      found = m;
    }
  }
  if (found != null) return found;
  // Over-disambiguated input such as `Ng1f3` is still unambiguous.
  final long =
      RegExp(r'^([NBRQK])([a-h][1-8])x?([a-h][1-8])$').firstMatch(text);
  if (long != null) {
    final from = parseSquare(long[2]!), to = parseSquare(long[3]!);
    for (final m in board.legalMoves()) {
      if (m.from == from &&
          m.to == to &&
          ' PNBRQK'[pieceType(board.pieceAt(from))] == long[1]) {
        return m;
      }
    }
  }
  throw FormatException('no legal move matches', san);
}
