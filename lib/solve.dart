import 'dart:math';

import 'store.dart';

// ----- Problem solving: number problems from the module's formulas (no AI) -----
// Finds formulas like "V = I x R" or "P = V × I", makes problems with random numbers, and works out the
// exact answer with a small calculator. The brain never does the math: small models get math wrong.

final _rng = Random();

typedef Calc = double Function(Map<String, double> values);

// One formula from the module. "V = I × R" -> result V, inputs [I, R].
// A function like "f(x) = x^2 + 3x" (fn: true) asks "find f(2)" instead.
class Formula {
  Formula(this.text, this.result, this.inputs, this.calc, {this.fn = false});
  final String text, result;
  final List<String> inputs;
  final Calc calc;
  final bool fn;
}

// Splits math into pieces: numbers, names (V, R1, R_T), + - * / ^ and brackets.
// Returns null if it holds anything else (so ordinary sentences are never taken as formulas).
// [fn]: inside a function like f(x), "x" is the variable, never "times".
List<String>? _tokens(String s, {bool fn = false}) {
  s = s.replaceAll(RegExp(r'[×·∙✕]'), '*');
  if (!fn) s = s.replaceAll(RegExp(r'\s+x\s+'), ' * '); // "I x R": x between spaces means "times"
  s = s
      .replaceAll('÷', '/')
      .replaceAll(RegExp(r'[−–]'), '-')
      .replaceAll('²', '^2')
      .replaceAll('³', '^3')
      .replaceAll('√', ' sqrt ');
  final piece = RegExp(r'\s*(\d+(?:\.\d+)?|sqrt|sin|cos|tan|ln|log|exp|[A-Za-z](?:_?\d+|_[A-Za-z]{1,3})?|[-+*/^()])');
  final out = <String>[];
  var i = 0;
  while (i < s.length) {
    final m = piece.matchAsPrefix(s, i);
    if (m == null) return s.substring(i).trim().isEmpty ? out : null;
    out.add(m[1]!);
    i = m.end;
  }
  return out;
}

// The calculator. Reads the pieces in math order: brackets, powers, minus signs, × and /, then + and -.
// Two things side by side multiply: "IR" is I × R, "2x" is 2 × x.
class _Parser {
  _Parser(this.t, {this.fn = false});
  final List<String> t;
  final bool fn; // inside a function like f(x): "e" is the number e (2.718...)
  final names = <String>[];
  var i = 0;

  String? get _next => i < t.length ? t[i] : null;
  bool get _startsValue => _next != null && (_next == '(' || RegExp(r'^[\dA-Za-z]').hasMatch(_next!));

  Calc sum() {
    var a = product();
    while (_next == '+' || _next == '-') {
      final minus = t[i++] == '-', l = a, r = product();
      a = minus ? (v) => l(v) - r(v) : (v) => l(v) + r(v);
    }
    return a;
  }

  Calc product() {
    var a = signed();
    while (_next == '*' || _next == '/' || _startsValue) {
      final divide = _next == '/';
      if (_next == '*' || _next == '/') i++;
      final l = a, r = signed();
      a = divide ? (v) => l(v) / r(v) : (v) => l(v) * r(v);
    }
    return a;
  }

  Calc signed() {
    if (_next == '-') {
      i++;
      final a = signed();
      return (v) => -a(v);
    }
    final base = value();
    if (_next != '^') return base;
    i++;
    final power = signed();
    return (v) => pow(base(v), power(v)).toDouble();
  }

  Calc value() {
    final s = _next ?? (throw 'end');
    i++;
    if (s == '(') {
      final a = sum();
      if (_next != ')') throw 'bracket';
      i++;
      return a;
    }
    final n = double.tryParse(s);
    if (n != null) return (_) => n;
    // sqrt / √, sin, cos, tan, ln, log (base 10) and exp work on the value right after them: "4√x", "sin(x)".
    final f = _fns[s];
    if (f != null) {
      final a = signed();
      return (v) => f(a(v));
    }
    if (fn && s == 'e') return (_) => e;
    if (!RegExp(r'^[A-Za-z]').hasMatch(s)) throw 'symbol';
    if (!names.contains(s)) names.add(s);
    return (v) => v[s]!;
  }
}

final _fns = <String, double Function(num)>{
  'sqrt': sqrt,
  'sin': sin,
  'cos': cos,
  'tan': tan,
  'ln': log,
  'exp': exp,
  'log': (x) => log(x) / ln10,
};

// A formula on one line: a short name, "=", then only math. The math stops at a comma, a full stop
// or the first word after a space ("V = I x R, where V is voltage" -> "I x R"; "E = mc² is famous" -> "mc²").
final _candidate = RegExp(r'(?<![\w)])([A-Za-z](?:_?\d+|_[A-Za-z]{1,3})?)\s*=\s*([^=,;:\n]+)');
final _stop = RegExp(r'\s+[a-z]{2,}\b|\s+[A-Za-z]{3,}\b|\.(?!\d)');

// Proof books write "L1 = p1L" for joining maps, not numbers. A "formula" with arrows, ⊗, ∈... or words like
// "prove" or "linear map" within 200 characters is skipped (Nov 23, a 700-page algebra book).
final _abstract = RegExp(
    r'[→↦⊗⊕∈∉⊆⊂≅∗∘]|\b(?:prove|show that|isomorphi|homomorphi|linear map|vector space|subgroup|submodule|bijection)',
    caseSensitive: false);
// A proof book: a proof word or sign every 1,000 characters or less (Nov 23: the algebra book has one every
// 160; number modules have one every 3,000 or more). Its letters stand for maps and sets, not numbers, so its
// "formulas" make no number problems ("Using k = m + 1, find m...").
final _proofWords = RegExp('${_abstract.pattern}|\\b(?:theorem|lemma|proposition|proof)\\b', caseSensitive: false);
bool proofBook(String text) {
  final n = _proofWords.allMatches(text).length;
  return n >= 20 && n * 1000 > text.length; // at least 20, so one "proof" in a short module doesn't count
}

bool _inProof(String text, Match m) =>
    _abstract.hasMatch(text.substring(max(0, m.start - 200), min(text.length, m.end + 200)));

List<Formula> formulas(String text) {
  final out = <Formula>[], seen = <String>{};
  for (final m in _candidate.allMatches(text)) {
    if (_inProof(text, m)) continue;
    final result = m[1]!, math = m[2]!.split(_stop).first.trim();
    final pieces = _tokens(math);
    if (pieces == null || pieces.isEmpty) continue;
    // "y = f(x)" is function notation, not "f times x": a single letter right before "(" means a function.
    if (RegExp(r'(?<![A-Za-z])[A-Za-z]\(').hasMatch(math)) continue;
    try {
      final p = _Parser(pieces), calc = p.sum();
      // Must use every piece, have something to plug in, and not be a plain "V = I" or "x = 5".
      if (p.i != pieces.length || p.names.isEmpty || p.names.contains(result) || p.names.length > 4) continue;
      if (pieces.length < 2) continue;
      final shown = '$result = $math';
      if (seen.add(shown.replaceAll(' ', ''))) out.add(Formula(shown, result, p.names, calc));
    } catch (_) {} // not math after all
  }
  return out;
}

// Functions from the module: "f(x) = e^x − 4√x" -> asks "find f(1.5)". The math stops like in formulas().
// PDFs also print "f (x ) =" with spaces.
final _function = RegExp(r'(?<![\w)])([A-Za-z])\s*\(\s*([a-z])\s*\)\s*=\s*([^=,;:\n]+)');

// PDFs flatten powers: x³ comes out as "x 3", e^x as "e x", e^-x as "e −x". A single letter (or ")") followed by
// a space and a number or letter can't be anything else, so it's put back as a power: "x^3", "e^x", "e^(-x)".
String _powers(String math) => math.replaceAllMapped(
    RegExp(r'(^|[^A-Za-z])([A-Za-z)]) +(\d+|[a-z]|[-−][a-z])(?= |$)'),
    (m) => '${m[1]}${m[2]}^${m[3]!.length > 1 && !RegExp(r'^\d+$').hasMatch(m[3]!) ? '(${m[3]})' : m[3]}');

List<Formula> functions(String text) {
  final out = <Formula>[], seen = <String>{};
  // Gamy's PDF reader puts a power on the next line: "f(x) = x" + new line + "3 − x − 1 using ...".
  // A line ending in a letter, followed by a line that starts with a power and then math, is one line again.
  text = text.replaceAll('\r', '').replaceAllMapped(
      RegExp(r'([A-Za-z)])[ \t]*\n[ \t]*(?=(?:\d{1,2}|[-−]?[a-z])[ \t]+[-−+*/])'), (m) => '${m[1]} ');
  for (final m in _function.allMatches(text)) {
    final name = m[1]!, x = m[2]!, math = _powers(m[3]!.split(_stop).first.trim());
    // PDFs often lose superscripts ("e^x" comes out as "ex"): skip those instead of asking about the wrong function.
    if (x == 'e' || RegExp(r'(?<![A-Za-z])e[a-z]').hasMatch(math)) continue;
    final pieces = _tokens(math, fn: true);
    if (pieces == null || pieces.isEmpty) continue;
    try {
      final p = _Parser(pieces, fn: true), calc = p.sum();
      if (p.i != pieces.length || p.names.length != 1 || p.names.single != x) continue;
      if (pieces.length < 3) continue; // "f(x) = x" alone is not a real function to work with
      final shown = '$name($x) = $math';
      if (seen.add(shown.replaceAll(' ', ''))) out.add(Formula(shown, name, [x], calc, fn: true));
    } catch (_) {}
  }
  return out;
}

// 12.0 -> "12", 0.3333 -> "0.33"
String fmt(double d) => d == d.roundToDouble()
    ? d.toInt().toString()
    : d.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');

String _fill(String template, Map<String, String> values) =>
    values.entries.fold(template, (s, e) => s.replaceAll('{${e.key}}', e.value));

// Up to [count] problems from the module's formulas, in the same shape as rules.dart's quiz items.
// Half find the result ("find V when I = 3, R = 4"); half work backwards ("find I when V = 12, R = 4").
// Throws 'no_formulas' when the module has none.
// ----- Root-finding methods the module teaches (numerical methods) -----
// Only methods the module names, used on the module's own functions, so the problems follow the lesson.
const _methods = {
  'false_position': r'false position|regula falsi',
  'bisection': r'bisection|interval halving',
};

// A method counts only when the module really teaches it: at least one mention per 50,000 characters.
// Nov 23: a 700-page algebra book that names "Jacobi" twice in passing got Jacobi problems.
bool _teaches(String text, String pattern) {
  final n = RegExp(pattern, caseSensitive: false).allMatches(text).length;
  return n > 0 && n * 50000 >= text.length;
}

// What to look up on Wikipedia for "More about..." in the review.
const _topics = {'false_position': 'Regula falsi', 'bisection': 'Bisection method'};

// Runs one method from x- (f negative) and x+ (f positive) until two steps are within 0.0001.
// Returns every x it produced (x1, x2, ...).
// One row of the solution table, like the module's: x-, x+, f(x-), f(x+), the new x, f(x) and d.
typedef Step = ({double neg, double pos, double fNeg, double fPos, double x, double fx, double? d});

List<Step> rootTable(String method, double Function(double) at, double neg, double pos) {
  final rows = <Step>[];
  for (var k = 0; k < 100; k++) {
    final fn = at(neg), fp = at(pos);
    final x = method == 'bisection' ? (neg + pos) / 2 : neg - fn * (pos - neg) / (fp - fn);
    if (!x.isFinite) break;
    final fx = at(x), d = rows.isEmpty ? null : (x - rows.last.x).abs();
    rows.add((neg: neg, pos: pos, fNeg: fn, fPos: fp, x: x, fx: fx, d: d));
    if (fx == 0 || (d != null && d <= 0.0001)) break;
    if (fx > 0) {
      pos = x;
    } else {
      neg = x;
    }
  }
  return rows;
}

List<double> rootSteps(String method, double Function(double) at, double neg, double pos) =>
    [for (final r in rootTable(method, at, neg, pos)) r.x];

// The table as text, with even columns (shown in an even-width font). [mark] = the step the question asked.
String _table(List<Step> rows, {int? mark}) {
  String c(Object v) => (v is double ? v.toStringAsFixed(4) : '$v').padLeft(9);
  final lines = ['  k${c('x-')}${c('x+')}${c('f(x-)')}${c('f(x+)')}${c('x')}${c('f(x)')}${c('d')}'];
  for (var k = 0; k < rows.length; k++) {
    final r = rows[k];
    lines.add('${'$k'.padLeft(3)}${c(r.neg)}${c(r.pos)}${c(r.fNeg)}${c(r.fPos)}${c(r.x)}${c(r.fx)}${c(r.d ?? '-')}'
        '${k == mark ? '  <-' : ''}');
  }
  return lines.join('\n');
}

// Puts numbers in place of the letters of a formula's math: "I x R" with I = 3, R = 4 -> "(3) x (4)".
String _put(String math, Map<String, double> values) {
  for (final name in values.keys.toList()..sort((a, b) => b.length.compareTo(a.length))) {
    math = math.replaceAll(RegExp('(?<![A-Za-z_])${RegExp.escape(name)}(?![A-Za-z0-9_])'), '(${fmt(values[name]!)})');
  }
  return math;
}

// Numerical-methods problems: for each method the module names and each of its functions with a root between
// two whole numbers (-10 to 10), ask for x after steps 1, 2 and 3, and for each root.
List<Map> methodItems(String text) {
  final t = store.t, out = <Map>[];
  for (final e in _methods.entries) {
    if (!_teaches(text, e.value)) continue;
    for (final f in functions(text)) {
      double y(double x) => f.calc({f.inputs.single: x});
      for (var a = -10; a < 10; a++) {
        final ya = y(a.toDouble()), yb = y(a + 1.0);
        if (!ya.isFinite || !yb.isFinite || ya * yb >= 0) continue;
        final neg = ya < 0 ? a.toDouble() : a + 1.0, pos = ya < 0 ? a + 1.0 : a.toDouble();
        final rows = rootTable(e.key, y, neg, pos), xs = [for (final r in rows) r.x];
        if (xs.length < 3) continue;
        String d4(double v) => v.toStringAsFixed(4);
        final parts = {'m': t('m_${e.key}'), 'f': f.text, 'a': fmt(neg), 'b': fmt(pos), 'r': d4(xs.last)};
        // The full solution: the step table (the asked step marked), then why it stops and the root.
        String why(int? mark) => '${_fill(t('m_sol'), parts)}\n${_table(rows, mark: mark)}\n${_fill(t('m_stop'), parts)}';
        for (final k in [1, 2, 3]) {
          out.add({
            'type': 'solve',
            'q': _fill(t('m_step'), {...parts, 'k': '$k'}),
            'answer': d4(xs[k - 1]),
            'why': why(k - 1),
            'hint': _fill(t('m_hint'), parts),
            'topic': _topics[e.key],
          });
        }
        out.add({
          'type': 'solve',
          'q': _fill(t('m_root'), parts),
          'answer': d4(xs.last),
          'why': why(rows.length - 1),
          'hint': _fill(t('m_hint'), parts),
          'topic': _topics[e.key],
        });
      }
    }
  }
  return out..shuffle(_rng);
}

// ----- Systems of linear equations: Jacobi and Gauss-Seidel (numerical methods, part III) -----
// Reads systems like "3x − 2y + z = 11" (2 to 4 unknowns, one equation per line) from the module, and also
// makes new ones with whole-number answers, then solves them the way the module does: convergence check,
// each equation written for its own unknown, iteration 1 worked out, the iteration table, and the answer.
const _sysMethods = {'jacobi': r'jacobi', 'seidel': r'seidel'};
const _sysTopics = {'jacobi': 'Jacobi method', 'seidel': 'Gauss–Seidel method'};

typedef LinSystem = ({List<String> vars, List<List<double>> a, List<double> b, double tol});
// One row of the iteration table: the values after iteration k, and dₖ (null for the starting guess).
typedef SysRow = ({List<double> x, double? d});

final _eqLine = RegExp(r'^[+-]?(?:\d+(?:\.\d+)?)?[a-z]\d?(?:[+-](?:\d+(?:\.\d+)?)?[a-z]\d?)+=[+-]?\d+(?:\.\d+)?$');
final _term = RegExp(r'([+-]?)(\d+(?:\.\d+)?)?([a-z]\d?)');

// One equation line -> {unknown: coefficient} and the number after "=", or null if it isn't one.
(Map<String, double>, double)? _equation(String line) {
  final l = line.replaceAll(RegExp(r'[−–—]'), '-').replaceAll(RegExp(r'\s+'), '');
  if (!_eqLine.hasMatch(l)) return null;
  final sides = l.split('='), coef = <String, double>{};
  for (final m in _term.allMatches(sides[0])) {
    if (coef.containsKey(m[3])) return null; // "x + x = 2" is not a system row
    coef[m[3]!] = (m[1] == '-' ? -1 : 1) * (m[2] == null ? 1 : double.parse(m[2]!));
  }
  return (coef, double.parse(sides[1]));
}

int _byName(String a, String b) => a.length != b.length ? a.length.compareTo(b.length) : a.compareTo(b);

// Puts the equations in an order where each one's diagonal number is bigger than the rest of its row
// (so the methods surely work), or null if no order does.
List<int>? _dominantOrder(List<List<double>> a) {
  final n = a.length;
  List<int>? go(List<int> used) {
    if (used.length == n) return used;
    final i = used.length;
    for (var r = 0; r < n; r++) {
      if (used.contains(r)) continue;
      final rest = [for (var j = 0; j < n; j++) if (j != i) a[r][j].abs()].fold(0.0, (x, y) => x + y);
      if (a[r][i].abs() > rest) {
        final done = go([...used, r]);
        if (done != null) return done;
      }
    }
    return null;
  }
  return go([]);
}

// Systems written in the module (each counted once, even when an example repeats it in another order).
List<LinSystem> systems(String text) {
  final out = <LinSystem>[], seen = <String>{};
  final lines = text.replaceAll('\r', '').split('\n');
  for (var i = 0; i < lines.length; i++) {
    final rows = <(Map<String, double>, double)>[];
    var k = i;
    for (; k < lines.length && rows.length < 4; k++) {
      final e = _equation(lines[k].trim());
      if (e == null || e.$1.length < 2) break;
      rows.add(e);
    }
    final vars = {for (final r in rows) ...r.$1.keys}.toList()..sort(_byName);
    if (rows.length < 2 || vars.length != rows.length) continue;
    final a = [for (final r in rows) [for (final v in vars) r.$1[v] ?? 0.0]], b = [for (final r in rows) r.$2];
    // The module's stopping rule, like "dk ≤ 0.001", near the system; else 0.001.
    final near = lines.skip(max(0, i - 3)).take(rows.length + 6).join(' ');
    final tol = double.tryParse(RegExp(r'≤\s*(0?\.\d+)').firstMatch(near)?[1] ?? '') ?? 0.001;
    final key = ([for (var r = 0; r < a.length; r++) '${a[r].join(',')}=${b[r]}']..sort()).join(';');
    if (seen.add(key)) out.add((vars: vars, a: a, b: b, tol: tol));
    i = k - 1;
  }
  return out;
}

// A new practice system: 3 unknowns, whole-number answers from -5 to 5, diagonal numbers big enough to work.
LinSystem practiceSystem() {
  int pick() => _rng.nextInt(7) - 3;
  final sol = [for (var i = 0; i < 3; i++) (_rng.nextInt(5) + 1) * (_rng.nextBool() ? 1 : -1)];
  final a = <List<double>>[];
  for (var i = 0; i < 3; i++) {
    final row = [for (var j = 0; j < 3; j++) j == i ? 0 : pick()];
    row[i] = row.fold(0, (x, y) => x + y.abs()) + _rng.nextInt(5) + 2;
    a.add([for (final c in row) c.toDouble()]);
  }
  final b = [for (final row in a) [for (var j = 0; j < 3; j++) row[j] * sol[j]].fold(0.0, (x, y) => x + y)];
  return (vars: ['x', 'y', 'z'], a: a, b: b, tol: 0.001);
}

// Iterates from all zeros until dₖ ≤ tol (dₖ = the biggest |new − old| ÷ |new|). Null if it doesn't settle.
List<SysRow>? iterateSystem(String method, LinSystem s) {
  final n = s.vars.length, rows = <SysRow>[(x: List.filled(n, 0.0), d: null)];
  for (var k = 0; k < 100; k++) {
    final old = rows.last.x, x = [...old];
    for (var i = 0; i < n; i++) {
      final from = method == 'seidel' ? x : old; // Gauss-Seidel uses each new value right away
      var rest = 0.0;
      for (var j = 0; j < n; j++) {
        if (j != i) rest += s.a[i][j] * from[j];
      }
      x[i] = (s.b[i] - rest) / s.a[i][i];
    }
    if (x.any((v) => !v.isFinite || v.abs() > 1e9)) return null;
    final d = [for (var i = 0; i < n; i++) (x[i] - old[i]).abs() / (x[i] == 0 ? 1 : x[i].abs())].reduce(max);
    rows.add((x: x, d: d));
    if (d <= s.tol) return rows;
  }
  return null;
}

String _num(double d) => fmt(d).replaceFirst('-', '−');

// "3x − 2y + z = 11"
String _eqText(LinSystem s, int r) {
  final out = StringBuffer();
  for (var j = 0; j < s.vars.length; j++) {
    final c = s.a[r][j];
    if (c == 0) continue;
    final size = c.abs() == 1 ? '' : fmt(c.abs());
    out.write(out.isEmpty ? '${c < 0 ? '−' : ''}$size${s.vars[j]}' : ' ${c < 0 ? '−' : '+'} $size${s.vars[j]}');
  }
  return '$out = ${_num(s.b[r])}';
}

// "x = [11 − (−2y + z)] / 3", or with numbers in: "x = [11 − (−2(0) + (0))] / 3"
String _rewritten(LinSystem s, int i, [List<double>? values]) {
  final parts = <String>[];
  for (var j = 0; j < s.vars.length; j++) {
    final c = s.a[i][j];
    if (j == i || c == 0) continue;
    final what = values == null ? s.vars[j] : '(${values[j].toStringAsFixed(4).replaceFirst('-', '−')})';
    final size = c.abs() == 1 ? '' : fmt(c.abs());
    parts.add(parts.isEmpty ? '${c < 0 ? '−' : ''}$size$what' : '${c < 0 ? '−' : '+'} $size$what');
  }
  if (parts.isEmpty) return '${s.vars[i]} = ${_num(s.b[i])} / ${_num(s.a[i][i])}';
  return '${s.vars[i]} = [${_num(s.b[i])} − (${parts.join(' ')})] / ${_num(s.a[i][i])}';
}

String _sysTable(LinSystem s, List<SysRow> rows, {int? mark}) {
  final t = store.t;
  String c(Object v) => (v is double ? v.toStringAsFixed(4) : '$v').padLeft(10);
  final out = ['  k${s.vars.map(c).join()}${c('dk')}  ${t('sys_remark')}'];
  for (var k = 0; k < rows.length; k++) {
    final r = rows[k], last = k == rows.length - 1;
    out.add('${'$k'.padLeft(3)}${r.x.map(c).join()}${c(r.d ?? '-')}  '
        '${k == 0 ? '' : t(last ? 'sys_stop' : 'sys_go')}${k == mark ? '  <-' : ''}');
  }
  return out.join('\n');
}

// Problems for every system (the module's own, plus [practice] new ones) and every method the module names:
// a value after iteration 1 and 2, and each unknown's final answer, all with the full solution.
List<Map> systemItems(String text, {int practice = 2}) {
  final t = store.t, out = <Map>[];
  final names = [for (final e in _sysMethods.entries) if (_teaches(text, e.value)) e.key];
  if (names.isEmpty) return out;
  final all = [...systems(text), for (var i = 0; i < practice; i++) practiceSystem()];
  for (final given in all) {
    final order = _dominantOrder(given.a);
    final s = order == null
        ? given
        : (vars: given.vars, a: [for (final r in order) given.a[r]], b: [for (final r in order) given.b[r]], tol: given.tol);
    for (final m in names) {
      final rows = iterateSystem(m, s);
      if (rows == null || rows.length < 4) continue;
      final n = s.vars.length, zeros = '(${List.filled(n, '0').join(', ')})';
      final parts = {
        'm': t('m_$m'),
        'start': '(${s.vars.join(', ')})',
        'zeros': zeros,
        'tol': '${s.tol}',
        'eqs': [for (var r = 0; r < n; r++) '   ${_eqText(given, r)}'].join('\n'),
        'how': t('sys_how_$m'),
      };
      // The first iteration with the numbers in (Gauss-Seidel uses each new value as soon as it has one).
      final first = <String>[];
      final now = List.filled(n, 0.0);
      for (var i = 0; i < n; i++) {
        final used = m == 'seidel' ? now : rows[0].x;
        first.add('   ${_rewritten(s, i, used)} = ${rows[1].x[i].toStringAsFixed(4)}');
        now[i] = rows[1].x[i];
      }
      String why(int? mark) => [
            _fill(t('m_sol'), parts),
            if (order != null) ...[
              t('sys_check'),
              for (var r = 0; r < n; r++)
                '   |${fmt(s.a[r][r])}| > ${[for (var j = 0; j < n; j++) if (j != r) '|${fmt(s.a[r][j])}|'].join(' + ')}',
              if (order.indexed.any((e) => e.$1 != e.$2)) t('sys_order'),
            ] else
              t('sys_not_dominant'),
            t('sys_rewrite'),
            for (var i = 0; i < n; i++) '   ${_rewritten(s, i)}',
            _fill(t('sys_first'), parts),
            ...first,
            _fill(t('sys_table'), parts),
            _sysTable(s, rows, mark: mark),
            '${t('sys_answer')} ${[for (var i = 0; i < n; i++) '${s.vars[i]} = ${rows.last.x[i].toStringAsFixed(4)}'].join(', ')}',
          ].join('\n');
      final item = {'type': 'solve', 'hint': _fill(t('sys_hint'), parts), 'topic': _sysTopics[m]};
      for (final k in [1, 2]) {
        final v = _rng.nextInt(n);
        out.add({
          ...item,
          'q': _fill(t('sys_step'), {...parts, 'v': s.vars[v], 'k': '$k'}),
          'answer': rows[k].x[v].toStringAsFixed(4),
          'why': why(k),
        });
      }
      for (var v = 0; v < n; v++) {
        out.add({
          ...item,
          'q': _fill(t('sys_root'), {...parts, 'v': s.vars[v]}),
          'answer': rows.last.x[v].toStringAsFixed(4),
          'why': why(rows.length - 1),
        });
      }
    }
  }
  return out..shuffle(_rng);
}

// ----- Successive substitution (fixed-point iteration): Module 2 -----
// f(x) = 0 is written as x = g(x), then x(k+1) = g(x(k)) until d ≤ 0.0001 (d = |new − old| ÷ |new|).
// Gamy tries the rewrites the module uses, and keeps the first that settles on the root (|g′(x₀)| < 1):
//   1. solve the "x" term:           x³ − 3x + 1 = 0  ->  x = (x³ + 1) / 3
//   2. solve the highest power:      x³ − 3x + 1 = 0  ->  x = (3x − 1)^(1/3)
//   3. take x out of the x terms:    x³ + 2x² + 10x − 20 = 0  ->  x = 20 / (x² + 2x + 10)
const _ssPattern = r'successive substitution|successive approximation|fixed[- ]point iteration';

// "x^3 − 3x + 1" -> [(1, 'x^3'), (-1, '3x'), (1, '1')]; signs inside brackets or after ^ * / are not split.
List<(int, String)> _terms(String math) {
  final s = math.replaceAll(RegExp(r'[−–]'), '-'), out = <(int, String)>[];
  var depth = 0, sign = 1, start = 0;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (c == '(') depth++;
    if (c == ')') depth--;
    if (depth != 0 || (c != '+' && c != '-')) continue;
    final before = s.substring(0, i).trimRight();
    if (before.isEmpty) {
      sign = c == '-' ? -1 : 1;
      start = i + 1;
      continue;
    }
    if ('^*/('.contains(before[before.length - 1])) continue;
    out.add((sign, s.substring(start, i).trim()));
    sign = c == '-' ? -1 : 1;
    start = i + 1;
  }
  out.add((sign, s.substring(start).trim()));
  return out;
}

String _joinTerms(List<(int, String)> ts) {
  final b = StringBuffer();
  for (final (sign, body) in ts) {
    b.write(b.isEmpty ? (sign < 0 ? '−$body' : body) : (sign < 0 ? ' − $body' : ' + $body'));
  }
  return b.toString();
}

// A term "3x", "x", "2x^2": (coefficient, power); a plain number has power 0. Null for anything else.
(double, int)? _poly(String body, String x) {
  final m = RegExp('^(\\d+(?:\\.\\d+)?)?\\s*\\*?\\s*$x(?:\\^(\\d+))?\$').firstMatch(body);
  if (m != null) return (m[1] == null ? 1 : double.parse(m[1]!), m[2] == null ? 1 : int.parse(m[2]!));
  final n = double.tryParse(body);
  return n == null ? null : (n, 0);
}

double _rootOf(double v, int n) =>
    n.isOdd ? (v < 0 ? -pow(-v, 1 / n).toDouble() : pow(v, 1 / n).toDouble()) : (v < 0 ? double.nan : pow(v, 1 / n).toDouble());

// The rewrites x = g(x) of f: (text, g).
List<(String, double Function(double))> _rewrites(Formula f) {
  final x = f.inputs.single, math = f.text.substring(f.text.indexOf('=') + 1).trim(), ts = _terms(math);
  double y(double v) => f.calc({x: v});
  final out = <(String, double Function(double))>[];
  final polys = <(double, int)?>[
    for (final (sign, body) in ts)
      if (_poly(body, x) case (final c, final n)) (sign * c, n) else null
  ];
  String over(List<(int, String)> rest, double c) {
    // x = −rest / c, written without double minus signs
    final shown = c < 0 ? rest : [for (final (s, b) in rest) (-s, b)];
    final top = _joinTerms(shown), d = c.abs();
    return d == 1 ? top : '${shown.length > 1 ? '($top)' : top} / ${fmt(d)}';
  }

  // 1. the plain "x" term
  final lin = [for (var i = 0; i < ts.length; i++) if (polys[i]?.$2 == 1) i];
  if (lin.length == 1) {
    final c = polys[lin.single]!.$1, rest = [...ts]..removeAt(lin.single);
    out.add((over(rest, c), (v) => -(y(v) - c * v) / c));
  }
  // 2. the highest power (when every term is a plain power or number)
  if (polys.every((p) => p != null)) {
    final top = [for (var i = 0; i < ts.length; i++) i]..sort((a, b) => polys[b]!.$2.compareTo(polys[a]!.$2));
    final i = top.first, a = polys[i]!.$1, n = polys[i]!.$2;
    if (n >= 2) {
      final rest = [...ts]..removeAt(i);
      out.add(('(${over(rest, a)})^(1/$n)', (v) => _rootOf(-(y(v) - a * pow(v, n)) / a, n)));
    }
    // 3. x taken out of every x term: x = −k / (the x terms ÷ x)
    final consts = [for (var j = 0; j < ts.length; j++) if (polys[j]!.$2 == 0) j];
    if (consts.length == 1 && polys[consts.single]!.$1 != 0) {
      final k = polys[consts.single]!.$1;
      final inner = [
        for (var j = 0; j < ts.length; j++)
          if (j != consts.single)
            (polys[j]!.$1 < 0 ? -1 : 1,
                '${polys[j]!.$1.abs() == 1 && polys[j]!.$2 > 1 ? '' : fmt(polys[j]!.$1.abs())}${polys[j]!.$2 == 2 ? x : polys[j]!.$2 > 2 ? '$x^${polys[j]!.$2 - 1}' : ''}')
      ];
      out.add(('${k < 0 ? '' : '−'}${fmt(k.abs())} / (${_joinTerms(inner)})', (v) => -k * v / (y(v) - k)));
    }
  }
  return out;
}

typedef SsRow = ({double x, double next, double d});

// The iteration table from x0, or null if it doesn't settle within 100 steps.
List<SsRow>? ssTable(double Function(double) g, double x0, {double tol = 0.0001}) {
  final rows = <SsRow>[];
  var x = x0;
  for (var k = 0; k < 100; k++) {
    final next = g(x);
    if (!next.isFinite) return null;
    final d = (next - x).abs() / (next == 0 ? 1 : next.abs());
    rows.add((x: x, next: next, d: d));
    if (d <= tol) return rows;
    x = next;
  }
  return null;
}

double _slope(double Function(double) g, double x) => (g(x + 1e-5) - g(x - 1e-5)) / 2e-5;

// Problems for every root of every module function between two whole numbers (-10 to 10).
List<Map> successiveItems(String text) {
  final t = store.t, out = <Map>[];
  if (!_teaches(text, _ssPattern)) return out;
  for (final f in functions(text)) {
    final forms = _rewrites(f);
    double y(double v) => f.calc({f.inputs.single: v});
    for (var a = -10; a < 10; a++) {
      final ya = y(a.toDouble()), yb = y(a + 1.0);
      if (!ya.isFinite || !yb.isFinite || ya * yb >= 0) continue;
      // The first rewrite and start (a, a+1, a+0.5) with |g′(x₀)| < 1 that settles on this root.
      (String, double, double, List<SsRow>)? pick;
      for (final (shown, g) in forms) {
        for (final x0 in [a.toDouble(), a + 1.0, a + .5]) {
          final s = _slope(g, x0);
          if (!(s.abs() < 1)) continue;
          final rows = ssTable(g, x0);
          if (rows == null || rows.length < 3 || rows.last.next < a - 1e-3 || rows.last.next > a + 1 + 1e-3) continue;
          pick = (shown, x0, s, rows);
          break;
        }
        if (pick != null) break;
      }
      if (pick == null) continue;
      final (shown, x0, s, rows) = pick;
      String d4(double v) => v.toStringAsFixed(4);
      final parts = {'m': t('m_successive'), 'f': f.text, 'g': shown, 'x0': fmt(x0), 'r': d4(rows.last.next)};
      String why(int? mark) {
        String c(Object v) => (v is double ? v.toStringAsFixed(4) : '$v').padLeft(10);
        final table = ['  k${c('x(k)')}${c('x(k+1)')}${c('d')}  ${t('sys_remark')}'];
        for (var k = 0; k < rows.length; k++) {
          final r = rows[k];
          table.add('${'$k'.padLeft(3)}${c(r.x)}${c(r.next)}${c(r.d)}  '
              '${t(k == rows.length - 1 ? 'sys_stop' : 'sys_go')}${k == mark ? '  <-' : ''}');
        }
        return [
          _fill(t('m_sol'), parts),
          _fill(t('ss_rewrite'), parts),
          _fill(t('ss_check'), {...parts, 's': s.abs().toStringAsFixed(3)}),
          table.join('\n'),
          _fill(t('m_stop'), parts),
        ].join('\n');
      }

      final item = {'type': 'solve', 'hint': _fill(t('ss_hint'), parts), 'topic': 'Fixed-point iteration'};
      for (final k in [1, 2, 3]) {
        out.add({...item, 'q': _fill(t('ss_step'), {...parts, 'k': '$k'}), 'answer': d4(rows[k - 1].next), 'why': why(k - 1)});
      }
      out.add({...item, 'q': _fill(t('ss_root'), parts), 'answer': d4(rows.last.next), 'why': why(rows.length - 1)});
    }
  }
  return out;
}

List<Map> solveItems(String text, int count) {
  // A numerical-methods module gets problems on its own methods; other modules get formula problems.
  final methods = [...methodItems(text), ...systemItems(text), ...successiveItems(text)]..shuffle(_rng);
  if (methods.isNotEmpty) return methods.take(count).toList();
  if (proofBook(text)) throw 'proof_book';
  final all = [...formulas(text), ...functions(text)];
  if (all.isEmpty) throw 'no_formulas';
  // Nov 23: problems come from the whole module, evenly spread (like the other quiz types), not from its first
  // pages: 50 problems from a 700-page book all came from the first 10%.
  final step = all.length / min(count, all.length), start = _rng.nextDouble() * step;
  final fs = [for (var i = 0; i < min(count, all.length); i++) all[(start + i * step).floor().clamp(0, all.length - 1)]]
    ..shuffle(_rng);
  final t = store.t, out = <Map>[];
  for (var n = 0; out.length < count && n < count * 20; n++) {
    final f = fs[n % fs.length];
    if (f.fn) {
      // "Using f(x) = x^2 + 3x, find f(2)." with x from 0.5 to 5
      final x = (_rng.nextInt(10) + 1) / 2, y = f.calc({f.inputs.single: x});
      if (!y.isFinite || y.abs() > 1e6) continue;
      final parts = {'f': f.text, 'x': '${f.result}(${fmt(x)})', 'v': '${f.inputs.single} = ${fmt(x)}', 'a': fmt(y)};
      // Solution: f(1.5) = e^(1.5) − 4√(1.5) = -0.42
      final math = f.text.substring(f.text.indexOf('=') + 1).trim();
      out.add({
        'type': 'solve',
        'q': _fill(t('s_fn'), parts),
        'answer': fmt(y),
        'why': '${_fill(t('s_fn_why'), parts)}\n${parts['x']} = ${_put(math, {f.inputs.single: x})} = ${fmt(y)}',
        'hint': _fill(t('s_hint'), parts),
      });
      continue;
    }
    final values = {for (final x in f.inputs) x: (_rng.nextInt(12) + 1).toDouble()}; // 1 to 12
    final y = f.calc(values);
    if (!y.isFinite || y == 0 || y.abs() > 1e6) continue;
    // Backwards only when the result is shown exactly, so the student can get the exact input back.
    final back = _rng.nextBool() && y == y.roundToDouble();
    final ask = back ? f.inputs[_rng.nextInt(f.inputs.length)] : f.result;
    final known = {...values, f.result: y}..remove(ask);
    final given = [for (final e in known.entries) '${e.key} = ${fmt(e.value)}'].join(', ');
    final answer = fmt(back ? values[ask]! : y);
    final parts = {'f': f.text, 'x': ask, 'given': given, 'a': answer};
    // Solution: the numbers put into the formula, then the answer (and a check when solving backwards).
    final math = f.text.substring(f.text.indexOf('=') + 1).trim();
    final work = back
        ? '${fmt(y)} = ${_put(math, known..remove(f.result))}\n$ask = $answer\n'
            '${t('s_check')}: ${f.result} = ${_put(math, values)} = ${fmt(y)}'
        : '$ask = ${_put(math, values)} = $answer';
    out.add({
      'type': 'solve',
      'q': _fill(t('s_find'), parts),
      'answer': answer,
      'why': '${_fill(t(back ? 's_why_inv' : 's_why_fwd'), parts)}\n$work',
      'hint': _fill(t('s_hint'), parts),
    });
  }
  return out;
}

// A typed number counts if it's within 1% (rounding) of the answer. "12 V" and "12.0" both match 12.
bool numberOk(String typed, String answer) {
  final m = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(typed.replaceAll(',', ''));
  final a = m == null ? null : double.parse(m[0]!), b = double.parse(answer);
  return a != null && (a - b).abs() <= max(b.abs() * .01, .005);
}
