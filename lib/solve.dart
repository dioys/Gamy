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

List<Formula> formulas(String text) {
  final out = <Formula>[], seen = <String>{};
  for (final m in _candidate.allMatches(text)) {
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
    if (!RegExp(e.value, caseSensitive: false).hasMatch(text)) continue;
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

List<Map> solveItems(String text, int count) {
  // A numerical-methods module gets problems on its own methods; other modules get formula problems.
  final methods = methodItems(text);
  if (methods.isNotEmpty) return methods.take(count).toList();
  final fs = [...formulas(text), ...functions(text)];
  if (fs.isEmpty) throw 'no_formulas';
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
