import 'board.dart';
import 'game.dart';

/// A game read from PGN: its tag pairs and the replayed [Game].
final class PgnGame {
  final Map<String, String> headers;
  final Game game;

  /// The result token from the movetext (`1-0`, `0-1`, `1/2-1/2` or `*`).
  final String result;
  const PgnGame(this.headers, this.game, this.result);
}

const List<String> _sevenTagRoster = [
  'Event', 'Site', 'Date', 'Round', 'White', 'Black', 'Result', //
];

String _escape(String v) => v.replaceAll(r'\', r'\\').replaceAll('"', r'\"');

/// Exports [game] as PGN. The Seven Tag Roster is always present (missing
/// tags default to `?`), `SetUp`/`FEN` are added for non-standard starts,
/// and movetext is wrapped at 80 columns.
String gameToPgn(Game game, {Map<String, String> headers = const {}}) {
  final tags = <String, String>{
    'Event': '?',
    'Site': '?',
    'Date': '????.??.??',
    'Round': '?',
    'White': '?',
    'Black': '?',
    ...headers,
    'Result': game.result,
  };
  if (game.initialFen != startFen) {
    tags['SetUp'] = '1';
    tags['FEN'] = game.initialFen;
  }
  final sb = StringBuffer();
  for (final k in _sevenTagRoster) {
    sb.writeln('[$k "${_escape(tags[k]!)}"]');
  }
  for (final e in tags.entries) {
    if (!_sevenTagRoster.contains(e.key)) {
      sb.writeln('[${e.key} "${_escape(e.value)}"]');
    }
  }
  sb.writeln();

  final start = Board.fromFen(game.initialFen);
  var moveNo = start.fullmoveNumber;
  var whiteToMove = start.sideToMove == 0;
  final tokens = <String>[];
  for (final (i, san) in game.sanMoves.indexed) {
    if (whiteToMove) {
      tokens.add('$moveNo. $san');
    } else {
      tokens.add(i == 0 ? '$moveNo... $san' : san);
      moveNo++;
    }
    whiteToMove = !whiteToMove;
  }
  tokens.add(game.result);

  var line = StringBuffer();
  for (final t in tokens) {
    if (line.isNotEmpty && line.length + 1 + t.length > 80) {
      sb.writeln(line);
      line = StringBuffer();
    }
    if (line.isNotEmpty) line.write(' ');
    line.write(t);
  }
  sb.writeln(line);
  return sb.toString();
}

final RegExp _tagLine = RegExp(r'^\[(\w+)\s+"((?:[^"\\]|\\.)*)"\]\s*$');
final RegExp _moveNumber = RegExp(r'^\d+\.+$');
final RegExp _results = RegExp(r'^(1-0|0-1|1/2-1/2|\*)$');

/// Parses a single PGN game. Comments (`{...}` and `;` to end of line),
/// recursive variations, NAGs (`$1`) and move numbers are skipped; every
/// mainline move is validated by replaying it. Throws [FormatException].
PgnGame parsePgn(String pgn) {
  final headers = <String, String>{};
  final movetext = StringBuffer();
  for (final raw in pgn.split(RegExp(r'\r?\n'))) {
    final line = raw.trim();
    if (line.startsWith('%')) continue; // escape mechanism
    final tag = _tagLine.firstMatch(line);
    if (tag != null) {
      headers[tag[1]!] = tag[2]!.replaceAll(r'\"', '"').replaceAll(r'\\', r'\');
    } else if (line.startsWith('[')) {
      throw FormatException('malformed tag pair', line);
    } else {
      movetext.writeln(raw);
    }
  }

  final game = Game(headers['FEN'] ?? startFen);
  String? result;
  final text = movetext.toString();
  var depth = 0;
  var i = 0;
  final token = StringBuffer();

  void flush() {
    if (token.isEmpty) return;
    var t = token.toString();
    token.clear();
    if (depth > 0) return;
    // "12.e4" style: split a glued move number from the move.
    final glued = RegExp(r'^(\d+\.+)([^.].*)$').firstMatch(t);
    if (glued != null) t = glued[2]!;
    if (_moveNumber.hasMatch(t) || t.startsWith(r'$')) return;
    if (_results.hasMatch(t)) {
      if (result != null) throw FormatException('two results', t);
      result = t;
      return;
    }
    if (result != null) throw FormatException('move after result', t);
    try {
      game.play(t);
    } on FormatException {
      throw FormatException(
          'illegal move "$t" after ${game.sanMoves.length} plies', pgn);
    }
  }

  while (i < text.length) {
    final c = text[i];
    if (c == '{') {
      flush();
      final end = text.indexOf('}', i);
      if (end < 0) throw FormatException('unterminated comment', pgn, i);
      i = end + 1;
      continue;
    }
    if (c == ';') {
      flush();
      final end = text.indexOf('\n', i);
      i = end < 0 ? text.length : end + 1;
      continue;
    }
    if (c == '(') {
      flush();
      depth++;
    } else if (c == ')') {
      flush();
      if (depth == 0) throw FormatException('unbalanced ")"', pgn, i);
      depth--;
    } else if (c.trim().isEmpty) {
      flush();
    } else {
      token.write(c);
    }
    i++;
  }
  flush();
  if (depth != 0) throw FormatException('unterminated variation', pgn);
  return PgnGame(headers, game, result ?? '*');
}
