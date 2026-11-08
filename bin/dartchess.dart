import 'dart:convert';
import 'dart:io';

import 'package:dartchess/dartchess.dart';

const _usage = '''
Usage: dartchess <command> [arguments]

Commands:
  uci                         Run as a UCI engine on stdin/stdout (default)
  perft <depth> [fen]         Count leaf nodes of the move tree
  divide <depth> [fen]        Perft broken down by root move
  best [--depth N] [--time MS] [fen]
                              Search a position and print the best move
  selfplay [--depth N] [--fen FEN] [--max-moves N]
                              Let the engine play itself; prints PGN
  pgn <file>                  Validate a PGN file and print it normalised
''';

Never _fail(String msg) {
  stderr.writeln('dartchess: $msg');
  stderr.write(_usage);
  exit(64);
}

int _intOpt(List<String> args, String name, int fallback) {
  final i = args.indexOf(name);
  if (i < 0) return fallback;
  if (i + 1 >= args.length) _fail('$name needs a value');
  final v = int.tryParse(args[i + 1]);
  if (v == null || v < 1) _fail('$name must be a positive integer');
  args.removeRange(i, i + 2);
  return v;
}

String? _strOpt(List<String> args, String name) {
  final i = args.indexOf(name);
  if (i < 0) return null;
  if (i + 1 >= args.length) _fail('$name needs a value');
  final v = args[i + 1];
  args.removeRange(i, i + 2);
  return v;
}

Board _board(List<String> rest) {
  try {
    return rest.isEmpty ? Board() : Board.fromFen(rest.join(' '));
  } on FormatException catch (e) {
    _fail('invalid FEN: ${e.message}');
  }
}

Future<void> main(List<String> argv) async {
  final args = List.of(argv);
  final cmd = args.isEmpty ? 'uci' : args.removeAt(0);
  switch (cmd) {
    case 'uci':
      final uci = UciProtocol(stdout.writeln);
      await for (final line
          in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
        uci.handle(line);
        if (uci.quit) break;
      }
    case 'perft' || 'divide':
      if (args.isEmpty) _fail('$cmd needs a depth');
      final depth = int.tryParse(args.removeAt(0));
      if (depth == null || depth < 1) _fail('depth must be a positive integer');
      final b = _board(args);
      final sw = Stopwatch()..start();
      var nodes = 0;
      if (cmd == 'divide') {
        final d = divide(b, depth);
        for (final e in d.entries) {
          stdout.writeln('${e.key}: ${e.value}');
        }
        nodes = d.values.fold(0, (a, n) => a + n);
        stdout.writeln();
      } else {
        nodes = perft(b, depth);
      }
      final ms = sw.elapsedMilliseconds;
      stdout.writeln('nodes $nodes  time ${ms}ms'
          '${ms > 0 ? '  nps ${nodes * 1000 ~/ ms}' : ''}');
    case 'best':
      final depth = _intOpt(args, '--depth', 64);
      final time = _intOpt(args, '--time', 2000);
      final b = _board(args);
      final r = Engine().search(b,
          maxDepth: depth,
          timeLimit: Duration(milliseconds: time),
          onInfo: (i) => stdout.writeln('depth ${i.depth}  score '
              '${i.mateIn != null ? 'mate ${i.mateIn}' : i.score}  '
              'nodes ${i.nodes}  pv ${i.pv.join(' ')}'));
      if (r.bestMove == null) {
        stdout.writeln(b.inCheck ? 'checkmated' : 'stalemate');
      } else {
        stdout.writeln('bestmove ${r.bestMove!.uci} '
            '(${toSan(b, r.bestMove!)})');
      }
    case 'selfplay':
      final depth = _intOpt(args, '--depth', 4);
      final maxMoves = _intOpt(args, '--max-moves', 200);
      final fen = _strOpt(args, '--fen') ?? startFen;
      final Game g;
      try {
        g = Game(fen);
      } on FormatException catch (e) {
        _fail('invalid FEN: ${e.message}');
      }
      final engine = Engine();
      while (!g.isOver && g.sanMoves.length < maxMoves * 2) {
        g.playMove(engine.search(g.board, maxDepth: depth).bestMove!);
      }
      stdout.write(gameToPgn(g, headers: {
        'Event': 'dartchess self-play',
        'White': 'dartchess depth $depth',
        'Black': 'dartchess depth $depth',
        'Termination': g.status.name,
      }));
    case 'pgn':
      if (args.isEmpty) _fail('pgn needs a file');
      try {
        final p = parsePgn(File(args.first).readAsStringSync());
        stdout.write(gameToPgn(p.game, headers: p.headers));
      } on FileSystemException catch (e) {
        _fail('cannot read ${args.first}: ${e.osError?.message ?? e.message}');
      } on FormatException catch (e) {
        stderr.writeln('dartchess: invalid PGN: ${e.message}');
        exit(65);
      }
    case '-h' || '--help' || 'help':
      stdout.write(_usage);
    default:
      _fail('unknown command "$cmd"');
  }
}
