import 'types.dart';

/// An immutable chess move.
///
/// [flags] records how the move changes the board beyond moving one piece,
/// so that making and unmaking it never has to re-derive that information.
final class Move {
  final int from;
  final int to;

  /// Promotion piece *type* ([knight]..[queen]), or 0.
  final int promotion;
  final int flags;

  static const int capture = 1;
  static const int doublePush = 2;
  static const int enPassant = 4;
  static const int castling = 8;

  const Move(this.from, this.to, {this.promotion = 0, this.flags = 0});

  bool get isCapture => flags & capture != 0;
  bool get isEnPassant => flags & enPassant != 0;
  bool get isCastling => flags & castling != 0;
  bool get isDoublePush => flags & doublePush != 0;
  bool get isPromotion => promotion != 0;

  /// Long algebraic coordinate notation as used by UCI, e.g. `e7e8q`.
  String get uci {
    final p = promotion == 0 ? '' : ' pnbrqk'[promotion];
    return '${squareName(from)}${squareName(to)}$p';
  }

  @override
  bool operator ==(Object other) =>
      other is Move &&
      other.from == from &&
      other.to == to &&
      other.promotion == promotion &&
      other.flags == flags;

  @override
  int get hashCode => Object.hash(from, to, promotion, flags);

  @override
  String toString() => uci;
}
