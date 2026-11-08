import 'package:dartchess/dartchess.dart';
import 'package:test/test.dart';

void main() {
  test("fool's mate", () {
    final g = Game();
    for (final m in ['f3', 'e5', 'g4', 'Qh4']) {
      g.play(m);
    }
    expect(g.sanMoves, ['f3', 'e5', 'g4', 'Qh4#']);
    expect(g.status, GameStatus.checkmate);
    expect(g.result, '0-1');
    expect(g.isOver, isTrue);
  });

  test('accepts UCI and SAN, and undo restores the position', () {
    final g = Game();
    expect(g.play('e2e4'), 'e4');
    expect(g.play('c5'), 'c5');
    expect(g.undo(), isTrue);
    expect(g.undo(), isTrue);
    expect(g.undo(), isFalse);
    expect(g.board.fen, startFen);
    expect(() => g.play('e5'), throwsFormatException);
  });

  test('stalemate', () {
    final g = Game('7k/8/6K1/8/8/8/8/5Q2 w - - 0 1');
    g.play('Qf7');
    expect(g.status, GameStatus.stalemate);
    expect(g.result, '1/2-1/2');
  });

  test('threefold and fivefold repetition', () {
    final g = Game();
    expect(g.status, GameStatus.ongoing);
    void shuffle() {
      for (final m in ['Nf3', 'Nf6', 'Ng1', 'Ng8']) {
        g.play(m);
      }
    }

    shuffle();
    expect(g.status, GameStatus.ongoing); // second occurrence
    shuffle();
    expect(g.status, GameStatus.threefoldRepetition);
    g.undo();
    expect(g.status, GameStatus.ongoing);
    g.play('Ng8');
    shuffle();
    shuffle();
    expect(g.status, GameStatus.fivefoldRepetition);
  });

  test('a lost castling right breaks the repetition', () {
    final g = Game('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1');
    for (final m in ['Ke2', 'Ke7', 'Ke1', 'Ke8', 'Ke2', 'Ke7', 'Ke1', 'Ke8']) {
      g.play(m);
    }
    // The start position (with rights) is gone; the rights-less one occurred
    // twice, so it is not yet a threefold repetition.
    expect(g.status, GameStatus.ongoing);
  });

  test('fifty and seventy-five move rules', () {
    expect(Game('4k3/8/8/8/8/8/8/R3K3 w - - 99 80').status, GameStatus.ongoing);
    expect(Game('4k3/8/8/8/8/8/8/R3K3 w - - 100 80').status,
        GameStatus.fiftyMoveRule);
    expect(Game('4k3/8/8/8/8/8/8/R3K3 w - - 150 80').status,
        GameStatus.seventyFiveMoveRule);
    // Checkmate on the fiftieth move takes precedence.
    expect(Game('R5k1/5ppp/8/8/8/8/8/4K3 b - - 100 80').status,
        GameStatus.checkmate);
  });

  group('insufficient material', () {
    for (final (fen, expected) in [
      ('4k3/8/8/8/8/8/8/4K3 w - - 0 1', true),
      ('4k3/8/8/8/8/8/8/2N1K3 w - - 0 1', true),
      ('4k3/8/8/8/8/8/8/2B1K3 w - - 0 1', true),
      ('2b1k3/8/8/8/8/8/8/2B1K3 w - - 0 1', false), // opposite colours
      ('3bk3/8/8/8/8/8/8/2B1K3 w - - 0 1', true), // same colour
      ('4k3/8/8/8/8/8/8/1NN1K3 w - - 0 1', false),
      ('4k3/8/8/8/8/8/8/2BNK3 w - - 0 1', false),
      ('4k3/8/8/8/8/8/P7/4K3 w - - 0 1', false),
      ('4k3/8/8/8/8/8/8/3RK3 w - - 0 1', false),
    ]) {
      test(fen, () {
        expect(Board.fromFen(fen).insufficientMaterial, expected);
        expect(Game(fen).status == GameStatus.insufficientMaterial, expected);
      });
    }
  });
}
