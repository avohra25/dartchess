/// A dependency-free chess library: board representation, FEN, legal move
/// generation, perft, SAN and game-state tracking.
library;

export 'src/board.dart' show Board, startFen;
export 'src/game.dart';
export 'src/move.dart';
export 'src/perft.dart';
export 'src/san.dart';
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
