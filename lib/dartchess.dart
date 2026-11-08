/// A dependency-free chess library: board representation, FEN, legal move
/// generation and perft.
library;

export 'src/board.dart' show Board, startFen;
export 'src/move.dart';
export 'src/perft.dart';
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
