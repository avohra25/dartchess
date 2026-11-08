# dartchess

A dependency-free chess library for Dart. It represents positions on a 0x88
board, parses and writes FEN, generates fully legal moves (castling, en passant,
promotions, pins and checks), and is verified with perft against published
reference counts. On top of that it speaks Standard Algebraic Notation and
tracks full game state: Zobrist hashing, repetition, the fifty/seventy-five
move rules and insufficient material.

```dart
import 'package:dartchess/dartchess.dart';

void main() {
  final board = Board();                 // starting position
  board.make(board.moveFromUci('e2e4')!);
  print(board.fen);                      // ... b KQkq e3 0 1
  print(board.legalMoves().length);      // 20
  print(perft(Board(), 4));              // 197281
}
```

### Games and SAN

```dart
final game = Game();
for (final m in ['f3', 'e5', 'g4', 'Qh4']) {
  game.play(m);                          // SAN or UCI
}
print(game.sanMoves);                    // [f3, e5, g4, Qh4#]
print(game.status);                      // GameStatus.checkmate
print(game.result);                      // 0-1
```

`toSan` produces minimal disambiguation (`Nbd2`, `R1a3`, `Qa1b2`) and
`parseSan` accepts common variants such as `0-0`, `e8Q` and trailing `+`/`!?`.

## Development

```sh
dart pub get
dart analyze
dart test
```

The test suite runs perft on the standard Chess Programming Wiki positions and
on a set of edge-case positions (en passant discovered checks, castling through
check, under-promotion, stalemate traps).

## License

MIT
