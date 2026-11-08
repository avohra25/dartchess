import 'board.dart';
import 'eval.dart';
import 'move.dart';
import 'types.dart';

const int mateScore = 30000;
const int _mateBound = mateScore - 1000;
const int _inf = 32000;
const int _maxPly = 96;

const int _exact = 0, _lower = 1, _upper = 2;

/// Progress report emitted after each completed iteration.
final class SearchInfo {
  final int depth;
  final int score;
  final int nodes;
  final Duration elapsed;
  final List<Move> pv;
  const SearchInfo(this.depth, this.score, this.nodes, this.elapsed, this.pv);

  /// Moves until mate (positive: side to move mates, negative: gets mated),
  /// or null if the score is not a mate score.
  int? get mateIn => mateDistance(score);
}

/// Outcome of [Engine.search].
final class SearchResult {
  /// Null only when the side to move has no legal move.
  final Move? bestMove;
  final int score;
  final int depth;
  final int nodes;
  final List<Move> pv;
  const SearchResult(
    this.bestMove,
    this.score,
    this.depth,
    this.nodes,
    this.pv,
  );

  int? get mateIn => mateDistance(score);
}

/// Converts a search score into "mate in N moves", or null.
int? mateDistance(int score) {
  if (score > _mateBound) return (mateScore - score + 1) ~/ 2;
  if (score < -_mateBound) return -((mateScore + score + 1) ~/ 2);
  return null;
}

/// An alpha-beta searcher with iterative deepening, principal variation
/// search, quiescence, a transposition table, null-move pruning, check
/// extensions and killer/history move ordering.
///
/// The engine keeps its transposition table between searches; call [clear]
/// when starting an unrelated game.
class Engine {
  final int _mask;
  final List<int> _ttKey;
  final List<Move?> _ttMove;
  final List<int> _ttDepth;
  final List<int> _ttScore;
  final List<int> _ttFlag;

  final List<List<Move?>> _killers = List.generate(
    _maxPly,
    (_) => List<Move?>.filled(2, null),
  );
  final List<int> _history = List<int>.filled(16 * 128, 0);
  final List<List<Move>> _pv = List.generate(_maxPly + 1, (_) => <Move>[]);

  late Board _b;
  int _nodes = 0;
  bool _stopped = false;
  bool _canStop = false;
  final Stopwatch _clock = Stopwatch();
  Duration? _timeLimit;
  int? _nodeLimit;
  bool Function()? _shouldStop;

  /// [ttBits] sets the transposition table size to `2^ttBits` entries.
  Engine({int ttBits = 18})
      : _mask = (1 << ttBits) - 1,
        _ttKey = List<int>.filled(1 << ttBits, 0),
        _ttMove = List<Move?>.filled(1 << ttBits, null),
        _ttDepth = List<int>.filled(1 << ttBits, -1),
        _ttScore = List<int>.filled(1 << ttBits, 0),
        _ttFlag = List<int>.filled(1 << ttBits, 0);

  /// Forgets everything learned from previous searches.
  void clear() {
    _ttKey.fillRange(0, _ttKey.length, 0);
    _ttMove.fillRange(0, _ttMove.length, null);
    _ttDepth.fillRange(0, _ttDepth.length, -1);
    _history.fillRange(0, _history.length, 0);
    for (final k in _killers) {
      k[0] = k[1] = null;
    }
  }

  /// Searches [board] (which is restored before returning) until [maxDepth]
  /// is reached, [timeLimit] or [nodeLimit] is exceeded, or [shouldStop]
  /// returns true. Depth 1 always completes so a move is always returned
  /// when one exists.
  SearchResult search(
    Board board, {
    int maxDepth = 64,
    Duration? timeLimit,
    int? nodeLimit,
    bool Function()? shouldStop,
    void Function(SearchInfo info)? onInfo,
  }) {
    _b = board;
    _nodes = 0;
    _stopped = false;
    _canStop = false;
    _timeLimit = timeLimit;
    _nodeLimit = nodeLimit;
    _shouldStop = shouldStop;
    _clock
      ..reset()
      ..start();
    for (var i = 0; i < _history.length; i++) {
      _history[i] >>= 2; // age history between searches
    }

    final legal = board.legalMoves();
    if (legal.isEmpty) {
      return SearchResult(null, board.inCheck ? -mateScore : 0, 0, 0, const []);
    }
    var best = SearchResult(legal.first, 0, 0, 0, [legal.first]);
    final depthCap = maxDepth.clamp(1, _maxPly - 8);
    for (var depth = 1; depth <= depthCap; depth++) {
      final score = _negamax(depth, -_inf, _inf, 0, false);
      if (_stopped) break;
      final pv = List<Move>.of(_pv[0]);
      if (pv.isNotEmpty) {
        best = SearchResult(pv.first, score, depth, _nodes, pv);
      }
      onInfo?.call(SearchInfo(depth, score, _nodes, _clock.elapsed, pv));
      _canStop = true;
      if (mateDistance(score) case final m? when m.abs() * 2 <= depth) break;
    }
    _clock.stop();
    return SearchResult(best.bestMove, best.score, best.depth, _nodes, best.pv);
  }

  bool _checkStop() {
    if (_stopped) return true;
    if (!_canStop || (_nodes & 1023) != 0) return false;
    if ((_nodeLimit != null && _nodes >= _nodeLimit!) ||
        (_timeLimit != null && _clock.elapsed >= _timeLimit!) ||
        (_shouldStop?.call() ?? false)) {
      _stopped = true;
    }
    return _stopped;
  }

  bool _hasNonPawnMaterial(int color) {
    for (var i = 0; i < 64; i++) {
      final p = _b.pieceAt(from64(i));
      if (p != empty && pieceColor(p) == color) {
        final t = pieceType(p);
        if (t != pawn && t != king) return true;
      }
    }
    return false;
  }

  int _toTT(int score, int ply) => score > _mateBound
      ? score + ply
      : (score < -_mateBound ? score - ply : score);
  int _fromTT(int score, int ply) => score > _mateBound
      ? score - ply
      : (score < -_mateBound ? score + ply : score);

  int _negamax(int depth, int alpha, int beta, int ply, bool allowNull) {
    _pv[ply].clear();
    if (_checkStop()) return 0;
    if (ply > 0) {
      if (_b.halfmoveClock >= 100 ||
          _b.repetitions > 0 ||
          _b.insufficientMaterial) {
        return 0;
      }
      // Mate distance pruning.
      alpha = alpha > -mateScore + ply ? alpha : -mateScore + ply;
      beta = beta < mateScore - ply ? beta : mateScore - ply;
      if (alpha >= beta) return alpha;
    }
    final inCheck = _b.inCheck;
    if (inCheck) depth++;
    if (depth <= 0) return _quiesce(alpha, beta, ply);
    _nodes++;
    if (ply >= _maxPly - 1) return evaluate(_b);

    final key = _b.hash;
    final idx = key & _mask;
    Move? ttMove;
    if (_ttKey[idx] == key && _ttDepth[idx] >= 0) {
      ttMove = _ttMove[idx];
      if (ply > 0 && _ttDepth[idx] >= depth) {
        final s = _fromTT(_ttScore[idx], ply);
        final f = _ttFlag[idx];
        if (f == _exact ||
            (f == _lower && s >= beta) ||
            (f == _upper && s <= alpha)) {
          return s;
        }
      }
    }

    final us = _b.sideToMove;
    if (allowNull &&
        !inCheck &&
        depth >= 3 &&
        beta.abs() < _mateBound &&
        _hasNonPawnMaterial(us) &&
        evaluate(_b) >= beta) {
      _b.makeNull();
      final s = -_negamax(depth - 3, -beta, -beta + 1, ply + 1, false);
      _b.unmake();
      if (_stopped) return 0;
      if (s >= beta) return beta;
    }

    final moves = _b.pseudoLegalMoves();
    final scores = [for (final m in moves) _orderScore(m, ttMove, ply)];
    final origAlpha = alpha;
    var best = -_inf;
    Move? bestMove;
    var legal = 0;
    for (var i = 0; i < moves.length; i++) {
      _pickNext(moves, scores, i);
      final m = moves[i];
      _b.make(m);
      if (_b.isAttacked(_b.kingSquare(us), us ^ 1)) {
        _b.unmake();
        continue;
      }
      legal++;
      int score;
      if (legal == 1) {
        score = -_negamax(depth - 1, -beta, -alpha, ply + 1, true);
      } else {
        // Principal variation search: prove the move is no better with a
        // null window, re-search only if it is.
        score = -_negamax(depth - 1, -alpha - 1, -alpha, ply + 1, true);
        if (score > alpha && score < beta) {
          score = -_negamax(depth - 1, -beta, -alpha, ply + 1, true);
        }
      }
      _b.unmake();
      if (_stopped) return 0;
      if (score > best) {
        best = score;
        bestMove = m;
        if (score > alpha) {
          alpha = score;
          _pv[ply]
            ..clear()
            ..add(m)
            ..addAll(_pv[ply + 1]);
          if (alpha >= beta) {
            if (!m.isCapture && !m.isPromotion) {
              final k = _killers[ply];
              if (k[0] != m) {
                k[1] = k[0];
                k[0] = m;
              }
              _history[_b.pieceAt(m.from) * 128 + m.to] += depth * depth;
            }
            break;
          }
        }
      }
    }
    if (legal == 0) return inCheck ? -mateScore + ply : 0;

    final flag = best >= beta ? _lower : (best > origAlpha ? _exact : _upper);
    _ttKey[idx] = key;
    _ttMove[idx] = bestMove;
    _ttDepth[idx] = depth;
    _ttScore[idx] = _toTT(best, ply);
    _ttFlag[idx] = flag;
    return best;
  }

  int _quiesce(int alpha, int beta, int ply) {
    _pv[ply].clear();
    if (_checkStop()) return 0;
    _nodes++;
    final standPat = evaluate(_b);
    if (standPat >= beta || ply >= _maxPly - 1) return standPat;
    if (standPat > alpha) alpha = standPat;
    final us = _b.sideToMove;
    final moves = [
      for (final m in _b.pseudoLegalMoves())
        if (m.isCapture || m.promotion == queen) m,
    ];
    final scores = [for (final m in moves) _orderScore(m, null, ply)];
    for (var i = 0; i < moves.length; i++) {
      _pickNext(moves, scores, i);
      final m = moves[i];
      _b.make(m);
      if (_b.isAttacked(_b.kingSquare(us), us ^ 1)) {
        _b.unmake();
        continue;
      }
      final score = -_quiesce(-beta, -alpha, ply + 1);
      _b.unmake();
      if (_stopped) return 0;
      if (score >= beta) return score;
      if (score > alpha) {
        alpha = score;
        _pv[ply]
          ..clear()
          ..add(m)
          ..addAll(_pv[ply + 1]);
      }
    }
    return alpha;
  }

  int _orderScore(Move m, Move? ttMove, int ply) {
    if (m == ttMove) return 1 << 30;
    var s = 0;
    if (m.isCapture) {
      final victim = m.isEnPassant ? pawn : pieceType(_b.pieceAt(m.to));
      final attacker = pieceType(_b.pieceAt(m.from));
      s = 1 << 20 | (victim * 16 - attacker);
    }
    if (m.isPromotion) s += m.promotion == queen ? 1 << 21 : -(1 << 10);
    if (s != 0) return s;
    final k = _killers[ply];
    if (m == k[0]) return 1 << 19;
    if (m == k[1]) return (1 << 19) - 1;
    return _history[_b.pieceAt(m.from) * 128 + m.to];
  }

  /// Selection-sort step: moves the best remaining move to index [i]. Cheap
  /// because a cutoff usually happens after the first few moves.
  static void _pickNext(List<Move> moves, List<int> scores, int i) {
    var bestIdx = i;
    for (var j = i + 1; j < moves.length; j++) {
      if (scores[j] > scores[bestIdx]) bestIdx = j;
    }
    if (bestIdx != i) {
      final m = moves[i];
      moves[i] = moves[bestIdx];
      moves[bestIdx] = m;
      final s = scores[i];
      scores[i] = scores[bestIdx];
      scores[bestIdx] = s;
    }
  }
}
