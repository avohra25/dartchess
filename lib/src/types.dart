/// Core constants and helpers shared across the library.
///
/// Squares use the 0x88 layout: `index = rank * 16 + file`, with rank 0 being
/// White's back rank. Any index with `index & 0x88 != 0` is off the board,
/// which makes edge detection for move generation a single bit test.
library;

const int white = 0;
const int black = 1;

const int empty = 0;
const int pawn = 1;
const int knight = 2;
const int bishop = 3;
const int rook = 4;
const int queen = 5;
const int king = 6;

/// Encodes a piece as `color * 8 + type`, so white pieces are 1..6 and black
/// pieces 9..14. Zero is an empty square.
int makePiece(int color, int type) => color * 8 + type;
int pieceType(int piece) => piece & 7;
int pieceColor(int piece) => piece >> 3;

bool onBoard(int sq) => sq & 0x88 == 0;
int squareOf(int file, int rank) => rank * 16 + file;
int fileOf(int sq) => sq & 7;
int rankOf(int sq) => sq >> 4;

/// Converts between 0x88 squares and the dense 0..63 indexing (a1 = 0).
int to64(int sq) => (sq >> 4) * 8 + (sq & 7);
int from64(int i) => (i >> 3) * 16 + (i & 7);

const String _files = 'abcdefgh';

String squareName(int sq) {
  if (!onBoard(sq)) throw ArgumentError.value(sq, 'sq', 'not a board square');
  return '${_files[fileOf(sq)]}${rankOf(sq) + 1}';
}

/// Parses an algebraic square such as `e4`. Throws [FormatException].
int parseSquare(String name) {
  if (name.length != 2) throw FormatException('bad square', name);
  final f = name.codeUnitAt(0) - 0x61;
  final r = name.codeUnitAt(1) - 0x31;
  if (f < 0 || f > 7 || r < 0 || r > 7) {
    throw FormatException('bad square', name);
  }
  return squareOf(f, r);
}

const String _pieceChars = ' PNBRQK';

/// FEN letter for a piece: upper case for White, lower case for Black.
String pieceChar(int piece) {
  final c = _pieceChars[pieceType(piece)];
  return pieceColor(piece) == white ? c : c.toLowerCase();
}

/// Inverse of [pieceChar]; returns 0 for an unknown letter.
int pieceFromChar(String ch) {
  final t = _pieceChars.indexOf(ch.toUpperCase());
  if (t <= 0) return empty;
  return makePiece(ch == ch.toUpperCase() ? white : black, t);
}

// Castling right bits.
const int castleWK = 1;
const int castleWQ = 2;
const int castleBK = 4;
const int castleBQ = 8;

// Direction offsets in 0x88 space.
const List<int> knightOffsets = [-33, -31, -18, -14, 14, 18, 31, 33];
const List<int> kingOffsets = [-17, -16, -15, -1, 1, 15, 16, 17];
const List<int> bishopOffsets = [-17, -15, 15, 17];
const List<int> rookOffsets = [-16, -1, 1, 16];
