/// Zobrist hashing keys, generated deterministically so hashes are stable
/// across runs (useful for opening books and reproducible tests).
library;

final class _SplitMix64 {
  int _state;
  _SplitMix64(this._state);

  int next() {
    _state = (_state + 0x9E3779B97F4A7C15) & 0xFFFFFFFFFFFFFFFF;
    var z = _state;
    z = ((z ^ (z >>> 30)) * 0xBF58476D1CE4E5B9) & 0xFFFFFFFFFFFFFFFF;
    z = ((z ^ (z >>> 27)) * 0x94D049BB133111EB) & 0xFFFFFFFFFFFFFFFF;
    return z ^ (z >>> 31);
  }
}

final _rng = _SplitMix64(0x5EED0C4E55);

/// Indexed by `piece * 128 + square` (0x88 square, piece code 0..15).
final List<int> pieceKeys = List<int>.generate(16 * 128, (_) => _rng.next());
final int sideKey = _rng.next();

/// Indexed by the 4-bit castling rights value.
final List<int> castlingKeys = List<int>.generate(16, (_) => _rng.next());

/// Indexed by the file of the en passant target square.
final List<int> epFileKeys = List<int>.generate(8, (_) => _rng.next());
