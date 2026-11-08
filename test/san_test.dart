import 'package:dartchess/dartchess.dart';
import 'package:test/test.dart';

String _san(String fen, String uci) {
  final b = Board.fromFen(fen);
  return toSan(b, b.moveFromUci(uci)!);
}

void main() {
  group('toSan', () {
    test('pawn and piece moves', () {
      expect(_san(startFen, 'e2e4'), 'e4');
      expect(_san(startFen, 'g1f3'), 'Nf3');
    });

    test('captures, en passant and promotions', () {
      const fen = 'r3k3/1P6/8/3pP3/8/8/8/4K3 w q d6 0 1';
      expect(_san(fen, 'e5d6'), 'exd6');
      expect(_san(fen, 'b7a8q'), 'bxa8=Q+');
      expect(_san(fen, 'b7b8n'), 'b8=N');
      expect(_san(fen, 'b7b8r'), 'b8=R+');
    });

    test('castling', () {
      const fen = 'r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1';
      expect(_san(fen, 'e1g1'), 'O-O');
      expect(_san(fen, 'e1c1'), 'O-O-O');
    });

    test('disambiguation by file, rank, and square', () {
      expect(_san('4k3/8/8/8/8/8/8/1N2KN2 w - - 0 1', 'b1d2'), 'Nbd2');
      expect(_san('4k3/8/8/8/R7/8/8/R3K3 w - - 0 1', 'a1a3'), 'R1a3');
      expect(_san('8/7k/8/8/7K/Q7/8/Q1Q5 w - - 0 1', 'a1b2'), 'Qa1b2');
      // A pinned piece does not count as an alternative.
      expect(_san('4k3/4r3/8/8/8/8/4N3/1N2K3 w - - 0 1', 'b1c3'), 'Nc3');
    });

    test('check and mate suffixes', () {
      expect(_san('4k3/8/8/8/8/8/8/R3K3 w - - 0 1', 'a1a8'), 'Ra8+');
      expect(_san('6k1/5ppp/8/8/8/8/8/R3K3 w - - 0 1', 'a1a8'), 'Ra8#');
    });
  });

  group('parseSan', () {
    test('round-trips every legal move in tricky positions', () {
      for (final fen in [
        startFen,
        'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1',
        'r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1',
        '8/7k/8/8/7K/Q7/8/Q1Q5 w - - 0 1',
      ]) {
        final b = Board.fromFen(fen);
        for (final m in b.legalMoves()) {
          expect(parseSan(b, toSan(b, m)), m, reason: '$fen ${m.uci}');
        }
      }
    });

    test('lenient input forms', () {
      final b = Board.fromFen('r3k3/1P6/8/8/8/8/8/R3K2R w KQq - 0 1');
      expect(parseSan(b, '0-0').uci, 'e1g1');
      expect(parseSan(b, 'O-O-O!?').uci, 'e1c1');
      expect(parseSan(b, 'b8Q').uci, 'b7b8q');
      expect(parseSan(b, 'bxa8N').uci, 'b7a8n');
      expect(parseSan(b, 'Rh1h7').uci, 'h1h7');
      expect(parseSan(Board(), 'Nf3+').uci, 'g1f3');
    });

    test('rejects illegal or ambiguous input', () {
      final b = Board.fromFen('4k3/8/8/8/8/8/8/1N2KN2 w - - 0 1');
      expect(() => parseSan(b, 'Nd2'), throwsFormatException);
      expect(() => parseSan(Board(), 'e5'), throwsFormatException);
      expect(() => parseSan(Board(), 'Ke2'), throwsFormatException);
      expect(() => parseSan(Board(), 'hello'), throwsFormatException);
    });
  });
}
