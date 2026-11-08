import 'board.dart';
import 'move.dart';
import 'san.dart';

/// Why a game is (or is not) over.
enum GameStatus {
  ongoing,
  checkmate,
  stalemate,
  insufficientMaterial,

  /// Fifty full moves without a capture or pawn move (claimable draw).
  fiftyMoveRule,

  /// The same position for the third time (claimable draw).
  threefoldRepetition,

  /// Seventy-five moves rule: automatic draw under FIDE rules.
  seventyFiveMoveRule,

  /// Fivefold repetition: automatic draw under FIDE rules.
  fivefoldRepetition,
}

/// A game record: a starting position plus the moves played, in SAN.
class Game {
  final String initialFen;
  final Board _board;
  final List<String> _san = [];

  Game([String fen = startFen])
      : initialFen = Board.fromFen(fen).fen,
        _board = Board.fromFen(fen);

  /// The current position. Do not mutate it directly; use [play]/[undo].
  Board get board => _board;

  /// Moves played so far in SAN.
  List<String> get sanMoves => List.unmodifiable(_san);

  /// Plays a move given as SAN or UCI and returns its SAN.
  /// Throws [FormatException] if the move is not legal.
  String play(String move) {
    final m = _board.moveFromUci(move) ?? parseSan(_board, move);
    return playMove(m);
  }

  /// Plays a legal [Move] (for example one from `board.legalMoves()`).
  String playMove(Move m) {
    if (!_board.legalMoves().contains(m)) {
      throw ArgumentError.value(m, 'm', 'not a legal move');
    }
    final san = toSan(_board, m);
    _board.make(m);
    _san.add(san);
    return san;
  }

  /// Takes back the last move. Returns false if there is none.
  bool undo() {
    if (_san.isEmpty) return false;
    _board.unmake();
    _san.removeLast();
    return true;
  }

  GameStatus get status {
    if (!_board.hasLegalMove) {
      return _board.inCheck ? GameStatus.checkmate : GameStatus.stalemate;
    }
    if (_board.insufficientMaterial) return GameStatus.insufficientMaterial;
    final reps = _board.repetitions;
    if (reps >= 4) return GameStatus.fivefoldRepetition;
    if (_board.halfmoveClock >= 150) return GameStatus.seventyFiveMoveRule;
    if (reps >= 2) return GameStatus.threefoldRepetition;
    if (_board.halfmoveClock >= 100) return GameStatus.fiftyMoveRule;
    return GameStatus.ongoing;
  }

  bool get isOver => status != GameStatus.ongoing;

  /// PGN-style result: `1-0`, `0-1`, `1/2-1/2`, or `*` while ongoing.
  String get result => switch (status) {
        GameStatus.ongoing => '*',
        GameStatus.checkmate => _board.sideToMove == 0 ? '0-1' : '1-0',
        _ => '1/2-1/2',
      };
}
