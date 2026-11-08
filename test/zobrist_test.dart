import 'package:dartchess/dartchess.dart';
import 'package:test/test.dart';

/// Walks the move tree checking the incremental hash at every node.
int _walk(Board b, int depth) {
  expect(b.hash, b.computeHash(), reason: b.fen);
  if (depth == 0) return 1;
  var n = 0;
  for (final m in b.legalMoves()) {
    final before = b.hash;
    b.make(m);
    n += _walk(b, depth - 1);
    b.unmake();
    expect(b.hash, before);
  }
  return n;
}

void main() {
  test('incremental hash matches recomputation through the tree', () {
    for (final fen in [
      startFen,
      'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1',
      'r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1',
      '8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1',
    ]) {
      _walk(Board.fromFen(fen), 3);
    }
  });

  test('transpositions hash equal, different positions differ', () {
    final a = Board(), b = Board();
    for (final m in ['g1f3', 'g8f6', 'b1c3']) {
      a.make(a.moveFromUci(m)!);
    }
    for (final m in ['b1c3', 'g8f6', 'g1f3']) {
      b.make(b.moveFromUci(m)!);
    }
    expect(a.hash, b.hash);
    expect(a.fen, b.fen);
    expect(Board().hash, isNot(a.hash));
  });

  test('side to move and castling rights are part of the hash', () {
    const placement = 'r3k2r/8/8/8/8/8/8/R3K2R';
    final hashes = {
      for (final suffix in ['w KQkq', 'b KQkq', 'w Kkq', 'w -'])
        Board.fromFen('$placement $suffix - 0 1').hash,
    };
    expect(hashes, hasLength(4));
  });

  test('an uncapturable en passant square does not change the hash', () {
    final withEp = Board.fromFen(
      'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
    );
    final without = Board.fromFen(
      'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
    );
    expect(withEp.hash, without.hash);

    final capturable = Board.fromFen(
      'rnbqkbnr/ppp1pppp/8/8/3pP3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
    );
    final notCapturable = Board.fromFen(
      'rnbqkbnr/ppp1pppp/8/8/3pP3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
    );
    expect(capturable.hash, isNot(notCapturable.hash));
  });

  test('null move flips side, clears ep and unmakes cleanly', () {
    final b = Board.fromFen(
      'rnbqkbnr/ppp1pppp/8/8/3pP3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
    );
    final fen = b.fen, h = b.hash;
    b.makeNull();
    expect(b.sideToMove, white);
    expect(b.epSquare, -1);
    expect(b.hash, b.computeHash());
    expect(b.lastMove, isNull);
    b.unmake();
    expect(b.fen, fen);
    expect(b.hash, h);
  });
}
