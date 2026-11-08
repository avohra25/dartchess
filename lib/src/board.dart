import 'move.dart';
import 'types.dart';
import 'zobrist.dart';

const String startFen =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// State needed to undo a move that cannot be recovered from the move itself.
final class _Undo {
  final Move move;
  final int captured;
  final int castling;
  final int epSquare;
  final int halfmove;
  final int hash;
  const _Undo(this.move, this.captured, this.castling, this.epSquare,
      this.halfmove, this.hash);
}

/// Castling rights that survive a piece leaving or arriving on each square.
final List<int> _castleMask = () {
  final m = List<int>.filled(128, 15);
  m[squareOf(0, 0)] = 15 & ~castleWQ;
  m[squareOf(7, 0)] = 15 & ~castleWK;
  m[squareOf(4, 0)] = 15 & ~(castleWK | castleWQ);
  m[squareOf(0, 7)] = 15 & ~castleBQ;
  m[squareOf(7, 7)] = 15 & ~castleBK;
  m[squareOf(4, 7)] = 15 & ~(castleBK | castleBQ);
  return m;
}();

/// A mutable chess position with make/unmake and legal move generation.
class Board {
  final List<int> _sq = List<int>.filled(128, empty);
  final List<int> _kings = [-1, -1];
  final List<_Undo> _history = [];

  int _side = white;
  int _castling = 0;
  int _ep = -1;
  int _halfmove = 0;
  int _fullmove = 1;
  int _hash = 0;

  Board._();

  /// The standard starting position.
  factory Board() => Board.fromFen(startFen);

  /// Parses a FEN string. Throws [FormatException] on malformed input or an
  /// illegal position (missing kings, pawns on the back ranks, side not to
  /// move in check).
  factory Board.fromFen(String fen) {
    final b = Board._();
    b._loadFen(fen);
    return b;
  }

  /// An independent deep copy (history is not copied).
  Board copy() => Board.fromFen(fen);

  int get sideToMove => _side;
  int get castlingRights => _castling;
  int get epSquare => _ep;
  int get halfmoveClock => _halfmove;
  int get fullmoveNumber => _fullmove;
  int kingSquare(int color) => _kings[color];
  int pieceAt(int sq) => _sq[sq];
  int get ply => _history.length;

  /// 64-bit Zobrist hash of the position (placement, side to move, castling
  /// rights and a *capturable* en passant square), maintained incrementally.
  int get hash => _hash;

  /// The last move made with [make], or null (also after [makeNull]).
  Move? get lastMove {
    if (_history.isEmpty) return null;
    final m = _history.last.move;
    return identical(m, _nullMove) ? null : m;
  }

  /// Whether the side to move has any legal move (cheaper than
  /// `legalMoves().isNotEmpty` because it stops at the first one).
  bool get hasLegalMove {
    final us = _side;
    for (final m in pseudoLegalMoves()) {
      make(m);
      final ok = !isAttacked(_kings[us], us ^ 1);
      unmake();
      if (ok) return true;
    }
    return false;
  }

  /// Neither side can possibly checkmate: K v K, K+minor v K, or only
  /// same-coloured bishops besides the kings.
  bool get insufficientMaterial {
    var minors = 0, knights = 0;
    var bishopColors = 0; // bit 0: light-square bishop, bit 1: dark
    for (var i = 0; i < 64; i++) {
      final p = _sq[from64(i)];
      switch (pieceType(p)) {
        case pawn || rook || queen:
          return false;
        case knight:
          minors++;
          knights++;
        case bishop:
          minors++;
          bishopColors |= ((i >> 3) + (i & 7)).isEven ? 2 : 1;
      }
    }
    if (minors <= 1) return true;
    return knights == 0 && bishopColors != 3;
  }

  void _loadFen(String fen) {
    final parts = fen.trim().split(RegExp(r'\s+'));
    if (parts.length < 4 || parts.length > 6) {
      throw FormatException('FEN needs 4 to 6 fields', fen);
    }
    final ranks = parts[0].split('/');
    if (ranks.length != 8) throw FormatException('FEN needs 8 ranks', fen);
    for (var i = 0; i < 8; i++) {
      final rank = 7 - i;
      var file = 0;
      for (final ch in ranks[i].split('')) {
        final d = int.tryParse(ch);
        if (d != null) {
          if (d < 1 || d > 8) throw FormatException('bad digit', fen);
          file += d;
        } else {
          final p = pieceFromChar(ch);
          if (p == empty) throw FormatException('bad piece "$ch"', fen);
          if (file > 7) throw FormatException('rank overflow', fen);
          final s = squareOf(file, rank);
          _sq[s] = p;
          if (pieceType(p) == king) {
            if (_kings[pieceColor(p)] != -1) {
              throw FormatException('more than one king per side', fen);
            }
            _kings[pieceColor(p)] = s;
          }
          if (pieceType(p) == pawn && (rank == 0 || rank == 7)) {
            throw FormatException('pawn on back rank', fen);
          }
          file++;
        }
      }
      if (file != 8) {
        throw FormatException('rank ${rank + 1} is not 8 wide', fen);
      }
    }
    if (_kings[white] == -1 || _kings[black] == -1) {
      throw FormatException('both sides need a king', fen);
    }

    _side = switch (parts[1]) {
      'w' => white,
      'b' => black,
      _ => throw FormatException('side must be w or b', fen),
    };

    if (parts[2] != '-') {
      for (final ch in parts[2].split('')) {
        final bit = switch (ch) {
          'K' => castleWK,
          'Q' => castleWQ,
          'k' => castleBK,
          'q' => castleBQ,
          _ => throw FormatException('bad castling "$ch"', fen),
        };
        if (_castling & bit != 0) {
          throw FormatException('repeated castling', fen);
        }
        _castling |= bit;
      }
    }
    // Drop rights that the piece placement makes impossible.
    bool has(int f, int r, int p) => _sq[squareOf(f, r)] == p;
    final wk = makePiece(white, king), bk = makePiece(black, king);
    final wr = makePiece(white, rook), br = makePiece(black, rook);
    if (!has(4, 0, wk) || !has(7, 0, wr)) _castling &= ~castleWK;
    if (!has(4, 0, wk) || !has(0, 0, wr)) _castling &= ~castleWQ;
    if (!has(4, 7, bk) || !has(7, 7, br)) _castling &= ~castleBK;
    if (!has(4, 7, bk) || !has(0, 7, br)) _castling &= ~castleBQ;

    if (parts[3] != '-') {
      final ep = parseSquare(parts[3]);
      final expectedRank = _side == white ? 5 : 2;
      if (rankOf(ep) != expectedRank) {
        throw FormatException('en passant square on wrong rank', fen);
      }
      _ep = ep;
    }
    _halfmove = parts.length > 4 ? _parseCounter(parts[4], fen, 0) : 0;
    _fullmove = parts.length > 5 ? _parseCounter(parts[5], fen, 1) : 1;

    if (isAttacked(_kings[_side ^ 1], _side)) {
      throw FormatException('side not to move is in check', fen);
    }
    _hash = computeHash();
  }

  /// Hash contribution of the en passant square. It only counts when a pawn
  /// of the side to move could actually capture there, so that positions
  /// differing only in an unusable ep square hash (and repeat) identically.
  int _epKey() {
    if (_ep == -1) return 0;
    final p = makePiece(_side, pawn);
    final back = _side == white ? -16 : 16;
    for (final d in const [-1, 1]) {
      final s = _ep + back + d;
      if (onBoard(s) && _sq[s] == p) return epFileKeys[fileOf(_ep)];
    }
    return 0;
  }

  /// Recomputes the hash from scratch. [hash] should always equal this.
  int computeHash() {
    var h = 0;
    for (var i = 0; i < 64; i++) {
      final s = from64(i);
      if (_sq[s] != empty) h ^= pieceKeys[_sq[s] * 128 + s];
    }
    if (_side == black) h ^= sideKey;
    h ^= castlingKeys[_castling];
    return h ^ _epKey();
  }

  /// How many times the current position occurred before, counting only
  /// positions since the last irreversible move (capture or pawn move).
  int get repetitions {
    var count = 0;
    final n = _history.length;
    for (var back = 2; back <= _halfmove && back <= n; back += 2) {
      if (_history[n - back].hash == _hash) count++;
    }
    return count;
  }

  static int _parseCounter(String s, String fen, int min) {
    final v = int.tryParse(s);
    if (v == null || v < min) throw FormatException('bad move counter', fen);
    return v;
  }

  /// Serialises the position as FEN.
  String get fen {
    final sb = StringBuffer();
    for (var rank = 7; rank >= 0; rank--) {
      var gap = 0;
      for (var file = 0; file < 8; file++) {
        final p = _sq[squareOf(file, rank)];
        if (p == empty) {
          gap++;
        } else {
          if (gap > 0) sb.write(gap);
          gap = 0;
          sb.write(pieceChar(p));
        }
      }
      if (gap > 0) sb.write(gap);
      if (rank > 0) sb.write('/');
    }
    sb.write(_side == white ? ' w ' : ' b ');
    var c = '';
    if (_castling & castleWK != 0) c += 'K';
    if (_castling & castleWQ != 0) c += 'Q';
    if (_castling & castleBK != 0) c += 'k';
    if (_castling & castleBQ != 0) c += 'q';
    sb.write(c.isEmpty ? '-' : c);
    sb.write(' ${_ep == -1 ? '-' : squareName(_ep)} $_halfmove $_fullmove');
    return sb.toString();
  }

  /// Whether [sq] is attacked by any piece of color [by].
  bool isAttacked(int sq, int by) {
    // Pawns: a white pawn on s attacks s+15 and s+17.
    final pw = makePiece(by, pawn);
    final dir = by == white ? -1 : 1;
    for (final d in const [15, 17]) {
      final s = sq + dir * d;
      if (onBoard(s) && _sq[s] == pw) return true;
    }
    final kn = makePiece(by, knight);
    for (final d in knightOffsets) {
      final s = sq + d;
      if (onBoard(s) && _sq[s] == kn) return true;
    }
    final kg = makePiece(by, king);
    for (final d in kingOffsets) {
      final s = sq + d;
      if (onBoard(s) && _sq[s] == kg) return true;
    }
    final b = makePiece(by, bishop), r = makePiece(by, rook);
    final q = makePiece(by, queen);
    for (final d in bishopOffsets) {
      for (var s = sq + d; onBoard(s); s += d) {
        final p = _sq[s];
        if (p == empty) continue;
        if (p == b || p == q) return true;
        break;
      }
    }
    for (final d in rookOffsets) {
      for (var s = sq + d; onBoard(s); s += d) {
        final p = _sq[s];
        if (p == empty) continue;
        if (p == r || p == q) return true;
        break;
      }
    }
    return false;
  }

  /// Whether the side to move is in check.
  bool get inCheck => isAttacked(_kings[_side], _side ^ 1);

  /// All pseudo-legal moves: they obey piece movement rules but may leave the
  /// mover's own king in check. Castling is fully checked here because its
  /// legality depends on intermediate squares.
  List<Move> pseudoLegalMoves() {
    final moves = <Move>[];
    final us = _side, them = _side ^ 1;
    for (var rank = 0; rank < 8; rank++) {
      for (var file = 0; file < 8; file++) {
        final from = squareOf(file, rank);
        final p = _sq[from];
        if (p == empty || pieceColor(p) != us) continue;
        switch (pieceType(p)) {
          case pawn:
            _pawnMoves(from, moves);
          case knight:
            _leaperMoves(from, knightOffsets, moves);
          case bishop:
            _sliderMoves(from, bishopOffsets, moves);
          case rook:
            _sliderMoves(from, rookOffsets, moves);
          case queen:
            _sliderMoves(from, bishopOffsets, moves);
            _sliderMoves(from, rookOffsets, moves);
          case king:
            _leaperMoves(from, kingOffsets, moves);
            _castlingMoves(from, us, them, moves);
        }
      }
    }
    return moves;
  }

  void _pawnMoves(int from, List<Move> out) {
    final us = _side;
    final fwd = us == white ? 16 : -16;
    final startRank = us == white ? 1 : 6;
    final lastRank = us == white ? 7 : 0;
    void add(int to, int flags) {
      if (rankOf(to) == lastRank) {
        for (final promo in const [queen, rook, bishop, knight]) {
          out.add(Move(from, to, promotion: promo, flags: flags));
        }
      } else {
        out.add(Move(from, to, flags: flags));
      }
    }

    final one = from + fwd;
    if (onBoard(one) && _sq[one] == empty) {
      add(one, 0);
      final two = one + fwd;
      if (rankOf(from) == startRank && _sq[two] == empty) {
        out.add(Move(from, two, flags: Move.doublePush));
      }
    }
    for (final side in const [-1, 1]) {
      final to = from + fwd + side;
      if (!onBoard(to)) continue;
      final t = _sq[to];
      if (t != empty && pieceColor(t) != us) {
        add(to, Move.capture);
      } else if (to == _ep) {
        out.add(Move(from, to, flags: Move.capture | Move.enPassant));
      }
    }
  }

  void _leaperMoves(int from, List<int> offsets, List<Move> out) {
    for (final d in offsets) {
      final to = from + d;
      if (!onBoard(to)) continue;
      final t = _sq[to];
      if (t == empty) {
        out.add(Move(from, to));
      } else if (pieceColor(t) != _side) {
        out.add(Move(from, to, flags: Move.capture));
      }
    }
  }

  void _sliderMoves(int from, List<int> offsets, List<Move> out) {
    for (final d in offsets) {
      for (var to = from + d; onBoard(to); to += d) {
        final t = _sq[to];
        if (t == empty) {
          out.add(Move(from, to));
          continue;
        }
        if (pieceColor(t) != _side) {
          out.add(Move(from, to, flags: Move.capture));
        }
        break;
      }
    }
  }

  void _castlingMoves(int from, int us, int them, List<Move> out) {
    final rank = us == white ? 0 : 7;
    if (from != squareOf(4, rank)) return;
    final kBit = us == white ? castleWK : castleBK;
    final qBit = us == white ? castleWQ : castleBQ;
    if (_castling & (kBit | qBit) == 0) return;
    if (isAttacked(from, them)) return;
    if (_castling & kBit != 0 &&
        _sq[from + 1] == empty &&
        _sq[from + 2] == empty &&
        !isAttacked(from + 1, them) &&
        !isAttacked(from + 2, them)) {
      out.add(Move(from, from + 2, flags: Move.castling));
    }
    if (_castling & qBit != 0 &&
        _sq[from - 1] == empty &&
        _sq[from - 2] == empty &&
        _sq[from - 3] == empty &&
        !isAttacked(from - 1, them) &&
        !isAttacked(from - 2, them)) {
      out.add(Move(from, from - 2, flags: Move.castling));
    }
  }

  /// All legal moves for the side to move.
  List<Move> legalMoves() {
    final legal = <Move>[];
    final us = _side;
    for (final m in pseudoLegalMoves()) {
      make(m);
      if (!isAttacked(_kings[us], us ^ 1)) legal.add(m);
      unmake();
    }
    return legal;
  }

  /// Applies [m] without checking legality. Use [legalMoves] (or the
  /// higher-level game API) to obtain moves that are safe to pass here.
  void make(Move m) {
    final us = _side;
    final piece = _sq[m.from];
    var captured = _sq[m.to];
    var capSq = m.to;
    if (m.isEnPassant) {
      capSq = m.to + (us == white ? -16 : 16);
      captured = _sq[capSq];
    }
    _history.add(_Undo(m, captured, _castling, _ep, _halfmove, _hash));

    var h = _hash ^ _epKey() ^ castlingKeys[_castling] ^ sideKey;
    final placed = m.isPromotion ? makePiece(us, m.promotion) : piece;
    h ^= pieceKeys[piece * 128 + m.from] ^ pieceKeys[placed * 128 + m.to];
    if (captured != empty) h ^= pieceKeys[captured * 128 + capSq];

    if (m.isEnPassant) _sq[capSq] = empty;
    _sq[m.to] = placed;
    _sq[m.from] = empty;

    if (pieceType(piece) == king) {
      _kings[us] = m.to;
      if (m.isCastling) {
        final kingSide = m.to > m.from;
        final rookFrom = kingSide ? m.from + 3 : m.from - 4;
        final rookTo = kingSide ? m.from + 1 : m.from - 1;
        final r = _sq[rookFrom];
        _sq[rookTo] = r;
        _sq[rookFrom] = empty;
        h ^= pieceKeys[r * 128 + rookFrom] ^ pieceKeys[r * 128 + rookTo];
      }
    }

    _castling &= _castleMask[m.from] & _castleMask[m.to];
    _ep = m.isDoublePush ? (m.from + m.to) >> 1 : -1;
    _halfmove =
        (pieceType(piece) == pawn || captured != empty) ? 0 : _halfmove + 1;
    if (us == black) _fullmove++;
    _side = us ^ 1;
    _hash = h ^ castlingKeys[_castling] ^ _epKey();
  }

  /// Passes the turn without moving (a "null move"), used by search
  /// heuristics. Must not be called while in check. Undo with [unmake].
  void makeNull() {
    _history.add(_Undo(_nullMove, empty, _castling, _ep, _halfmove, _hash));
    _hash ^= _epKey() ^ sideKey;
    _ep = -1;
    _halfmove++;
    if (_side == black) _fullmove++;
    _side ^= 1;
  }

  static const Move _nullMove = Move(0, 0);

  /// Reverts the most recent [make]. Throws [StateError] if there is none.
  void unmake() {
    if (_history.isEmpty) throw StateError('no move to unmake');
    final u = _history.removeLast();
    final m = u.move;
    _side ^= 1;
    final us = _side;
    if (us == black) _fullmove--;
    _castling = u.castling;
    _ep = u.epSquare;
    _halfmove = u.halfmove;
    _hash = u.hash;
    if (identical(m, _nullMove)) return;

    final moved = m.isPromotion ? makePiece(us, pawn) : _sq[m.to];
    _sq[m.from] = moved;
    if (m.isEnPassant) {
      _sq[m.to] = empty;
      _sq[m.to + (us == white ? -16 : 16)] = u.captured;
    } else {
      _sq[m.to] = u.captured;
    }
    if (pieceType(moved) == king) {
      _kings[us] = m.from;
      if (m.isCastling) {
        final kingSide = m.to > m.from;
        final rookFrom = kingSide ? m.from + 3 : m.from - 4;
        final rookTo = kingSide ? m.from + 1 : m.from - 1;
        _sq[rookFrom] = _sq[rookTo];
        _sq[rookTo] = empty;
      }
    }
  }

  /// Finds the legal move matching a UCI string such as `e2e4` or `a7a8q`.
  /// Returns null if no legal move matches.
  Move? moveFromUci(String uci) {
    for (final m in legalMoves()) {
      if (m.uci == uci) return m;
    }
    return null;
  }

  /// A human-readable diagram, White at the bottom.
  String get ascii {
    final sb = StringBuffer();
    for (var rank = 7; rank >= 0; rank--) {
      sb.write('${rank + 1} ');
      for (var file = 0; file < 8; file++) {
        final p = _sq[squareOf(file, rank)];
        sb.write(p == empty ? '.' : pieceChar(p));
        if (file < 7) sb.write(' ');
      }
      sb.writeln();
    }
    sb.write('  a b c d e f g h');
    return sb.toString();
  }

  @override
  String toString() => fen;
}
