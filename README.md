# dartchess

A dependency-free chess library and engine for Dart. It parses and writes FEN,
generates fully legal moves (castling, en passant, promotions, pins and
checks), speaks SAN and PGN, tracks every game-ending rule, and includes an
alpha-beta engine that runs as a UCI engine in any chess GUI.

The move generator is verified with perft against the published Chess
Programming Wiki reference counts plus a suite of edge-case positions
(en passant discovered checks, castling through check, under-promotion,
stalemate traps), for example 4,865,609 nodes at depth 5 from the start
position.

## Library

```dart
import 'package:dartchess/dartchess.dart';

void main() {
  final board = Board();                  // starting position
  board.make(board.moveFromUci('e2e4')!);
  print(board.fen);                       // ... b KQkq e3 0 1
  print(board.legalMoves().length);       // 20
  print(perft(Board(), 4));               // 197281
}
```

### Games, SAN and PGN

```dart
final game = Game();
for (final m in ['f3', 'e5', 'g4', 'Qh4']) {
  game.play(m);                           // SAN or UCI
}
print(game.sanMoves);                     // [f3, e5, g4, Qh4#]
print(game.status);                       // GameStatus.checkmate
print(game.result);                       // 0-1
print(gameToPgn(game, headers: {'White': 'Me'}));

final imported = parsePgn(File('game.pgn').readAsStringSync());
print(imported.game.board.fen);
```

* `toSan` produces minimal disambiguation (`Nbd2`, `R1a3`, `Qa1b2`) and
  `parseSan` accepts common variants such as `0-0`, `e8Q` and trailing `+`/`!?`.
* `Game.status` reports checkmate, stalemate, insufficient material,
  threefold and fivefold repetition, and the 50 and 75 move rules.
  Repetition uses Zobrist hashes that only count an en passant square when a
  capture there is actually possible.
* `parsePgn` skips comments, recursive variations and NAGs, validates every
  mainline move by replaying it, and honours `SetUp`/`FEN` tags. `gameToPgn`
  writes the Seven Tag Roster and wraps movetext at 80 columns.

### Engine

```dart
final engine = Engine();
final result = engine.search(
  Board.fromFen('kbK5/pp6/1P6/8/8/8/8/R7 w - - 0 1'),
  maxDepth: 8,
  timeLimit: const Duration(seconds: 2),
  onInfo: (i) => print('depth ${i.depth} score ${i.score} pv ${i.pv}'),
);
print(result.bestMove);                   // a1a6
print(result.mateIn);                     // 2
```

The search is negamax alpha-beta with iterative deepening, principal
variation search, quiescence on captures, a Zobrist-keyed transposition table,
null-move pruning, check extensions, mate distance pruning and MVV-LVA,
killer and history move ordering. Draws by repetition, the fifty-move rule
and insufficient material are recognised inside the tree. Evaluation is
material plus piece-square tables, with a king table tapered by game phase
and a bishop pair bonus. It is a small teaching engine, not a Stockfish rival,
but it finds short mates and does not hang pieces.

## Command line

```sh
dart pub get
dart run bin/dartchess.dart perft 5
# nodes 4865609  time 640ms  nps 7600000

dart run bin/dartchess.dart best --time 1000 "kbK5/pp6/1P6/8/8/8/8/R7 w - - 0 1"
# depth 4  score mate 2  nodes 388  pv a1a6 b7a6 b6b7
# bestmove a1a6 (Ra6)

dart run bin/dartchess.dart selfplay --depth 3 --fen "8/8/4k3/8/8/3K4/3Q4/8 w - - 0 1"
dart run bin/dartchess.dart pgn game.pgn
```

To use it in a GUI such as Cute Chess or Arena, compile it and register the
binary as a UCI engine:

```sh
dart compile exe bin/dartchess.dart -o dartchess
printf 'uci\nposition startpos moves e2e4\ngo movetime 500\nquit\n' | ./dartchess
```

Supported UCI commands are `uci`, `isready`, `ucinewgame`, `position`
(`startpos` or `fen`, with `moves`), `go` (`depth`, `nodes`, `movetime`,
`wtime`/`btime`/`winc`/`binc`/`movestogo`, `infinite`), `quit`, plus the
debugging extras `d` (show the board) and `perft N`. Searches run
synchronously, so `go infinite` searches to the depth cap rather than waiting
for `stop`.

## Layout

| File | Contents |
|---|---|
| `lib/src/types.dart` | Piece and square encoding (0x88 board), helpers |
| `lib/src/board.dart` | Board, FEN, make/unmake, move generation, hashing |
| `lib/src/zobrist.dart` | Deterministic Zobrist keys |
| `lib/src/perft.dart` | `perft` and `divide` |
| `lib/src/san.dart` | SAN formatting and parsing |
| `lib/src/game.dart` | Game record and end-of-game rules |
| `lib/src/pgn.dart` | PGN import and export |
| `lib/src/eval.dart` | Static evaluation |
| `lib/src/search.dart` | The alpha-beta engine |
| `lib/src/uci.dart` | UCI protocol handler |
| `bin/dartchess.dart` | Command-line interface |

## Development

```sh
dart pub get
dart format --set-exit-if-changed .
dart analyze --fatal-infos
dart test
```

The suite (128 tests, a few seconds) covers perft, FEN validation, Zobrist
consistency checked at every node of a move tree, SAN round trips over every
legal move in tricky positions, repetition and draw rules, PGN round trips on
a real game, tactical search positions, and the UCI protocol.

## License

MIT
