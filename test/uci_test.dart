import 'package:dartchess/dartchess.dart';
import 'package:test/test.dart';

(UciProtocol, List<String>) _uci() {
  final out = <String>[];
  return (UciProtocol(out.add, engine: Engine(ttBits: 16)), out);
}

void main() {
  test('handshake', () {
    final (uci, out) = _uci();
    uci.handle('uci');
    uci.handle('isready');
    expect(out.first, startsWith('id name dartchess'));
    expect(out, containsAllInOrder(['uciok', 'readyok']));
  });

  test('position startpos with moves', () {
    final (uci, _) = _uci();
    uci.handle('position startpos moves e2e4 c7c5 g1f3');
    expect(uci.board.fen,
        'rnbqkbnr/pp1ppppp/8/2p5/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2');
  });

  test('position fen with moves and errors', () {
    final (uci, out) = _uci();
    uci.handle('position fen 4k3/8/8/8/8/8/8/R3K3 w Q - 0 1 moves e1c1');
    expect(uci.board.fen, '4k3/8/8/8/8/8/8/2KR4 b - - 1 1');
    uci.handle('position startpos moves e2e5');
    expect(out.last, 'info string illegal move e2e5');
    uci.handle('position fen not a fen');
    expect(out.last, startsWith('info string invalid FEN'));
    expect(uci.board.fen, '4k3/8/8/8/8/8/8/2KR4 b - - 1 1',
        reason: 'a bad command must not clobber the position');
  });

  test('go depth reports info lines and a mating bestmove', () {
    final (uci, out) = _uci();
    uci.handle('position fen 6k1/5ppp/8/8/8/8/8/R3K3 w - - 0 1');
    uci.handle('go depth 3');
    expect(out.where((l) => l.startsWith('info depth')), isNotEmpty);
    expect(out.any((l) => l.contains('score mate 1')), isTrue);
    expect(out.last, 'bestmove a1a8');
  });

  test('go with clock and nodes limits', () {
    final (uci, out) = _uci();
    uci.handle('position startpos');
    final sw = Stopwatch()..start();
    uci.handle('go wtime 3000 btime 3000 winc 0 binc 0');
    expect(sw.elapsedMilliseconds, lessThan(2000));
    expect(out.last, matches(RegExp(r'^bestmove [a-h][1-8][a-h][1-8]$')));
    uci.handle('go nodes 2000');
    expect(out.last, startsWith('bestmove '));
    uci.handle('go movetime 50');
    expect(out.last, startsWith('bestmove '));
  });

  test('bestmove 0000 when there are no legal moves', () {
    final (uci, out) = _uci();
    uci.handle('position fen 7k/5Q2/6K1/8/8/8/8/8 b - - 0 1');
    uci.handle('go depth 2');
    expect(out.last, 'bestmove 0000');
  });

  test('perft, display, unknown and quit', () {
    final (uci, out) = _uci();
    uci.handle('perft 3');
    expect(out.last, 'Nodes searched: 8902');
    uci.handle('d');
    expect(out.any((l) => l.startsWith('Fen: rnbqkbnr')), isTrue);
    uci.handle('frobnicate');
    expect(out.last, 'info string unknown command: frobnicate');
    uci.handle('');
    expect(uci.quit, isFalse);
    uci.handle('quit');
    expect(uci.quit, isTrue);
  });
}
