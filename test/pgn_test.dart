import 'package:dartchess/dartchess.dart';
import 'package:test/test.dart';

const _opera = '''
[Event "A Night at the Opera"]
[Site "Paris FRA"]
[Date "1858.??.??"]
[Round "?"]
[White "Paul Morphy"]
[Black "Duke Karl / Count Isouard"]
[Result "1-0"]

1. e4 e5 2. Nf3 d6 3. d4 Bg4 {This is a weak move already.} 4. dxe5 Bxf3
5. Qxf3 dxe5 6. Bc4 Nf6 7. Qb3 Qe7 8. Nc3 (8. Qxb7 Qb4+ 9. Qxb4 Bxb4+) c6
9. Bg5 \$1 b5 10. Nxb5 cxb5 11. Bxb5+ Nbd7 12. O-O-O Rd8 13. Rxd7 Rxd7
14. Rd1 Qe6 15. Bxd7+ Nxd7 16. Qb8+ Nxb8 17. Rd8# 1-0
''';

void main() {
  test('parses a real game with comments, variations and NAGs', () {
    final p = parsePgn(_opera);
    expect(p.headers['White'], 'Paul Morphy');
    expect(p.result, '1-0');
    expect(p.game.sanMoves, hasLength(33));
    expect(p.game.sanMoves.last, 'Rd8#');
    expect(p.game.status, GameStatus.checkmate);
    expect(p.game.result, '1-0');
  });

  test('export then re-import round-trips', () {
    final p = parsePgn(_opera);
    final text = gameToPgn(p.game, headers: p.headers);
    expect(text, startsWith('[Event "A Night at the Opera"]\n'));
    expect(text, contains('[Result "1-0"]'));
    expect(text.split('\n').every((l) => l.length <= 80), isTrue);
    final again = parsePgn(text);
    expect(again.game.sanMoves, p.game.sanMoves);
    expect(again.headers, p.headers);
  });

  test('custom start positions use SetUp/FEN and black-first numbering', () {
    const fen = '4k3/8/8/8/8/8/7p/R3K3 b Q - 0 40';
    final g = Game(fen);
    g.play('Kd7');
    g.play('O-O-O+');
    final text = gameToPgn(g);
    expect(text, contains('[SetUp "1"]'));
    expect(text, contains('[FEN "$fen"]'));
    expect(text, contains('40... Kd7 41. O-O-O+ *'));
    expect(parsePgn(text).game.board.fen, g.board.fen);
  });

  test('default tags and escaping', () {
    final text = gameToPgn(Game(), headers: {'White': 'A "quoted" name'});
    expect(text, contains(r'[White "A \"quoted\" name"]'));
    expect(text, contains('[Date "????.??.??"]'));
    expect(parsePgn(text).headers['White'], 'A "quoted" name');
  });

  test('tolerates glued move numbers, line comments and no result', () {
    final p = parsePgn('1.e4 e5 ; a comment (with parens\n2.Nf3 (2.f4) Nc6');
    expect(p.game.sanMoves, ['e4', 'e5', 'Nf3', 'Nc6']);
    expect(p.result, '*');
  });

  for (final (name, bad) in [
    ('illegal move', '1. e4 e5 2. Ke3'),
    ('unbalanced variation', '1. e4 (1. d4 e5'),
    ('stray close paren', '1. e4 ) e5'),
    ('unterminated comment', '1. e4 {oops'),
    ('move after result', '1. e4 1-0 e5'),
    ('bad tag', '[Event unquoted]\n1. e4'),
  ]) {
    test('rejects $name', () {
      expect(() => parsePgn(bad), throwsFormatException);
    });
  }
}
