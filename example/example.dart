import 'package:dartchess/dartchess.dart';

void main() {
  // Play the opening of the Italian Game and look at the position.
  final game = Game();
  for (final m in ['e4', 'e5', 'Nf3', 'Nc6', 'Bc4', 'Bc5']) {
    game.play(m);
  }
  print(game.board.ascii);
  print('FEN: ${game.board.fen}');
  print('${game.board.legalMoves().length} legal moves for White');

  // Ask the engine for a move.
  final result = Engine().search(game.board, maxDepth: 5);
  print('Engine suggests ${toSan(game.board, result.bestMove!)} '
      '(score ${result.score} cp, pv ${result.pv.join(' ')})');

  // Export the game so far.
  game.playMove(result.bestMove!);
  print(gameToPgn(game, headers: {'Event': 'Example'}));
}
