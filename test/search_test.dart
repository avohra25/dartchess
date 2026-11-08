import 'package:dartchess/dartchess.dart';
import 'package:test/test.dart';

SearchResult _search(String fen, {int depth = 6}) =>
    Engine(ttBits: 16).search(Board.fromFen(fen), maxDepth: depth);

void main() {
  group('evaluate', () {
    test('start position is balanced', () {
      expect(evaluate(Board()), 0);
    });

    test('is symmetric under colour flip', () {
      // Same position with colours swapped and side to move flipped.
      final a = Board.fromFen(
          'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3');
      final b = Board.fromFen(
          'rnbqkb1r/pppp1ppp/5n2/4p3/4P3/2N5/PPPP1PPP/R1BQKBNR b KQkq - 2 3');
      expect(evaluate(a), evaluate(b));
    });

    test('reflects material', () {
      final upQueen = Board.fromFen('4k3/8/8/8/8/8/8/3QK3 w - - 0 1');
      expect(evaluate(upQueen), greaterThan(800));
      final asBlack = Board.fromFen('4k3/8/8/8/8/8/8/3QK3 b - - 0 1');
      expect(evaluate(asBlack), lessThan(-800));
    });
  });

  group('tactics', () {
    test('mate in one', () {
      final r = _search('6k1/5ppp/8/8/8/8/8/R3K3 w - - 0 1', depth: 3);
      expect(r.bestMove!.uci, 'a1a8');
      expect(r.mateIn, 1);
    });

    test('mate in two with a quiet first move', () {
      // 1. Ra6! bxa6 2. b7#
      final r = _search('kbK5/pp6/1P6/8/8/8/8/R7 w - - 0 1');
      expect(r.mateIn, 2);
      expect(r.bestMove!.uci, 'a1a6');
    });

    test('back-rank mate in two', () {
      // Two rooks against a back rank defended by one rook.
      final r = _search('1r4k1/5ppp/8/8/8/8/5PPP/1R1R2K1 w - - 0 1');
      expect(r.mateIn, isNotNull);
      final b = Board.fromFen('1r4k1/5ppp/8/8/8/8/5PPP/1R1R2K1 w - - 0 1');
      for (final m in r.pv) {
        expect(b.legalMoves(), contains(m));
        b.make(m);
      }
      expect(b.legalMoves(), isEmpty);
      expect(b.inCheck, isTrue);
    });

    test('recognises being mated', () {
      final r = _search('6k1/5ppp/8/8/8/8/rr6/4K3 w - - 0 1', depth: 4);
      expect(r.mateIn, isNotNull);
      expect(r.mateIn!, lessThan(0));
    });

    test('wins a hanging queen', () {
      final r = _search(
          'rnb1kbnr/pppp1ppp/8/4p1q1/3P4/2N5/PPP1PPPP/R1BQKBNR w KQkq - 0 1',
          depth: 4);
      expect(r.bestMove!.uci, 'c1g5');
    });

    test('avoids stalemating when winning', () {
      // Qf7 would stalemate; anything sensible keeps the win.
      final b = Board.fromFen('7k/8/6K1/8/8/8/8/5Q2 w - - 0 1');
      final r = Engine().search(b, maxDepth: 5);
      b.make(r.bestMove!);
      expect(b.hasLegalMove || b.inCheck, isTrue);
      expect(r.score, greaterThan(500));
    });
  });

  group('engine behaviour', () {
    test('returns no move and a mate score when checkmated', () {
      final r = _search(
          'rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3');
      expect(r.bestMove, isNull);
      expect(r.score, -mateScore);
    });

    test('returns no move and zero when stalemated', () {
      final r = _search('7k/5Q2/6K1/8/8/8/8/8 b - - 0 1');
      expect(r.bestMove, isNull);
      expect(r.score, 0);
    });

    test('restores the board and reports increasing depths', () {
      final b = Board.fromFen(
          'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1');
      final fen = b.fen, hash = b.hash;
      final depths = <int>[];
      final r = Engine().search(b, maxDepth: 5, onInfo: (i) {
        depths.add(i.depth);
        expect(i.pv, isNotEmpty);
      });
      expect(b.fen, fen);
      expect(b.hash, hash);
      expect(depths, [1, 2, 3, 4, 5]);
      expect(b.legalMoves(), contains(r.bestMove));
    });

    test('principal variation is a legal line', () {
      final b = Board();
      final r = Engine().search(b, maxDepth: 5);
      for (final m in r.pv) {
        expect(b.legalMoves(), contains(m));
        b.make(m);
      }
    });

    test('node and stop limits still return a legal move', () {
      final b = Board.fromFen(
          'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1');
      final byNodes = Engine().search(b, nodeLimit: 3000);
      expect(b.legalMoves(), contains(byNodes.bestMove));
      expect(byNodes.depth, greaterThanOrEqualTo(1));

      final stopped = Engine().search(b, shouldStop: () => true);
      expect(stopped.depth, 1);
      expect(b.legalMoves(), contains(stopped.bestMove));

      final timed =
          Engine().search(b, timeLimit: const Duration(milliseconds: 200));
      expect(b.legalMoves(), contains(timed.bestMove));
    });

    test('is deterministic', () {
      final a = _search(startFen, depth: 5), b = _search(startFen, depth: 5);
      expect(a.bestMove, b.bestMove);
      expect(a.score, b.score);
      expect(a.nodes, b.nodes);
    });

    test('engine plays itself to a legal finished game', () {
      final g = Game('8/8/4k3/8/8/3K4/3Q4/8 w - - 0 1');
      final e = Engine(ttBits: 16);
      while (!g.isOver && g.sanMoves.length < 120) {
        g.playMove(e.search(g.board, maxDepth: 4).bestMove!);
      }
      expect(g.status, GameStatus.checkmate);
      expect(g.result, '1-0');
    });
  });

  test('mateDistance', () {
    expect(mateDistance(mateScore - 1), 1);
    expect(mateDistance(mateScore - 3), 2);
    expect(mateDistance(-mateScore + 2), -1);
    expect(mateDistance(150), isNull);
  });
}
