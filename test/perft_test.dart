import 'package:dartchess/dartchess.dart';
import 'package:test/test.dart';

/// Reference counts from the Chess Programming Wiki "Perft Results" page.
const _cases = <(String, String, List<int>)>[
  ('start', startFen, [20, 400, 8902, 197281]),
  (
    'kiwipete',
    'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1',
    [48, 2039, 97862],
  ),
  (
    'position 3',
    '8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1',
    [14, 191, 2812, 43238, 674624]
  ),
  (
    'position 4',
    'r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1',
    [6, 264, 9467, 422333],
  ),
  (
    'position 4 mirrored',
    'r2q1rk1/pP1p2pp/Q4n2/bbp1p3/Np6/1B3NBn/pPPP1PPP/R3K2R b KQ - 0 1',
    [6, 264, 9467, 422333],
  ),
  (
    'position 5',
    'rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8',
    [44, 1486, 62379],
  ),
  (
    'position 6',
    'r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10',
    [46, 2079, 89890],
  ),
];

void main() {
  for (final (name, fen, counts) in _cases) {
    group('perft $name', () {
      for (var d = 0; d < counts.length; d++) {
        test('depth ${d + 1} = ${counts[d]}', () {
          final b = Board.fromFen(fen);
          expect(perft(b, d + 1), counts[d]);
          expect(b.fen, Board.fromFen(fen).fen,
              reason: 'make/unmake must restore the position exactly');
        });
      }
    });
  }

  group('edge-case perft (en passant pins, promotions, castling through check)',
      () {
    // Positions from Martin Sedlak's "perftsuite" special cases.
    const special = <(String, int, int)>[
      ('3k4/3p4/8/K1P4r/8/8/8/8 b - - 0 1', 6, 1134888), // ep discovers check
      ('8/8/4k3/8/2p5/8/B2P2K1/8 w - - 0 1', 6, 1015133), // ep pin
      ('8/8/1k6/2b5/2pP4/8/5K2/8 b - d3 0 1', 6, 1440467), // ep capture ok
      ('5k2/8/8/8/8/8/8/4K2R w K - 0 1', 6, 661072), // short castle gives check
      ('3k4/8/8/8/8/8/8/R3K3 w Q - 0 1', 6, 803711), // long castle gives check
      ('r3k2r/1b4bq/8/8/8/8/7B/R3K2R w KQkq - 0 1', 4, 1274206), // castling
      ('r3k2r/8/3Q4/8/8/5q2/8/R3K2R b KQkq - 0 1', 4, 1720476), // no castling
      ('2K2r2/4P3/8/8/8/8/8/3k4 w - - 0 1', 6, 3821001), // promote out of check
      ('8/8/1P2K3/8/2n5/1q6/8/5k2 b - - 0 1', 5, 1004658), // discovered check
      ('4k3/1P6/8/8/8/8/K7/8 w - - 0 1', 6, 217342), // promote to give check
      ('8/P1k5/K7/8/8/8/8/8 w - - 0 1', 6, 92683), // underpromote
      ('K1k5/8/P7/8/8/8/8/8 w - - 0 1', 6, 2217), // self stalemate
      ('8/k1P5/8/1K6/8/8/8/8 w - - 0 1', 7, 567584), // stalemate and checkmate
      ('8/8/2k5/5q2/5n2/8/5K2/8 b - - 0 1', 4, 23527), // double check
    ];
    for (final (fen, depth, nodes) in special) {
      test('$fen d$depth', () {
        expect(perft(Board.fromFen(fen), depth), nodes);
      });
    }
  });

  test('divide sums to perft', () {
    final b = Board.fromFen(_cases[1].$2);
    final d = divide(b, 3);
    expect(d.length, 48);
    expect(d.values.reduce((a, c) => a + c), 97862);
    expect(d['e1g1'], 2059);
  });
}
