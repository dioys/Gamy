import 'dart:math';

import 'solve.dart';
import 'store.dart';

// ----- Learning from the module's own worked examples (Nov 24) -----
// Works for any subject. Gamy finds each solved example ("Example 2. A gas occupies 2.5 L at 300 K... Solution:
// V2 = V1 × T2 / T1 = 2.5 × 350 / 300 = 2.92 L"), re-checks every solution step with his calculator, works out
// which number of the problem each step uses, then makes a new version with new numbers and recomputes every
// step. An example he can't re-check exactly is skipped: a wrong "correct answer" is worse than no question.
final _rng = Random();

// "Example 2.", "Sample Problem 3:", "Halimbawa 1)" — a word then a number or ":"; not "example, in the..."
final _header = RegExp(
    r'^\s*(?:example|sample problem|solved problem|illustrative example|illustration|problem|halimbawa)\s*'
    r'(?:(?:no\.?\s*)?\d+[\d.]*\s*[.:)\-–]?|[:.)\-–])\s*',
    caseSensitive: false);
// Where a worked problem written as a paragraph starts: "For example, suppose you have 5.00 liters of a gas..."
final _cue = RegExp(r'\b(?:for example|for instance|suppose|imagine|if you have|consider|halimbawa)\b', caseSensitive: false);
// A number in the problem ("2.5", "300"), not the digits of a name ("CO2", "V1").
final _number = RegExp(r'(?<![\w.])\d+(?:\.\d+)?(?!\d)');
// A finished value: a number, then maybe a unit ("2.92 L", "15 m/s", "37.5%").
// (Words in brackets after it are allowed: "4 (four electrons shared)".)
final _result = RegExp(r'^\s*(-?\d+(?:\.\d+)?)\.?\s*([A-Za-z°%µΩ/·²³ ]{0,14}?)\s*(?:[(,;].*)?$');
const _fnWords = {'sqrt', 'sin', 'cos', 'tan', 'ln', 'log', 'exp'};

// A percent in the problem ("6%") used as a decimal in the solution ("0.06").
class _Percent {
  _Percent(this.of);
  final _Given of;
}

// A number in the problem that the solution uses: it gets new values in each version.
class _Given {
  _Given(this.value, this.text);
  final double value;
  final String text; // as printed: "2.5", "300"
  int get decimals => text.contains('.') ? text.split('.')[1].length : 0;
}

// One solution step: "V2 = V1 × T2 / T1 = 2.5 × 350 / 300 = 2.92 L".
class _Step {
  _Step(this.name, this.formula, this.work, this.refs, this.result, this.unit);
  final String name; // "V2" (may be empty)
  final String formula; // "V1 × T2 / T1" (may be empty)
  final String work; // "2.5 × 350 / 300", the numbers replaced by {0}, {1}...
  final List<Object> refs; // for each {i}: a _Given, an earlier _Step, or a fixed number (double)
  final String result; // "2.92"
  final String unit; // "L"
  int get decimals => result.contains('.') ? result.split('.')[1].length : 0;
}

class _Example {
  _Example(this.statement, this.steps, this.givens, this.spans);
  final String statement;
  final List<_Step> steps;
  final List<_Given> givens;
  final List<(int, int, _Given)> spans; // where each given is printed in the statement
}

// Units and words in a step's numbers ("2.5 L × 350 K") are dropped; names with digits ("V1") too, so a
// formula is never mistaken for numbers.
String _numbersOnly(String s) => s
    .replaceFirst(RegExp(r'^\s*[A-Za-z][A-Za-z ]{0,20}:\s*'), '') // a label: "Inside: −23°C + 273"
    .replaceAll('[', '(')
    .replaceAll(']', ')')
    .replaceAllMapped(RegExp(r'(\d),(\d{3})(?!\d)'), (m) => '${m[1]}${m[2]}') // 1,280 -> 1280
    .replaceAllMapped(RegExp(r'(\d)\.(?!\d)'), (m) => m[1]!) // "300. K"
    .replaceAllMapped(RegExp(r'[A-Za-zµΩ°]+\d*'), (m) => _fnWords.contains(m[0]) ? m[0]! : '');

double _round(double v, int decimals) => double.parse(v.toStringAsFixed(decimals));
String _print(double v, int decimals) => v.toStringAsFixed(decimals);

List<_Example> _examples(String text) {
  final lines = text.replaceAll('\r', '').split('\n'), out = <_Example>[];
  var done = -1; // lines up to here already belong to an example
  for (var i = 0; i < lines.length; i++) {
    if (i <= done || _stepParts(lines[i]) == null) continue;
    // Back from the first worked step: an "Example 2." header, or a question ("...?") and where its
    // paragraph starts ("For example, suppose..."). At most 25 lines back.
    var start = -1, question = -1;
    for (var k = i - 1; k > max(done, i - 25); k--) {
      if (_header.hasMatch(lines[k])) {
        start = k;
        break;
      }
      if (question < 0 && lines[k].contains('?')) question = k;
      if (question >= 0 && _cue.hasMatch(lines[k])) {
        start = k;
        break;
      }
    }
    if (start < 0) continue;
    // The work: steps up to 8 lines apart belong together (explanations often sit between them), until the
    // next example starts (Nov 24: Boyle's law took the steps of the Charles's law paragraph after it).
    var end = i;
    bool next(String l) => _header.hasMatch(l) || _cue.hasMatch(l) || l.contains('?');
    for (var k = i + 1; k < lines.length && k <= end + 8 && !next(lines[k]); k++) {
      if (_stepParts(lines[k]) != null) end = k;
    }
    var problem = [for (final l in lines.sublist(start, question >= 0 ? question + 1 : i)) l].join(' ');
    problem = problem.replaceFirst(_header, '');
    if (question >= 0) {
      problem = problem.substring(0, problem.lastIndexOf('?') + 1);
      final cue = _cue.firstMatch(problem);
      if (cue != null && !_header.hasMatch(lines[start])) problem = problem.substring(cue.start);
      problem = problem.replaceFirst(RegExp(r'^(for example|for instance),?\s*', caseSensitive: false), '');
      if (problem.isNotEmpty) problem = problem[0].toUpperCase() + problem.substring(1);
    }
    final ex = _read(problem, lines.sublist(question >= 0 ? question + 1 : start + 1, end + 1));
    if (ex != null) out.add(ex);
    done = end;
  }
  return out;
}

_Example? _read(String problem, List<String> work) {
  final statement = problem
      .replaceAll(RegExp(r'\b(solution|given|solusyon)\s*:', caseSensitive: false), '')
      .replaceAllMapped(RegExp(r'(\d),(\d{3})(?!\d)'), (m) => '${m[1]}${m[2]}')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (statement.length < 15 || statement.length > 700) return null;
  final givens = <_Given>[], spans = <(int, int, _Given)>[];
  final byValue = <double, Object>{};
  for (final m in _number.allMatches(statement)) {
    final v = double.parse(m[0]!);
    final known = byValue[v];
    final _Given g;
    if (known is _Given) {
      g = known;
    } else {
      g = _Given(v, m[0]!); // (a number also written as a percent elsewhere counts as itself)
      givens.add(g);
      byValue[v] = g;
    }
    // "6%" also matches 0.06 in the solution (unless 0.06 is itself a number in the problem).
    if (statement.substring(m.end).trimLeft().startsWith('%')) {
      byValue.putIfAbsent(_round(v / 100, g.decimals + 2), () => _Percent(g));
    }
    spans.add((m.start, m.end, g));
  }
  final steps = <_Step>[];
  for (final line in work) {
    final parts = _stepParts(line);
    if (parts == null) continue;
    final step = _check(parts, byValue, steps);
    if (step != null) steps.add(step);
  }
  final used = {for (final s in steps) for (final r in s.refs) if (r is _Given) r else if (r is _Percent) r.of};
  if (steps.isEmpty || used.isEmpty) return null;
  // (The same number printed twice is changed in both places; a number with two roles in one step is caught
  // in _check.)
  return _Example(statement, steps, givens, spans);
}

// "name = formula = numbers = result" pieces of a line, or null if it isn't a worked step.
(String, String, String, String, String)? _stepParts(String line) {
  final seg = line.split('=').map((s) => s.trim()).toList();
  if (seg.length < 2 || line.length > 160) return null;
  final r = _result.firstMatch(seg.last.replaceAllMapped(RegExp(r'(\d),(\d{3})(?!\d)'), (m) => '${m[1]}${m[2]}'));
  if (r == null) return null;
  final isName = RegExp(r'^[A-Za-z][\w₀-₉]{0,5}$');
  // The numbers: the first (most detailed) piece that is pure math once units are dropped and has an operator.
  // ("(4 + 8 + 6 + 5 + 7) / 5", not "30 / 5": the short one hides where 30 came from.)
  for (var k = 0; k <= seg.length - 2; k++) {
    final nums = _numbersOnly(seg[k]);
    if (!RegExp(r'\d').hasMatch(nums) || !RegExp(r'[-+*/×÷·^√()²³–−]').hasMatch(nums.replaceFirst(RegExp(r'^\s*[-–−]'), ''))) continue;
    if (numberOf(nums) == null) continue;
    final name = seg.firstWhere((x) => isName.hasMatch(x), orElse: () => '');
    final formula = k >= 1 && seg[k - 1] != name && RegExp(r'[A-Za-z]').hasMatch(seg[k - 1]) ? seg[k - 1] : '';
    return (name, formula, nums, r[1]!, r[2]!.trim());
  }
  return null;
}

// Re-checks a step and links each of its numbers to the problem or an earlier step.
// Fixed numbers a step may use without the problem mentioning them: small numbers (½, squares, 2πr...), unit
// changes (60, 100, 1000...) and decimals like physical constants (9.8, 0.0821, 6.022). A whole number like 30
// that appears from nowhere is a hidden in-between result, so that step can't be re-checked.
bool _fixedOk(double v) => v <= 12 || v != v.roundToDouble() || const {24, 60, 100, 180, 273, 360, 1000, 3600}.contains(v);

_Step? _check((String, String, String, String, String) p, Map<double, Object> byValue, List<_Step> earlier) {
  final (name, formula, nums, result, unit) = p;
  final value = double.parse(result), got = numberOf(nums)!;
  final decimals = result.contains('.') ? result.split('.')[1].length : 0;
  // It must give the module's own answer (allowing for the module's rounding).
  if ((got - value).abs() > max(value.abs() * .01, .51 * pow(10, -decimals))) return null;
  final refs = <Object>[], buf = StringBuffer();
  var last = 0;
  final seen = <Object>{};
  for (final m in RegExp(r'\d+(?:\.\d+)?').allMatches(nums)) {
    final v = double.parse(m[0]!);
    // Exponents stay fixed ("5²", "x^2"); so do numbers the problem doesn't mention (constants like 0.5, 273).
    final before = nums.substring(0, m.start).trimRight();
    Object ref = v;
    if (!before.endsWith('^')) {
      final step = earlier.where((s) => double.parse(s.result) == v).lastOrNull;
      ref = byValue[v] ?? step ?? v;
    }
    // The same problem number twice in one step is ambiguous (which role is which?): not re-checkable.
    if (ref is! double && !seen.add(ref is _Percent ? ref.of : ref)) return null;
    if (ref is double && !_fixedOk(ref)) return null;
    buf
      ..write(nums.substring(last, m.start))
      ..write('{${refs.length}}');
    refs.add(ref);
    last = m.end;
  }
  buf.write(nums.substring(last));
  if (!refs.any((r) => r is! double)) return null; // only fixed numbers: nothing to vary
  return _Step(name, formula, buf.toString().trim(), refs, result, unit);
}

// New numbers for the problem: 60% to 160% of the original, printed like the original (same decimals).
Map<_Given, double> _newValues(_Example ex) {
  final out = <_Given, double>{};
  for (final g in ex.givens) {
    if (g.value == 0) {
      out[g] = 0;
      continue;
    }
    double v;
    var tries = 0;
    do {
      v = _round(g.value * (.6 + _rng.nextDouble()), g.decimals);
    } while ((v == g.value || v == 0 || (g.value >= 1 && v.abs() < 1)) && ++tries < 20);
    out[g] = v;
  }
  return out;
}

// One new version of an example, with every step recomputed; null if the new numbers don't work.
Map? _version(_Example ex, int index) {
  final values = _newValues(ex), results = <_Step, String>{}, lines = <String>[];
  for (final s in ex.steps) {
    String put(Object r) {
      final shown = switch (r) {
        _Given g => _print(values[g]!, g.decimals),
        _Percent p => _print(values[p.of]! / 100, p.of.decimals + 2),
        _Step st => results[st]!,
        _ => fmt(r as double),
      };
      return shown.startsWith('-') ? '($shown)' : shown;
    }

    final work = s.work.replaceAllMapped(RegExp(r'\{(\d+)\}'), (m) => put(s.refs[int.parse(m[1]!)]));
    final v = numberOf(work);
    if (v == null || !v.isFinite || (double.parse(s.result) > 0 && v <= 0)) return null;
    // Rounded like the module (at least 2 decimals, 3 below 1); later steps use that, like a student would.
    results[s] = _print(v, max(s.decimals, v.abs() < 1 ? 3 : 2));
    lines.add([if (s.name.isNotEmpty) s.name, if (s.formula.isNotEmpty) s.formula, work, '${results[s]} ${s.unit}'.trim()].join(' = '));
  }
  // The problem with its new numbers, printed where the old ones were.
  final b = StringBuffer();
  var at = 0;
  for (final (start, end, g) in ex.spans) {
    b
      ..write(ex.statement.substring(at, start))
      ..write(_print(values[g]!, g.decimals));
    at = end;
  }
  b.write(ex.statement.substring(at));
  final last = ex.steps.last, t = store.t;
  final answer = results[last]!;
  return {
    'type': 'solve',
    'q': '$b${last.name.isEmpty ? '' : '\n→ ${t('ex_find')} ${last.name}${last.unit.isEmpty ? '' : ' (${last.unit})'}.'}',
    'answer': answer,
    'why': '${t('ex_why')}\n${lines.join('\n')}',
    'hint': t('ex_hint'),
    'key': 'ex|$index',
  };
}

// One problem per worked example in the module, each with new numbers. Empty if there are none.
List<Map> exampleItems(String text) {
  final out = <Map>[], exs = _examples(text);
  for (var i = 0; i < exs.length; i++) {
    for (var tries = 0; tries < 10; tries++) {
      final m = _version(exs[i], i);
      if (m != null) {
        out.add(m);
        break;
      }
    }
  }
  return out..shuffle(_rng);
}

// The formulas the examples already use, so they aren't asked again as plain formula problems.
Set<String> exampleFormulas(String text) => {
      for (final ex in _examples(text))
        for (final s in ex.steps)
          if (s.formula.isNotEmpty) s.formula.replaceAll(' ', '')
    };
