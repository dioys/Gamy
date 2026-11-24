import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gamy/algebra.dart';
import 'package:gamy/solve.dart';
import 'package:gamy/store.dart';

// Round 1 packs (Nov 24): college algebra, trigonometry, analytic geometry, statistics and probability.
// Every answer is worked out again here from the question's own text, a different way where possible.
const _all = [
  'linear', 'inequalities', 'absolute', 'slope', 'systems', 'polynomials', 'factoring', 'rational', 'radicals',
  'quadratics', 'functions', 'explog', 'radians', 'righttri', 'unitcircle', 'identities', 'trilaws', 'trigeq',
  'distance', 'circle', 'parabola', 'ellipse', 'hyperbola', 'center', 'spread', 'zscore', 'prob', 'counting',
  'expected', 'binomial', 'poisson', 'normal', 'ci', 'hypothesis', 'chisq', 'correlation',
];

List<Map> _items(String topic, int level, [int n = 15]) => algebraItems([topic], level, n);
double _at(String expr, [Map<String, double> v = const {}]) => readExpression(expr)!.calc(v);
double _num(Object? s) => numberOf('$s')!;
List<double> _nums(String s) =>
    [for (final m in RegExp(r'-?\d+(?:\.\d+)?').allMatches(s.replaceAll('−', '-'))) double.parse(m[0]!)];
String _after(String q) => q.substring(q.lastIndexOf(': ') + 2);
Matcher _near(double v, [double rel = .01]) => closeTo(v, max(v.abs() * rel, .006));

// Is "2x − 3 < 5", "−3 < x ≤ 4", "x < −2 or x > 5" or "|2x + 1| ≥ 3" true at x?
bool _holds(String s, double x) => s.split(' or ').any((part) {
      final ops = [for (final m in RegExp(r'[<>≤≥]').allMatches(part)) m[0]!];
      final v = [
        for (final b in part.split(RegExp(r'[<>≤≥]')))
          _at(b.replaceAllMapped(RegExp(r'\|([^|]+)\|'), (m) => 'sqrt((${m[1]})^2)'), {'x': x})
      ];
      for (var i = 0; i < ops.length; i++) {
        final ok = switch (ops[i]) { '<' => v[i] < v[i + 1], '>' => v[i] > v[i + 1], '≤' => v[i] <= v[i + 1], _ => v[i] >= v[i + 1] };
        if (!ok) return false;
      }
      return true;
    });

int _f(int n) => n <= 1 ? 1 : n * _f(n - 1);
double _c(int n, int k) => _f(n) / (_f(k) * _f(n - k));

// The area under the standard normal curve left of z, by Simpson's rule (not the app's formula).
double _area(double z) {
  const steps = 2000;
  final h = z / steps;
  double pdf(double t) => exp(-t * t / 2) / sqrt(2 * pi);
  var s = pdf(0) + pdf(z);
  for (var i = 1; i < steps; i++) {
    s += (i.isOdd ? 4 : 2) * pdf(i * h);
  }
  return .5 + s * h / 3;
}

double _trig(String fn, double x) => switch (fn) { 'sin' => sin(x), 'cos' => cos(x), _ => tan(x) };

void main() {
  setUp(() => store.lang = 'en');

  group('answers students type', () {
    test('inequalities in any fair form', () {
      expect(ineqOk('x <= 3/2', 'x ≤ 1.5'), isTrue);
      expect(ineqOk('3 > x', 'x < 3'), isTrue);
      expect(ineqOk('x > 5 or x < -2', 'x < −2 or x > 5'), isTrue);
      expect(ineqOk('-3<x<5', '−3 < x < 5'), isTrue);
      expect(ineqOk('x < 3', 'x ≤ 3'), isFalse, reason: 'the boundary matters');
      expect(ineqOk('x > 3', 'x < 3'), isFalse);
      expect(ineqOk('3', 'x < 3'), isFalse);
    });

    test('both roots in any order, simplified radicals, factored and expanded forms, π', () {
      expect(setOk('x = 4 or x = -3', '−3, 4'), isTrue);
      expect(setOk('4', '−3, 4'), isFalse);
      expect(radicalOk('6√2', '6√2'), isTrue);
      expect(radicalOk('6sqrt2', '6√2'), isTrue);
      expect(radicalOk('√72', '6√2'), isFalse, reason: 'not simplified');
      expect(radicalOk('8.49', '6√2'), isFalse, reason: 'the exact form is asked');
      expect(radicalOk('2√6/3', '2√6/3'), isTrue);
      expect(radicalOk('4/√6', '2√6/3'), isFalse, reason: 'a root left at the bottom');
      expect(checkAnswer('factor', '(x+3)(x+2)', '(x + 2)(x + 3)'), isTrue);
      expect(checkAnswer('factor', 'x^2+5x+6', '(x + 2)(x + 3)'), isFalse, reason: 'not factored');
      expect(checkAnswer('factor', '(x^2+5x+6)', '(x + 2)(x + 3)'), isFalse);
      expect(checkAnswer('factor', '3x(x+2)', '3x(x + 2)'), isTrue);
      expect(checkAnswer('expanded', '(x+2)(x+3)', 'x² + 5x + 6'), isFalse, reason: 'not multiplied out');
      expect(checkAnswer('expanded', 'x^2+5x+6', 'x² + 5x + 6'), isTrue);
      expect(checkAnswer('simple', '(x^2+5x+6)/(x+2)', 'x + 3'), isFalse, reason: 'not simplified');
      expect(checkAnswer('simple', 'x+3', 'x + 3'), isTrue);
      expect(exprOk('f^-1(x) = (5-3x)/(x-2)', '(−3x + 5)/(x − 2)'), isTrue);
      expect(exprOk('f⁻¹(x) = (5-3x)/(x-2)', '(−3x + 5)/(x − 2)'), isTrue);
      expect(numberOk('5pi/6', '5π/6'), isTrue);
      expect(numberOk('2.618', '5π/6'), isTrue);
      expect(numberOk('-0.866', '−√3/2'), isTrue);
    });
  });

  group('lessons', () {
    test('a statistics module gets its lessons; words used once in passing do not count', () {
      final stats = List.filled(30, 'Find the median and the standard deviation. Use the normal distribution and a z-score.')
          .join('\n');
      expect(topicsIn(stats), ['center', 'spread', 'zscore', 'normal']);
      final physics = '${List.filled(2000, 'A force makes a body speed up.').join('\n')}\nAngles are in radians.';
      expect(topicsIn(physics), isEmpty);
    });

    test('more lessons than problems: a handful of lessons, still in course order', () {
      final items = algebraItems(_all, 2, 10);
      expect(items, hasLength(10));
      final order = [for (final m in items) _all.indexWhere((t) => topicName(t) == m['part'])];
      expect(order, orderedEquals([...order]..sort()));
    });

    test("the module's own worked examples come first", () {
      const examples = 'Example 1. How many moles are in 36 g of water if its molar mass is 18 g/mol?\n'
          'n = m / M = 36 / 18 = 2 mol\n';
      final text = '$examples${List.filled(10, 'Find the standard deviation.').join('\n')}';
      final items = packItems(text, ['spread'], 1, 6);
      expect(items, hasLength(6));
      expect(items.first['part'], 'From your module');
      expect(items.skip(1).every((m) => m['part'] == 'Variance and standard deviation'), isTrue);
    });
  });

  for (final topic in _all) {
    test('$topic: every level makes different, complete problems whose answer is accepted', () {
      for (final level in [1, 2, 3]) {
        final items = _items(topic, level, 5);
        expect(items, hasLength(5), reason: '$topic level $level');
        expect(items.map((m) => '${m['q']}${m['graph']}').toSet(), hasLength(5), reason: 'no repeats');
        for (final m in items) {
          final all = '${m['q']} ${m['answer']} ${m['why']}';
          expect(all, isNot(matches(RegExp(r'NaN|Infinity|null|\$\{'))), reason: all);
          expect('${m['why']}'.trim(), isNotEmpty);
          expect(checkAnswer('${m['check'] ?? 'num'}', m['answer'], m['answer']), isTrue, reason: all);
        }
      }
    });
  }

  group('college algebra answers', () {
    test('inequalities and absolute value: true for exactly the same x', () {
      for (final topic in ['inequalities', 'absolute']) {
        for (final level in [1, 2, 3]) {
          for (final m in _items(topic, level)) {
            final q = _after(m['q']).split('. ').first, answer = m['answer'] as String;
            if (m['check'] == 'set') {
              final eq = q.split(' = ');
              for (final x in answer.split(', ').map(_num)) {
                expect(_holds('${eq[0]} ≤ ${eq[1]}', x) && _holds('${eq[0]} ≥ ${eq[1]}', x), isTrue, reason: '$q at $x');
              }
              continue;
            }
            for (var x = -20.0; x < 20; x += .37) {
              expect(_holds(answer, x), _holds(q, x), reason: '$q -> $answer at $x');
            }
          }
        }
      }
    });

    test('quadratics: each answer is a root', () {
      for (final level in [1, 2, 3]) {
        for (final m in _items('quadratics', level)) {
          final poly = _after(m['q']).split(' = 0').first, xs = '${m['answer']}'.split(', ').map(_num).toList();
          expect(xs, hasLength(2), reason: m['q']);
          for (final x in xs) {
            if (level < 3) {
              expect(_at(poly, {'x': x}), closeTo(0, 1e-9), reason: '$poly at $x');
            } else {
              // Rounded to 2 places, so the real root is within 0.005: the curve changes sign around it.
              expect(_at(poly, {'x': x - .006}) * _at(poly, {'x': x + .006}), lessThanOrEqualTo(0), reason: '$poly at $x');
            }
          }
        }
      }
    });

    test('polynomials, factoring and rational expressions equal the question', () {
      for (final level in [1, 2]) {
        for (final topic in ['polynomials', 'factoring', 'rational']) {
          for (final m in _items(topic, level)) {
            expect(exprOk(m['answer'], _after(m['q'])), isTrue, reason: '${m['q']} -> ${m['answer']}');
          }
        }
      }
      for (final m in _items('factoring', 3)) {
        expect(exprOk(m['answer'], _after(m['q'])), isTrue, reason: '${m['q']} -> ${m['answer']}');
      }
      for (final m in _items('polynomials', 3)) {
        final g = RegExp(r'P\(x\) = (.+) is divided by \(x ([−+]) (\d+)\)').firstMatch(m['q'])!;
        final r = double.parse(g[3]!) * (g[2] == '−' ? 1 : -1);
        expect(_num(m['answer']), closeTo(_at(g[1]!, {'x': r}), 1e-9), reason: m['q']);
      }
      for (final m in _items('rational', 3)) {
        final sides = _after(m['q']).split(' = '), x = _num(m['answer']);
        expect(_at(sides[0], {'x': x}), closeTo(_at(sides[1], {'x': x}), 1e-9), reason: m['q']);
      }
    });

    test('radicals keep their value', () {
      for (final level in [1, 2, 3]) {
        for (final m in _items('radicals', level)) {
          expect(_num(m['answer']), closeTo(_at(_after(m['q'])), 1e-9), reason: '${m['q']} -> ${m['answer']}');
        }
      }
    });

    test('functions: values, compositions and inverses', () {
      for (final m in _items('functions', 1)) {
        final g = RegExp(r'f\(x\) = (.+), find f\((.+)\)\.').firstMatch(m['q'])!;
        expect(_num(m['answer']), closeTo(_at(g[1]!, {'x': _num(g[2])}), 1e-9));
      }
      for (final m in _items('functions', 2)) {
        final g = RegExp(r'f\(x\) = (.+) and g\(x\) = (.+), find (.)\(').firstMatch(m['q'])!;
        final f = g[1]!, h = g[2]!, fFirst = g[3] == 'f';
        for (final x in [-1.5, .5, 2.0]) {
          final want = fFirst ? _at(f, {'x': _at(h, {'x': x})}) : _at(h, {'x': _at(f, {'x': x})});
          expect(_at(m['answer'], {'x': x}), closeTo(want, 1e-9), reason: m['q']);
        }
      }
      for (final m in _items('functions', 3)) {
        final f = RegExp(r'f\(x\) = (.+)\.$').firstMatch(m['q'])![1]!;
        for (final x in [-2.3, .7, 3.1]) {
          expect(_at(f, {'x': _at(m['answer'], {'x': x})}), closeTo(x, 1e-9), reason: '${m['q']} -> ${m['answer']}');
        }
      }
    });

    test('exponents and logarithms', () {
      for (final m in _items('explog', 1)) {
        final sides = _after(m['q']).split(' = ');
        expect(_at(sides[0], {'x': _num(m['answer'])}), closeTo(double.parse(sides[1]), 1e-9));
      }
      const subs = '₀₁₂₃₄₅₆₇₈₉';
      for (final m in _items('explog', 2)) {
        final g = RegExp(r'log(\S+?)\((.+)\) = (\d+)').firstMatch(m['q'])!;
        final base = int.parse(g[1]!.split('').map(subs.indexOf).join()), arg = _at(g[2]!, {'x': _num(m['answer'])});
        expect(log(arg) / log(base), closeTo(double.parse(g[3]!), 1e-9));
      }
      for (final m in _items('explog', 3)) {
        final n = _nums(_after(m['q']));
        expect(pow(n[0], _num(m['answer'])).toDouble(), _near(n[1], .005));
      }
    });
  });

  group('trigonometry and analytic geometry answers', () {
    test('radians and degrees', () {
      for (final m in _items('radians', 1)) {
        expect(_num(m['answer']), closeTo(_nums(m['q']).last * pi / 180, 1e-9));
      }
      for (final m in _items('radians', 2)) {
        expect(_num(m['answer']), closeTo(_at(_after(m['q'])) * 180 / pi, 1e-6));
      }
      for (final m in _items('radians', 3)) {
        final n = _nums(m['q']), r = n[0], t = n[1] * pi / 180;
        expect(_num(m['answer']), _near((m['q'] as String).contains('arc') ? r * t : r * r * t / 2));
      }
    });

    test('right triangles and the sine and cosine laws', () {
      for (final m in _items('righttri', 1)) {
        final n = _nums(m['q']), t = n[1] * pi / 180;
        expect(_num(m['answer']), _near(n[0] * ((m['q'] as String).contains('opposite') ? sin(t) : cos(t))));
      }
      for (final m in _items('righttri', 2)) {
        final n = _nums(m['q']);
        expect(_num(m['answer']), _near(atan2(n[0], n[1]) * 180 / pi));
      }
      for (final m in _items('trilaws', 1)) {
        final n = _nums(m['q']);
        expect(_num(m['answer']), _near(n[2] * sin(n[1] * pi / 180) / sin(n[0] * pi / 180)));
      }
      for (final m in _items('trilaws', 2)) {
        final n = _nums(m['q']), b = n[0], c = n[1], a = n[2] * pi / 180;
        expect(_num(m['answer']), _near(sqrt(b * b + c * c - 2 * b * c * cos(a))));
      }
      for (final m in _items('trilaws', 3)) {
        final n = _nums(m['q']), a = n[0], b = n[1], c = n[2];
        // Check it the other way: the angle found gives back side c.
        final angle = _num(m['answer']) * pi / 180;
        expect(sqrt(a * a + b * b - 2 * a * b * cos(angle)), _near(c));
      }
    });

    test('unit circle exact values', () {
      for (final level in [1, 2, 3]) {
        for (final m in _items('unitcircle', level)) {
          final parts = _after(m['q']).split(' '), angle = parts[1];
          final x = angle.endsWith('°') ? double.parse(angle.replaceAll('°', '').replaceAll('−', '-')) * pi / 180 : _at(angle);
          expect(_num(m['answer']), closeTo(_trig(parts[0], x), 1e-9), reason: m['q']);
          expect(m['answer'], isNot(contains('.')), reason: 'exact, not a decimal');
        }
      }
    });

    test('identities: the other ratios from one ratio and the quadrant', () {
      for (final level in [1, 2, 3]) {
        for (final m in _items('identities', level)) {
          final g = RegExp(r'(sin|cos) θ = (\S+) and θ is in Quadrant (\w+), find (.+)\.').firstMatch(m['q'])!;
          final v = _num(g[2]), quadrant = const ['I', 'II', 'III', 'IV'].indexOf(g[3]!) + 1;
          final other = sqrt(1 - v * v);
          final s = g[1] == 'sin' ? v : (quadrant <= 2 ? other : -other);
          final c = g[1] == 'cos' ? v : (quadrant == 1 || quadrant == 4 ? other : -other);
          final want = switch (g[4]) { 'sin θ' => s, 'cos θ' => c, 'tan θ' => s / c, 'sin 2θ' => 2 * s * c, _ => c * c - s * s };
          expect(_num(m['answer']), closeTo(want, 1e-9), reason: m['q']);
        }
      }
    });

    test('trig equations: every answer works and none is missing', () {
      for (final level in [1, 2, 3]) {
        for (final m in _items('trigeq', level, level == 2 ? 6 : 10)) {
          final f = _after(m['q']).split(' = 0').first.replaceAllMapped(
              RegExp(r'(sin|cos|tan)(²)? x'), (g) => g[2] != null ? '(${g[1]}(x))^2' : '${g[1]}(x)');
          final works = [
            for (var d = 0; d < 360; d += 15)
              if (_at(f, {'x': d * pi / 180}).abs() < 1e-9) d.toDouble()
          ];
          expect(_nums(m['answer']), unorderedEquals(works), reason: m['q']);
        }
      }
    });

    test('distance, midpoint and distance to a line', () {
      List<List<double>> points(String q) =>
          [for (final g in RegExp(r'\((−?\d+), (−?\d+)\)').allMatches(q)) [_num(g[1]), _num(g[2])]];
      for (final m in _items('distance', 1)) {
        final p = points(m['q']);
        expect(_num(m['answer']), _near(sqrt(pow(p[1][0] - p[0][0], 2) + pow(p[1][1] - p[0][1], 2))));
      }
      for (final m in _items('distance', 2)) {
        final p = points(m['q']);
        expect(pairOk('(${(p[0][0] + p[1][0]) / 2}, ${(p[0][1] + p[1][1]) / 2})', m['answer']), isTrue);
      }
      for (final m in _items('distance', 3)) {
        final p = points(m['q']).first, line = RegExp(r'line (.+) = 0').firstMatch(m['q'])![1]!;
        // The closest point on the line, found by trying the whole line (not the formula).
        var best = double.infinity;
        final a = _at(line, {'x': 1, 'y': 0}) - _at(line, {'x': 0, 'y': 0}), b = _at(line, {'x': 0, 'y': 1}) - _at(line, {'x': 0, 'y': 0});
        final c = _at(line, {'x': 0, 'y': 0});
        for (var t = -60.0; t <= 60; t += .001) {
          final x = b == 0 ? -c / a : t, y = b == 0 ? t : -(a * t + c) / b;
          best = min(best, sqrt(pow(x - p[0], 2) + pow(y - p[1], 2)));
        }
        expect(_num(m['answer']), _near(best, .002));
      }
    });

    test('circles: the center and radius fit the equation', () {
      for (final level in [1, 2]) {
        for (final m in _items('circle', level)) {
          final eq = RegExp(r'radius of (.+)\. Answer').firstMatch(m['q'])![1]!.split(' = ');
          final a = _numsOf(m['answer']), h = a[0], k = a[1], r = a[2];
          for (final (x, y) in [(h + r, k), (h - r, k), (h, k + r)]) {
            expect(_at(eq[0], {'x': x, 'y': y}) - _at(eq[1]), closeTo(0, 1e-9), reason: '${m['q']} -> ${m['answer']}');
          }
        }
      }
      for (final m in _items('circle', 3)) {
        final g = RegExp(r'center \((−?\d+), (−?\d+)\) and passes through \((−?\d+), (−?\d+)\)').firstMatch(m['q'])!;
        final a = _numsOf(m['answer']);
        expect(-a[0] / 2, _num(g[1]));
        expect(-a[1] / 2, _num(g[2]));
        final x = _num(g[3]), y = _num(g[4]);
        expect(x * x + y * y + a[0] * x + a[1] * y + a[2], closeTo(0, 1e-9));
      }
    });

    test('parabolas: vertex and focus', () {
      for (final m in _items('parabola', 1)) {
        final f = RegExp(r'y = (.+)\. Answer').firstMatch(m['q'])![1]!, v = _numsOf(m['answer']);
        expect(_at(f, {'x': v[0]}), closeTo(v[1], 1e-9));
        expect(_at(f, {'x': v[0] - 1}), closeTo(_at(f, {'x': v[0] + 1}), 1e-9), reason: 'the vertex is on the axis');
      }
      for (final level in [2, 3]) {
        for (final m in _items('parabola', level)) {
          // The ends of the latus rectum, (focus ± 2p across the axis), are on the curve.
          final eq = RegExp(r'focus of (.+)\. Answer').firstMatch(m['q'])![1]!.split(' = ');
          double at(double x, double y) => _at(eq[0], {'x': x, 'y': y}) - _at(eq[1], {'x': x, 'y': y});
          final f = _numsOf(m['answer']), opensSideways = eq.join().contains('y²');
          // The vertex: the point of the curve on the axis.
          final p = opensSideways ? f[0] - _root(m, (x) => at(x, f[1])) : f[1] - _root(m, (y) => at(f[0], y));
          final ends = opensSideways ? [(f[0], f[1] + 2 * p), (f[0], f[1] - 2 * p)] : [(f[0] + 2 * p, f[1]), (f[0] - 2 * p, f[1])];
          for (final (x, y) in ends) {
            expect(at(x, y), closeTo(0, 1e-6), reason: '${m['q']} -> ${m['answer']}');
          }
        }
      }
    });

    test('ellipses and hyperbolas', () {
      for (final shape in ['ellipse', 'hyperbola']) {
        for (final level in [1, 2, 3]) {
          for (final m in _items(shape, level)) {
            final d = [for (final g in RegExp(r'/(\d+)').allMatches(m['q'])) double.parse(g[1]!)];
            final c = shape == 'ellipse' ? sqrt((d[0] - d[1]).abs()) : sqrt(d[0] + d[1]);
            final a = shape == 'ellipse' ? sqrt(max(d[0], d[1])) : sqrt(d[0]);
            if (level == 1) expect(_num(m['answer']), closeTo(c, 1e-9));
            if (level == 2) {
              // Hyperbola: x first means y = ±(b/a)x; y first means y = ±(a/b)x.
              final xFirst = RegExp(r'of \(?x').hasMatch(m['q']);
              final want = shape == 'ellipse' ? c / a : (xFirst ? sqrt(d[1] / d[0]) : sqrt(d[0] / d[1]));
              expect(_num(m['answer']), closeTo(want, 1e-9), reason: m['q']);
            }
            if (level == 3) {
              final center = [
                for (final v in ['x', 'y'])
                  RegExp('\\($v ([−+]) (\\d+)\\)').firstMatch(m['q']) == null
                      ? 0.0
                      : (RegExp('\\($v ([−+]) (\\d+)\\)').firstMatch(m['q'])![1] == '−' ? 1 : -1) *
                          double.parse(RegExp('\\($v ([−+]) (\\d+)\\)').firstMatch(m['q'])![2]!)
              ];
              final f = _numsOf(m['answer']), right = (m['q'] as String).contains('right');
              expect(f, right ? [center[0] + c, center[1]] : [center[0], center[1] + c], reason: m['q']);
            }
          }
        }
      }
    });
  });

  group('statistics and probability answers', () {
    List<double> data(String q) => _nums(q.substring(q.indexOf(': ') + 2, q.lastIndexOf(' (') > q.indexOf(': ') ? q.lastIndexOf(' (') : q.length));
    double mean(List<double> v) => v.reduce((a, b) => a + b) / v.length;
    double ss(List<double> v) => v.map((x) => pow(x - mean(v), 2)).reduce((a, b) => a + b).toDouble();

    test('mean, median, weighted mean, variance, standard deviation', () {
      for (final m in _items('center', 1)) {
        expect(_num(m['answer']), _near(mean(data(m['q']))));
      }
      for (final m in _items('center', 2)) {
        final v = data(m['q'])..sort();
        expect(_num(m['answer']), closeTo((v[v.length ~/ 2 - 1] + v[v.length ~/ 2]) / 2, 1e-9));
      }
      for (final m in _items('center', 3)) {
        final g = RegExp(r'(\d+) \((\d+) units\)').allMatches(m['q']).toList();
        final top = g.map((x) => double.parse(x[1]!) * double.parse(x[2]!)).reduce((a, b) => a + b);
        final units = g.map((x) => double.parse(x[2]!)).reduce((a, b) => a + b);
        expect(_num(m['answer']), _near(top / units));
      }
      for (final m in _items('spread', 1)) {
        final v = data(m['q']);
        expect(_num(m['answer']), _near(ss(v) / v.length));
      }
      for (final m in _items('spread', 2)) {
        final v = data(m['q']);
        expect(_num(m['answer']), _near(sqrt(ss(v) / (v.length - 1))));
      }
      for (final m in _items('spread', 3)) {
        final v = data(m['q']);
        expect(_num(m['answer']), _near(sqrt(ss(v) / (v.length - 1)) / mean(v) * 100));
      }
    });

    test('z-scores', () {
      for (final m in _items('zscore', 1)) {
        final n = _nums(m['q']);
        expect(_num(m['answer']), _near((n[2] - n[0]) / n[1]));
      }
      for (final m in _items('zscore', 2)) {
        final n = _nums(m['q']);
        expect(_num(m['answer']), _near(n[0] + n[2] * n[1]));
      }
      for (final m in _items('zscore', 3)) {
        final n = _nums(m['q']); // x, z, mean
        expect((n[0] - n[2]) / _num(m['answer']), closeTo(n[1], 1e-9));
      }
    });

    test('probability and counting', () {
      for (final m in _items('prob', 1)) {
        final n = _nums(m['q']), q = m['q'] as String;
        final pick = q.endsWith('red?') ? n[0] : q.endsWith('blue?') ? n[1] : n[2];
        expect(_num(m['answer']), closeTo(pick / (n[0] + n[1] + n[2]), 1e-9));
      }
      for (final m in _items('prob', 2)) {
        final s = _nums(m['q']).first, q = m['q'] as String;
        final k = q.contains('at least one') ? _nums(q.split('at least one').last).first : null;
        var hits = 0;
        for (var x = 1; x <= 6; x++) {
          for (var y = 1; y <= 6; y++) {
            if (x + y > s || (k == null ? x == y : x == k || y == k)) hits++;
          }
        }
        expect(_num(m['answer']), closeTo(hits / 36, 1e-9), reason: q);
      }
      for (final m in _items('prob', 3)) {
        final n = _nums(m['q']), r = n[0], b = n[1], all = r + b, q = m['q'] as String;
        // Count ordered pairs of different balls.
        final want = q.contains('two red') ? r * (r - 1) / (all * (all - 1)) : (r * b * 2) / (all * (all - 1));
        expect(_num(m['answer']), closeTo(want, 1e-9));
      }
      for (final m in _items('counting', 1, 5)) {
        expect(_num(m['answer']), _f(_nums(m['q']).first.toInt()));
      }
      for (final m in _items('counting', 2)) {
        final n = _nums(m['q']).first.toInt(), roles = RegExp(r'choose a (.+) \(').firstMatch(m['q'])![1]!.split(', ').length;
        expect(_num(m['answer']), _f(n) / _f(n - roles));
      }
      for (final m in _items('counting', 3)) {
        final n = _nums(m['q']).map((v) => v.toInt()).toList(); // size, men, women, k
        expect(_num(m['answer']), _c(n[2], n[3]) * _c(n[1], n[0] - n[3]));
      }
    });

    test('expected value', () {
      for (final m in _items('expected', 1)) {
        final n = _nums(m['q'].replaceAll('1/', '1 / ')); // cost, win, 1, n
        expect(_num(m['answer']), closeTo(n[1] / n[3] - n[0], 1e-9), reason: m['q']);
      }
      for (final level in [2, 3]) {
        for (final m in _items('expected', level)) {
          final p = [for (final g in RegExp(r'= (\d\.\d)').allMatches(m['q'])) double.parse(g[1]!)];
          expect(p.reduce((a, b) => a + b), closeTo(1, 1e-9));
          final mu = [for (var x = 0; x < 4; x++) x * p[x]].reduce((a, b) => a + b);
          final v = [for (var x = 0; x < 4; x++) pow(x - mu, 2) * p[x]].reduce((a, b) => a + b);
          expect(_num(m['answer']), _near(level == 2 ? mu : v));
        }
      }
    });

    test('binomial, Poisson and normal', () {
      for (final m in _items('binomial', 1)) {
        final n = _nums(m['q']), p = n[0], trials = n[1].toInt(), k = n[2].toInt();
        expect(_num(m['answer']), _near(_c(trials, k) * pow(p, k) * pow(1 - p, trials - k)));
      }
      for (final level in [2, 3]) {
        for (final m in _items('binomial', level)) {
          final n = _nums(m['q']), p = n[0], trials = n[1].toInt(), k = n[2].toInt();
          var atMost = 0.0;
          for (var i = 0; i <= (level == 2 ? k : k - 1); i++) {
            atMost += _c(trials, i) * pow(p, i) * pow(1 - p, trials - i);
          }
          expect(_num(m['answer']), _near(level == 2 ? atMost : 1 - atMost), reason: m['q']);
        }
      }
      for (final m in _items('poisson', 1)) {
        final n = _nums(m['q']), lambda = n[0], k = n[1].toInt();
        expect(_num(m['answer']), _near(pow(lambda, k) * exp(-lambda) / _f(k)));
      }
      for (final m in _items('normal', 1)) {
        final z = _nums(m['q']).first;
        final p = _area(z);
        expect(_num(m['answer']), closeTo((m['q'] as String).contains('<') ? p : 1 - p, .0002), reason: m['q']);
      }
      for (final m in _items('normal', 2)) {
        final n = _nums(m['q']), mu = n[0], sd = n[1], a = n[2], b = n[3];
        double z(double x) => double.parse(((x - mu) / sd).toStringAsFixed(2));
        expect(_num(m['answer']), closeTo(_area(z(b)) - _area(z(a)), .0003), reason: m['q']);
      }
      for (final m in _items('normal', 3)) {
        final n = _nums(m['q']), mu = n[0], sd = n[1], pct = n[2] / 100, top = (m['q'] as String).contains('top');
        // The share beyond the answer is the asked percent (within table rounding).
        final z = (_num(m['answer']) - mu) / sd;
        expect(top ? 1 - _area(z) : _area(z), closeTo(pct, .002), reason: m['q']);
      }
    });

    test('confidence intervals, test statistics, chi-square and correlation', () {
      const zStar = {90: 1.645, 95: 1.96, 99: 2.576};
      for (final m in _items('ci', 1)) {
        final n = _nums(m['q']); // n, mean, sigma, confidence
        expect(_num(m['answer']), _near(zStar[n[3].toInt()]! * n[2] / sqrt(n[0])));
      }
      for (final m in _items('ci', 2)) {
        final n = _nums(m['q']), e = zStar[n[3].toInt()]! * n[2] / sqrt(n[0]);
        expect(pairOk('(${n[1] - e}, ${n[1] + e})', m['answer']), isTrue, reason: m['q']);
      }
      for (final m in _items('ci', 3)) {
        final n = _nums(m['q']), p = n[1] / n[0], e = zStar[n[2].toInt()]! * sqrt(p * (1 - p) / n[0]);
        expect(pairOk('(${p - e}, ${p + e})', m['answer']), isTrue, reason: m['q']);
      }
      for (final level in [1, 2]) {
        for (final m in _items('hypothesis', level)) {
          final n = _nums(m['q']); // mu0, n, mean, sd
          expect(_num(m['answer']), _near((n[2] - n[0]) / (n[3] / sqrt(n[1]))));
        }
      }
      for (final m in _items('hypothesis', 3)) {
        final q = m['q'] as String, mu0 = _nums(q).first, v = _nums(q.substring(q.indexOf('sample: ') + 8, q.indexOf('. Find')));
        expect(_num(m['answer']), _near((mean(v) - mu0) / (sqrt(ss(v) / (v.length - 1)) / sqrt(v.length))));
      }
      for (final m in _items('chisq', 1)) {
        final q = m['q'] as String, seen = _nums(q.substring(q.indexOf('counts: ') + 8, q.indexOf('. Find')));
        final e = seen.reduce((a, b) => a + b) / 6;
        expect(_num(m['answer']), _near(seen.map((o) => pow(o - e, 2) / e).reduce((a, b) => a + b)));
      }
      for (final m in _items('chisq', 3)) {
        final o = _nums(m['q']).take(4).toList(), n = o.reduce((a, b) => a + b);
        final rows = [o[0] + o[1], o[2] + o[3]], cols = [o[0] + o[2], o[1] + o[3]];
        var chi = 0.0;
        for (var i = 0; i < 4; i++) {
          final e = rows[i ~/ 2] * cols[i % 2] / n;
          chi += pow(o[i] - e, 2) / e;
        }
        expect(_num(m['answer']), _near(chi));
      }
      for (final m in _items('correlation', 2)) {
        final p = [for (final g in RegExp(r'\((\d+), ([−-]?\d+)\)').allMatches(m['q'])) [_num(g[1]), _num(g[2])]];
        final xs = [for (final e in p) e[0]], ys = [for (final e in p) e[1]];
        var sxy = 0.0;
        for (var i = 0; i < p.length; i++) {
          sxy += (xs[i] - mean(xs)) * (ys[i] - mean(ys));
        }
        expect(_num(m['answer']), _near(sxy / sqrt(ss(xs) * ss(ys))));
      }
    });
  });
}

// The numbers of an answer like "(3, −2, 5)" or "(1/2, 4)".
List<double> _numsOf(Object? answer) => [for (final s in '$answer'.replaceAll(RegExp(r'[()]'), '').split(', ')) _num(s)];

// Where a one-letter function of the curve is zero near the axis (bisection on a wide bracket).
double _root(Map m, double Function(double) f) {
  for (var lo = -40.0; lo < 40; lo += .5) {
    var a = lo, b = lo + .5;
    if (f(a) * f(b) > 0) continue;
    for (var i = 0; i < 60; i++) {
      final c = (a + b) / 2;
      if (f(a) * f(c) <= 0) {
        b = c;
      } else {
        a = c;
      }
    }
    return (a + b) / 2;
  }
  fail('no vertex found for ${m['q']}');
}
