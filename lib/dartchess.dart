/// A dependency-free chess library: board representation, FEN, legal move
/// generation, perft, SAN/PGN, game-state tracking, an alpha-beta engine and
/// a UCI protocol front end.
library;

export 'src/board.dart' show Board, startFen;
export 'src/eval.dart' show evaluate, pieceValues;
export 'src/game.dart';
export 'src/move.dart';
export 'src/perft.dart';
export 'src/pgn.dart';
export 'src/san.dart';
export 'src/search.dart';
export 'src/uci.dart';
export 'src/types.dart'
    show
        white,
        black,
        empty,
        pawn,
        knight,
        bishop,
        rook,
        queen,
        king,
        makePiece,
        pieceType,
        pieceColor,
        squareName,
        parseSquare,
        pieceChar;
