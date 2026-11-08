# dartchess

A dependency-free chess library for Dart. It represents positions on a 0x88
board, parses and writes FEN, generates fully legal moves (castling, en passant,
promotions, pins and checks), and is verified with perft against published
reference counts.

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
