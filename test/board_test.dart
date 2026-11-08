import 'package:dartchess/dartchess.dart';
import 'package:test/test.dart';

void main() {
  group('FEN', () {
    test('round-trips well-formed positions', () {
      for (final fen in [
        startFen,
        'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1',
        'rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq c6 0 2',
        '8/8/8/8/8/8/8/K6k b - - 42 99',
      ]) {
        expect(Board.fromFen(fen).fen, fen);
      }
    });

    test('defaults missing move counters', () {
      expect(Board.fromFen('4k3/8/8/8/8/8/8/4K3 w - -').fen,
          '4k3/8/8/8/8/8/8/4K3 w - - 0 1');
    });

    test('drops castling rights that the placement contradicts', () {
      final b = Board.fromFen('4k3/8/8/8/8/8/8/4K3 w KQkq - 0 1');
      expect(b.castlingRights, 0);
    });

    for (final bad in [
      '',
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP w KQkq - 0 1', // 7 ranks
      'rnbqkbnr/pppppppp/9/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      'rnbqkbnr/pppppppp/7/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR x KQkq - 0 1',
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkx - 0 1',
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq e4 0 1',
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - -1 1',
      'rnbqxbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      'rnbq1bnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQ - 0 1', // no black king
      'kk6/8/8/8/8/8/8/K7 w - - 0 1', // two kings
      'P3k3/8/8/8/8/8/8/4K3 w - - 0 1', // pawn on 8th rank
      '4k3/8/8/8/8/8/8/R3K2r b - - 0 1', // side not to move in check
    ]) {
      test('rejects "$bad"', () {
        expect(() => Board.fromFen(bad), throwsFormatException);
      });
    }
  });

  group('moves', () {
    test('start position has 20 legal moves and is not check', () {
      final b = Board();
      expect(b.legalMoves(), hasLength(20));
      expect(b.inCheck, isFalse);
    });

    test('make/unmake updates and restores state', () {
      final b = Board();
      b.make(b.moveFromUci('e2e4')!);
      expect(
          b.fen, 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1');
      b.make(b.moveFromUci('g8f6')!);
      expect(b.fen,
          'rnbqkb1r/pppppppp/5n2/8/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 1 2');
      b.unmake();
      b.unmake();
      expect(b.fen, startFen);
      expect(() => b.unmake(), throwsStateError);
    });

    test('en passant capture removes the passed pawn', () {
      final b = Board.fromFen(
          'rnbqkbnr/ppp1p1pp/8/3pPp2/8/8/PPPP1PPP/RNBQKBNR w KQkq f6 0 3');
      final m = b.moveFromUci('e5f6')!;
      expect(m.isEnPassant, isTrue);
      b.make(m);
      expect(b.pieceAt(parseSquare('f5')), empty);
      b.unmake();
      expect(b.pieceAt(parseSquare('f5')), makePiece(black, pawn));
    });

    test('castling moves the rook and clears rights', () {
      final b = Board.fromFen('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1');
      b.make(b.moveFromUci('e1g1')!);
      expect(b.pieceAt(parseSquare('f1')), makePiece(white, rook));
      expect(b.pieceAt(parseSquare('h1')), empty);
      expect(b.fen, 'r3k2r/8/8/8/8/8/8/R4RK1 b kq - 1 1');
      b.make(b.moveFromUci('e8c8')!);
      expect(b.fen, '2kr3r/8/8/8/8/8/8/R4RK1 w - - 2 2');
    });

    test('capturing a rook on its home square removes that right', () {
      final b = Board.fromFen('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1');
      b.make(b.moveFromUci('a1a8')!);
      expect(b.castlingRights & 8, 0); // black queen-side gone
      expect(b.fen.split(' ')[2], 'Kk');
    });

    test('promotion offers all four pieces', () {
      final b = Board.fromFen('8/4P3/8/8/8/8/k7/4K3 w - - 0 1');
      final promos =
          b.legalMoves().where((m) => m.isPromotion).map((m) => m.uci);
      expect(promos, unorderedEquals(['e7e8q', 'e7e8r', 'e7e8b', 'e7e8n']));
    });

    test('pinned pieces cannot move off the pin line', () {
      final b = Board.fromFen('4k3/4r3/8/8/8/8/4B3/4K3 w - - 0 1');
      expect(b.legalMoves().where((m) => squareName(m.from) == 'e2'), isEmpty);
    });

    test('checkmate and stalemate have no legal moves', () {
      final mate = Board.fromFen(
          'rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3');
      expect(mate.inCheck, isTrue);
      expect(mate.legalMoves(), isEmpty);
      final stale = Board.fromFen('7k/5Q2/6K1/8/8/8/8/8 b - - 0 1');
      expect(stale.inCheck, isFalse);
      expect(stale.legalMoves(), isEmpty);
    });
  });
}
