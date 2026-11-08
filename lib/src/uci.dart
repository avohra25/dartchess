import 'board.dart';
import 'perft.dart';
import 'search.dart';

/// A Universal Chess Interface front end for [Engine].
///
/// Feed it one line at a time with [handle]; responses go to [output].
/// Searches run synchronously, so `go infinite` is treated as "search to the
/// maximum depth" rather than "until stop".
class UciProtocol {
  final void Function(String line) output;
  final Engine engine;
  Board _board = Board();
  bool _quit = false;

  static const String name = 'dartchess 0.2.0';

  UciProtocol(this.output, {Engine? engine}) : engine = engine ?? Engine();

  /// True after a `quit` command.
  bool get quit => _quit;

  /// The current position, as set by `position`.
  Board get board => _board;

  void handle(String line) {
    final args = line.trim().split(RegExp(r'\s+'));
    if (args.isEmpty || args.first.isEmpty) return;
    switch (args.first) {
      case 'uci':
        output('id name $name');
        output('id author avohra25');
        output('uciok');
      case 'isready':
        output('readyok');
      case 'ucinewgame':
        engine.clear();
        _board = Board();
      case 'position':
        _position(args.sublist(1));
      case 'go':
        _go(args.sublist(1));
      case 'd':
        output(_board.ascii);
        output('Fen: ${_board.fen}');
        output('Key: ${_board.hash.toUnsigned(64).toRadixString(16)}');
      case 'perft':
        final depth = args.length > 1 ? int.tryParse(args[1]) : null;
        if (depth == null || depth < 1) {
          output('info string usage: perft <depth>');
          return;
        }
        var total = 0;
        divide(_board, depth).forEach((m, n) {
          output('$m: $n');
          total += n;
        });
        output('');
        output('Nodes searched: $total');
      case 'stop' || 'setoption' || 'ponderhit' || 'register':
        break; // accepted; nothing to do for a synchronous engine
      case 'quit':
        _quit = true;
      default:
        output('info string unknown command: ${args.first}');
    }
  }

  void _position(List<String> args) {
    if (args.isEmpty) return;
    final movesAt = args.indexOf('moves');
    final spec = movesAt < 0 ? args : args.sublist(0, movesAt);
    final Board b;
    try {
      if (spec.first == 'startpos') {
        b = Board();
      } else if (spec.first == 'fen' && spec.length > 1) {
        b = Board.fromFen(spec.sublist(1).join(' '));
      } else {
        output('info string bad position command');
        return;
      }
    } on FormatException catch (e) {
      output('info string invalid FEN: ${e.message}');
      return;
    }
    if (movesAt >= 0) {
      for (final uci in args.sublist(movesAt + 1)) {
        final m = b.moveFromUci(uci);
        if (m == null) {
          output('info string illegal move $uci');
          return;
        }
        b.make(m);
      }
    }
    _board = b;
  }

  void _go(List<String> args) {
    int? opt(String key) {
      final i = args.indexOf(key);
      return i >= 0 && i + 1 < args.length ? int.tryParse(args[i + 1]) : null;
    }

    final depth = opt('depth') ?? 64;
    final nodes = opt('nodes');
    Duration? limit;
    if (opt('movetime') case final ms?) {
      limit = Duration(milliseconds: ms);
    } else if (!args.contains('infinite')) {
      final white = _board.sideToMove == 0;
      final left = opt(white ? 'wtime' : 'btime');
      final inc = opt(white ? 'winc' : 'binc') ?? 0;
      if (left != null) {
        final togo = opt('movestogo') ?? 30;
        var ms = left ~/ togo + inc * 3 ~/ 4;
        // Never plan to use more than half the clock, keep a safety margin.
        ms = ms.clamp(10, (left ~/ 2).clamp(10, 1 << 30));
        limit = Duration(milliseconds: ms);
      }
    }
    final result = engine.search(
      _board,
      maxDepth: depth,
      timeLimit: limit,
      nodeLimit: nodes,
      onInfo: (i) {
        final ms = i.elapsed.inMilliseconds;
        final nps = ms == 0 ? i.nodes * 1000 : i.nodes * 1000 ~/ ms;
        final score = i.mateIn != null ? 'mate ${i.mateIn}' : 'cp ${i.score}';
        output('info depth ${i.depth} score $score nodes ${i.nodes} '
            'nps $nps time $ms pv ${i.pv.join(' ')}');
      },
    );
    output('bestmove ${result.bestMove?.uci ?? '0000'}');
  }
}
