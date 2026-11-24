import 'dart:math';

import 'package:flutter/material.dart';

import 'examples.dart';
import 'solve.dart';
import 'store.dart';

// ----- Problem packs (Nov 24) -----
// Gamy reads which lessons a module teaches, then makes new problems for them at the level the student
// picks (Easy / Medium / Hard), works out the answer and writes every step. Nothing is read from the module's
// exercises: PDF text breaks fractions apart ("3/4 x" comes out on three lines). The module's own worked examples
// still come first (packItems). Round 1 (Nov 24): college algebra, trigonometry, analytic geometry, statistics
// and probability; the lessons are in college.dart, trig.dart and stats.dart.
part 'college.dart';
part 'trig.dart';
part 'stats.dart';

final _rng = Random();

// One lesson: how to tell a module teaches it, its name, its Wikipedia page and its problem maker.
typedef _Pack = ({String find, String en, String fil, String wiki, Map? Function(int level) make});

// In the order a course usually goes. A lesson counts when the module really teaches it (the same rule as the
// numerical methods: see teaches()), so a word used once in passing doesn't count.
final Map<String, _Pack> _packs = {
  'linear': (find: r'linear equation', en: 'Linear equations', fil: 'Linear equations', wiki: 'Linear equation', make: _linear),
  'inequalities': (find: r'\binequalit(?:y|ies)\b', en: 'Inequalities', fil: 'Inequalities', wiki: 'Inequality (mathematics)', make: _inequality),
  'absolute': (find: r'absolute value', en: 'Absolute value', fil: 'Absolute value', wiki: 'Absolute value', make: _absolute),
  'slope': (find: r'\bslopes?\b', en: 'Slope and lines', fil: 'Slope at mga linya', wiki: 'Slope', make: _slope),
  'systems': (find: r'systems? of (?:linear )?equations', en: 'Systems of equations', fil: 'Systems of equations', wiki: 'System of linear equations', make: _system),
  'polynomials': (find: r'\bpolynomials?\b', en: 'Polynomials', fil: 'Polynomials', wiki: 'Polynomial', make: _polynomial),
  'factoring': (find: r'\bfactor(?:ing|ization|isation)\b|\bfactor (?:the|each|completely)', en: 'Factoring', fil: 'Factoring', wiki: 'Factorization', make: _factoring),
  'rational': (find: r'rational (?:expressions?|equations?)', en: 'Rational expressions', fil: 'Rational expressions', wiki: 'Rational function', make: _rational),
  'radicals': (find: r'\bradicals?\b', en: 'Radicals', fil: 'Radicals', wiki: 'Nth root', make: _radical),
  'quadratics': (find: r'quadratic (?:equations?|formula|functions?)', en: 'Quadratic equations', fil: 'Quadratic equations', wiki: 'Quadratic equation', make: _quadratic),
  'functions': (find: r'composite functions?|composition of functions|inverse (?:of a )?functions?|f\s*\(\s*g\s*\(', en: 'Functions', fil: 'Functions', wiki: 'Function composition', make: _functions),
  'explog': (find: r'logarithm|exponential equations?', en: 'Exponents and logarithms', fil: 'Exponents at logarithms', wiki: 'Logarithm', make: _explog),
  'radians': (find: r'\bradians?\b', en: 'Angles and radians', fil: 'Angles at radians', wiki: 'Radian', make: _radians),
  'righttri': (find: r'right triangles?|angles? of (?:elevation|depression)', en: 'Right triangles', fil: 'Right triangles', wiki: 'Trigonometric functions', make: _rightTriangle),
  'unitcircle': (find: r'unit circle|reference angles?', en: 'Unit circle', fil: 'Unit circle', wiki: 'Unit circle', make: _unitCircle),
  'identities': (find: r'trigonometric identit|pythagorean identit', en: 'Trigonometric identities', fil: 'Trigonometric identities', wiki: 'List of trigonometric identities', make: _identities),
  'trilaws': (find: r'law of (?:sines|cosines)|(?:sine|cosine) law', en: 'Sine and cosine law', fil: 'Sine at cosine law', wiki: 'Law of cosines', make: _triangleLaws),
  'trigeq': (find: r'trigonometric equations?', en: 'Trigonometric equations', fil: 'Trigonometric equations', wiki: 'Trigonometric equation', make: _trigEquation),
  'distance': (find: r'distance formula|midpoint', en: 'Distance and midpoint', fil: 'Distance at midpoint', wiki: 'Euclidean distance', make: _distance),
  'circle': (find: r'equations? of (?:a |the )?circles?|center and radius', en: 'Circles', fil: 'Circles', wiki: 'Circle', make: _circle),
  'parabola': (find: r'\bparabolas?\b', en: 'Parabolas', fil: 'Parabolas', wiki: 'Parabola', make: _parabola),
  'ellipse': (find: r'\bellipses?\b', en: 'Ellipses', fil: 'Ellipses', wiki: 'Ellipse', make: _ellipse),
  'hyperbola': (find: r'\bhyperbola(?:s|e)?\b', en: 'Hyperbolas', fil: 'Hyperbolas', wiki: 'Hyperbola', make: _hyperbola),
  'center': (find: r'\bmedian\b|central tendency|arithmetic mean|weighted mean', en: 'Mean, median and mode', fil: 'Mean, median at mode', wiki: 'Central tendency', make: _center),
  'spread': (find: r'standard deviation|\bvariance\b', en: 'Variance and standard deviation', fil: 'Variance at standard deviation', wiki: 'Standard deviation', make: _spread),
  'zscore': (find: r'z-?scores?|standard scores?', en: 'z-scores', fil: 'z-scores', wiki: 'Standard score', make: _zScore),
  'prob': (find: r'\bprobabilit(?:y|ies)\b', en: 'Probability', fil: 'Probability', wiki: 'Probability', make: _probability),
  'counting': (find: r'permutations?|combinations?|counting principle', en: 'Permutations and combinations', fil: 'Permutations at combinations', wiki: 'Combination', make: _counting),
  'expected': (find: r'expected value|mathematical expectation', en: 'Expected value', fil: 'Expected value', wiki: 'Expected value', make: _expected),
  'binomial': (find: r'binomial (?:distribution|probabilit|experiment|random)', en: 'Binomial distribution', fil: 'Binomial distribution', wiki: 'Binomial distribution', make: _binomial),
  'poisson': (find: r'poisson', en: 'Poisson distribution', fil: 'Poisson distribution', wiki: 'Poisson distribution', make: _poisson),
  'normal': (find: r'normal (?:distribution|curve)|standard normal', en: 'Normal distribution', fil: 'Normal distribution', wiki: 'Normal distribution', make: _normal),
  'ci': (find: r'confidence intervals?', en: 'Confidence intervals', fil: 'Confidence intervals', wiki: 'Confidence interval', make: _interval),
  'hypothesis': (find: r'hypothesis test|null hypothesis|\bt-?tests?\b|\bz-?tests?\b', en: 'Hypothesis tests', fil: 'Hypothesis tests', wiki: 'Statistical hypothesis test', make: _hypothesis),
  'chisq': (find: r'chi-? ?squared?|χ²|χ2', en: 'Chi-square test', fil: 'Chi-square test', wiki: 'Chi-squared test', make: _chiSquare),
  'correlation': (find: r'correlation|regression line|least squares|linear regression', en: 'Correlation and regression', fil: 'Correlation at regression', wiki: 'Pearson correlation coefficient', make: _correlation),
};

// The lessons a module teaches, in course order. None for numerical methods modules: they have their own problems.
List<String> topicsIn(String text) =>
    teachesNumerical(text) ? const [] : [for (final e in _packs.entries) if (teaches(text, e.value.find)) e.key];

String _l(String en, String fil) => store.lang == 'fil' ? fil : en;
T _pick<T>(List<T> list) => list[_rng.nextInt(list.length)];

// A decimal answer with at most [places] places and no extra zeros: 2.50 -> "2.5", -0.0 -> "0".
String _dec(num v, [int places = 2]) {
  var s = v.toStringAsFixed(places);
  if (s.contains('.')) s = s.replaceFirst(RegExp(r'\.?0+$'), '');
  return s == '-0' ? '0' : s.replaceFirst('-', '−');
}

// ----- Exact fractions -----
int _gcd(int a, int b) => b == 0 ? a.abs() : _gcd(b, a % b);
int _lcm(int a, int b) => a ~/ _gcd(a, b) * b;

class Rat {
  final int n, d;
  const Rat._(this.n, this.d);
  factory Rat(int n, [int d = 1]) {
    if (d < 0) {
      n = -n;
      d = -d;
    }
    final g = _gcd(n, d) == 0 ? 1 : _gcd(n, d);
    return Rat._(n ~/ g, d ~/ g);
  }
  Rat operator +(Rat o) => Rat(n * o.d + o.n * d, d * o.d);
  Rat operator -(Rat o) => Rat(n * o.d - o.n * d, d * o.d);
  Rat operator *(Rat o) => Rat(n * o.n, d * o.d);
  Rat operator /(Rat o) => Rat(n * o.d, d * o.n);
  Rat operator -() => Rat(-n, d);
  bool get isZero => n == 0;
  bool get whole => d == 1;
  // The answer form students type: "3/4", "-2".
  @override
  String toString() => d == 1 ? '$n' : '$n/$d';
  // How it's shown: "−3/4"; inside a sum, fractions get brackets: "(3/4)".
  String get show => toString().replaceFirst('-', '−');
  @override
  bool operator ==(Object other) => other is Rat && other.n == n && other.d == d;
  @override
  int get hashCode => Object.hash(n, d);
}

Rat _r(int n, [int d = 1]) => Rat(n, d);
int _in(int lo, int hi) => lo + _rng.nextInt(hi - lo + 1);
int _nz(int lo, int hi) {
  for (;;) {
    final v = _in(lo, hi);
    if (v != 0) return v;
  }
}

// "3x", "−x", "(3/4)x"
String _term(Rat c, String v) {
  if (c == _r(1)) return v;
  if (c == _r(-1)) return '−$v';
  return c.whole ? '${c.show}$v' : '(${c.show})$v';
}

// A sum of terms with clean signs: [(3,'x'), (-5,'')] -> "3x − 5"; zero terms left out; "0" if all are zero.
String _sum(List<(Rat, String)> parts) {
  final b = StringBuffer();
  for (final (c, v) in parts) {
    if (c.isZero) continue;
    final abs = c.n < 0 ? -c : c, body = v.isEmpty ? abs.show : _term(abs, v);
    b.write(b.isEmpty ? (c.n < 0 ? '−$body' : body) : (c.n < 0 ? ' − $body' : ' + $body'));
  }
  return b.isEmpty ? '0' : b.toString();
}

String _times(Rat c) => c.whole ? c.show : '(${c.show})';

// ----- The quiz -----
// Problem solving for a module with lessons: its own worked examples first (up to half, new numbers each time),
// then new problems for the ticked lessons.
List<Map> packItems(String text, List<String> topics, int level, int count) {
  final mine = [
    for (final m in exampleItems(text).take(count ~/ 2))
      {...m, 'type': 'solve', 'part': _l('From your module', 'Mula sa module mo')}
  ];
  return [...mine, ...algebraItems(topics, level, count - mine.length)];
}

// [count] problems, split evenly over the [topics] and grouped topic by topic (each group is a part).
// More lessons than problems: a different handful of lessons each quiz, still in course order.
List<Map> algebraItems(List<String> topics, int level, int count) {
  if (topics.length > count) {
    final keep = ([...topics]..shuffle(_rng)).take(count).toSet();
    topics = [for (final t in topics) if (keep.contains(t)) t];
  }
  final out = <Map>[];
  for (var i = 0; i < topics.length; i++) {
    final want = count ~/ topics.length + (i < count % topics.length ? 1 : 0), seen = <String>{};
    for (var tries = 0; out.where((m) => m['part'] == _name(topics[i])).length < want && tries < want * 20; tries++) {
      final m = _packs[topics[i]]!.make(level);
      // The same words with a different graph is a different problem (Nov 24: Hard slope gave only one).
      if (m == null || !seen.add('${m['q']}${m['graph'] ?? ''}')) continue;
      out.add({...m, 'type': 'solve', 'part': _name(topics[i]), 'topic': _packs[topics[i]]!.wiki});
    }
  }
  return out;
}

String _name(String topic) => _l(_packs[topic]!.en, _packs[topic]!.fil);

// What the chip in the quiz setup says.
String topicName(String topic) => _name(topic);

// ----- Linear equations -----
Map? _linear(int level) {
  final x = level == 3 ? _r(_nz(-12, 12), _in(1, 4)) : _r(_nz(-9, 9));
  if (level == 1) {
    // ax + b = c
    final a = _r(_nz(-9, 9)), b = _r(_in(-15, 15)), c = a * x + b;
    if (a == _r(1) || a == _r(-1)) return null;
    return {
      'q': '${_l('Solve for x', 'Hanapin ang x')}: ${_sum([(a, 'x'), (b, '')])} = ${c.show}',
      'answer': '$x',
      'hint': _l('Undo the + or − first, then divide by the number next to x.',
          'Alisin muna ang + o −, tapos i-divide sa numerong katabi ng x.'),
      'why': [
        '${_sum([(a, 'x'), (b, '')])} = ${c.show}',
        if (!b.isZero) '${_l('Move', 'Ilipat ang')} ${b.show} ${_l('to the other side', 'sa kabila')}: ${_term(a, 'x')} = ${(c - b).show}',
        '${_l('Divide both sides by', 'I-divide ang magkabilang side sa')} ${a.show}: x = ${x.show}',
      ].join('\n'),
    };
  }
  if (level == 2) {
    // a(x + b) + c = dx + e
    final a = _r(_nz(-6, 6)), b = _r(_nz(-6, 6)), c = _r(_in(-10, 10)), d = _r(_nz(-5, 5));
    if (a == d || a == _r(1) || a == _r(-1)) return null;
    final e = a * (x + b) + c - d * x, left = a * b + c;
    return {
      'q': '${_l('Solve for x', 'Hanapin ang x')}: ${_times(a)}(${_sum([(_r(1), 'x'), (b, '')])})'
          '${c.isZero ? '' : (c.n < 0 ? ' − ${(-c).show}' : ' + ${c.show}')} = ${_sum([(d, 'x'), (e, '')])}',
      'answer': '$x',
      'hint': _l('Multiply out the brackets, put all the x on one side and the numbers on the other.',
          'I-distribute ang bracket, ilagay ang lahat ng x sa isang side at ang mga numero sa kabila.'),
      'why': [
        '${_l('Distribute', 'I-distribute')}: ${_sum([(a, 'x'), (a * b, ''), ])}${c.isZero ? '' : (c.n < 0 ? ' − ${(-c).show}' : ' + ${c.show}')} = ${_sum([(d, 'x'), (e, '')])}',
        '${_l('Combine', 'Pagsamahin')}: ${_sum([(a, 'x'), (left, '')])} = ${_sum([(d, 'x'), (e, '')])}',
        '${_l('x on the left, numbers on the right', 'x sa kaliwa, numero sa kanan')}: ${_term(a - d, 'x')} = ${(e - left).show}',
        '${_l('Divide by', 'I-divide sa')} ${(a - d).show}: x = ${x.show}',
      ].join('\n'),
    };
  }
  // Hard: A(x + B) = Cx + D with fractions, solved by clearing the denominators (the book's way).
  const dens = [2, 3, 4, 5, 6];
  final a = _r(_nz(-7, 7), dens[_rng.nextInt(5)]), b = _r(_nz(-5, 5)), c = _r(_nz(-7, 7), dens[_rng.nextInt(5)]);
  if (a == c || (a.whole && c.whole)) return null;
  final d = a * (x + b) - c * x, ab = a * b;
  final lcd = [a.d, ab.d, c.d, d.d].reduce(_lcm), big = _r(lcd);
  final la = a * big, lab = ab * big, lc = c * big, ld = d * big;
  return {
    'q': '${_l('Solve for x (a fraction is fine)', 'Hanapin ang x (puwede ang fraction)')}: '
        '${_times(a)}(${_sum([(_r(1), 'x'), (b, '')])}) = ${_sum([(c, 'x'), (d, '')])}',
    'answer': '$x',
    'hint': _l('Distribute, then multiply every term by the least common denominator to clear the fractions.',
        'I-distribute, tapos i-multiply ang bawat term sa least common denominator para mawala ang fractions.'),
    'why': [
      '${_l('Distribute', 'I-distribute')}: ${_sum([(a, 'x'), (ab, '')])} = ${_sum([(c, 'x'), (d, '')])}',
      '${_l('Least common denominator', 'Least common denominator')}: $lcd. ${_l('Multiply every term by', 'I-multiply ang bawat term sa')} $lcd:',
      '   ${_sum([(la, 'x'), (lab, '')])} = ${_sum([(lc, 'x'), (ld, '')])}',
      '${_l('x on the left, numbers on the right', 'x sa kaliwa, numero sa kanan')}: ${_term(la - lc, 'x')} = ${(ld - lab).show}',
      '${_l('Divide by', 'I-divide sa')} ${(la - lc).show}: x = ${x.show}',
    ].join('\n'),
  };
}

// ----- Slope and lines -----
Map? _slope(int level) {
  if (level == 3) return _graphLine();
  final x1 = _in(-8, 8), y1 = _in(-8, 8), x2 = _in(-8, 8), y2 = _in(-8, 8);
  if (x1 == x2) return null; // a vertical line has no slope
  final m = _r(y2 - y1, x2 - x1), b = _r(y1) - m * _r(x1);
  final p = '(${_r(x1).show}, ${_r(y1).show}) ${_l('and', 'at')} (${_r(x2).show}, ${_r(y2).show})';
  final slope = 'm = (y₂ − y₁) / (x₂ − x₁) = (${_r(y2).show} − ${_times(_r(y1))}) / (${_r(x2).show} − ${_times(_r(x1))})'
      ' = ${_r(y2 - y1).show} / ${_r(x2 - x1).show} = ${m.show}';
  if (level == 1) {
    return {
      'q': '${_l('Find the slope of the line through', 'Hanapin ang slope ng linyang dumadaan sa')} $p.',
      'answer': '$m',
      'hint': _l('Slope = change in y ÷ change in x.', 'Slope = pagbabago ng y ÷ pagbabago ng x.'),
      'why': slope,
    };
  }
  final line = 'y = ${_sum([(m, 'x'), (b, '')])}';
  return {
    'q': '${_l('Write the equation of the line through', 'Isulat ang equation ng linyang dumadaan sa')} $p. (y = mx + b)',
    'answer': line,
    'check': 'expr',
    'hint': _l('Find the slope m first, then put one point into y = mx + b to find b.',
        'Hanapin muna ang slope m, tapos ilagay ang isang point sa y = mx + b para makuha ang b.'),
    'why': [
      slope,
      '${_l('Put', 'Ilagay ang')} (${_r(x1).show}, ${_r(y1).show}) ${_l('into', 'sa')} y = mx + b: '
          '${_r(y1).show} = ${_times(m)}(${_r(x1).show}) + b  →  b = ${b.show}',
      line,
    ].join('\n'),
  };
}

// Hard: the line is drawn on a grid; the student reads two points and writes its equation.
Map? _graphLine() {
  final run = _in(1, 4), rise = _in(-4, 4), b = _in(-4, 4), m = _r(rise, run);
  if (rise == 0 && _rng.nextBool()) return null; // flat lines now and then, not half the time
  final line = 'y = ${_sum([(m, 'x'), (_r(b), '')])}';
  return {
    'q': _l('Write the equation of the line in the graph. (y = mx + b)',
        'Isulat ang equation ng linya sa graph. (y = mx + b)'),
    'answer': line,
    'check': 'expr',
    'graph': [0, b, run, b + rise],
    'hint': _l('Where does it cross the y-axis? That is b. Then count up/down and right between the dots.',
        'Saan tumatawid sa y-axis? Iyon ang b. Tapos bilangin ang taas/baba at kanan sa pagitan ng mga tuldok.'),
    'why': [
      '${_l('It crosses the y-axis at', 'Tumatawid ito sa y-axis sa')} (0, ${_r(b).show}), ${_l('so', 'kaya')} b = ${_r(b).show}.',
      '${_l('From that dot to the next: up', 'Mula sa tuldok na iyon papunta sa susunod: taas')} ${_r(rise).show}, '
          '${_l('right', 'kanan')} $run → m = ${_r(rise).show} / $run = ${m.show}',
      line,
    ].join('\n'),
  };
}

// ----- Systems of equations -----
Map? _system(int level) {
  if (level == 3) return _system3();
  final x = _nz(-6, 6), y = _nz(-6, 6);
  final a1 = level == 1 ? 1 : _nz(-7, 7), b1 = _nz(-7, 7), a2 = _nz(-7, 7), b2 = _nz(-7, 7);
  final det = a1 * b2 - a2 * b1;
  if (det == 0) return null;
  final c1 = a1 * x + b1 * y, c2 = a2 * x + b2 * y;
  String eq(int a, int b, int c) => '${_sum([(_r(a), 'x'), (_r(b), 'y')])} = ${_r(c).show}';
  final q = '${_l('Solve the system', 'Lutasin ang system')} (${level == 1 ? _l('substitution', 'substitution') : _l('elimination', 'elimination')}). '
      '${_l('Answer as (x, y)', 'Isagot bilang (x, y)')}:\n   ${eq(a1, b1, c1)}\n   ${eq(a2, b2, c2)}';
  final answer = '(${_r(x).show}, ${_r(y).show})';
  if (level == 1) {
    // x = c1 − b1·y, put into the second equation
    final k = a2 * -b1 + b2; // y's number after substituting
    return {
      'q': q,
      'answer': answer,
      'check': 'pair',
      'hint': _l('Get x alone in the first equation, then put it into the second.',
          'Ihiwalay ang x sa unang equation, tapos ilagay ito sa pangalawa.'),
      'why': [
        '${_l('From the first equation', 'Mula sa unang equation')}: x = ${_sum([(_r(c1), ''), (_r(-b1), 'y')])}',
        '${_l('Put it into the second', 'Ilagay sa pangalawa')}: ${_times(_r(a2))}(${_sum([(_r(c1), ''), (_r(-b1), 'y')])}) + ${_term(_r(b2), 'y')} = ${_r(c2).show}',
        '${_sum([(_r(a2 * c1), ''), (_r(k), 'y')])} = ${_r(c2).show}  →  ${_term(_r(k), 'y')} = ${_r(c2 - a2 * c1).show}  →  y = ${_r(y).show}',
        '${_l('Then', 'Tapos')}: x = ${_r(c1).show} − ${_times(_r(b1))}(${_r(y).show}) = ${_r(x).show}',
        '${_l('Answer', 'Sagot')}: $answer',
      ].join('\n'),
    };
  }
  // Elimination: multiply to cancel y, add, solve x, then y from the first equation.
  return {
    'q': q,
    'answer': answer,
    'check': 'pair',
    'hint': _l('Multiply the equations so the y terms cancel, then add them.',
        'I-multiply ang mga equation para magkansela ang y, tapos pagsamahin.'),
    'why': [
      '${_l('Multiply the first by', 'I-multiply ang una sa')} ${_r(b2).show} ${_l('and the second by', 'at ang pangalawa sa')} ${_r(-b1).show}:',
      '   ${eq(a1 * b2, b1 * b2, c1 * b2)}',
      '   ${eq(-a2 * b1, -b2 * b1, -c2 * b1)}',
      '${_l('Add them (y cancels)', 'Pagsamahin (nawawala ang y)')}: ${_term(_r(det), 'x')} = ${_r(c1 * b2 - c2 * b1).show}  →  x = ${_r(x).show}',
      '${_l('Put x into the first', 'Ilagay ang x sa una')}: ${_times(_r(a1))}(${_r(x).show}) + ${_term(_r(b1), 'y')} = ${_r(c1).show}  →  y = ${_r(y).show}',
      '${_l('Answer', 'Sagot')}: $answer',
    ].join('\n'),
  };
}

// Hard: three unknowns, solved with Cramer's rule (determinants), every determinant shown.
Map? _system3() {
  final s = [for (var i = 0; i < 3; i++) _nz(-5, 5)];
  final a = [for (var i = 0; i < 3; i++) [for (var j = 0; j < 3; j++) _in(-5, 5)]];
  int det(List<List<int>> m) =>
      m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1]) -
      m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0]) +
      m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0]);
  final d = det(a);
  if (d == 0 || a.any((r) => r.where((v) => v == 0).length > 1)) return null;
  final c = [for (final r in a) r[0] * s[0] + r[1] * s[1] + r[2] * s[2]];
  List<List<int>> swap(int col) => [for (var i = 0; i < 3; i++) [for (var j = 0; j < 3; j++) j == col ? c[i] : a[i][j]]];
  final dx = det(swap(0)), dy = det(swap(1)), dz = det(swap(2));
  String eq(List<int> r, int k) => '${_sum([(_r(r[0]), 'x'), (_r(r[1]), 'y'), (_r(r[2]), 'z')])} = ${_r(k).show}';
  final answer = '(${s.map((v) => _r(v).show).join(', ')})';
  return {
    'q': '${_l('Solve the system. Answer as (x, y, z)', 'Lutasin ang system. Isagot bilang (x, y, z)')}:\n'
        '   ${eq(a[0], c[0])}\n   ${eq(a[1], c[1])}\n   ${eq(a[2], c[2])}',
    'answer': answer,
    'check': 'pair',
    'hint': _l('Eliminate one letter from two pairs of equations, then solve the 2×2 system that is left.',
        'Alisin ang isang letra gamit ang dalawang pares ng equation, tapos lutasin ang natirang 2×2 system.'),
    'why': [
      _l("Cramer's rule (or elimination gives the same answer):", "Cramer's rule (pareho rin ang sagot sa elimination):"),
      '   D  = ${_r(d).show}',
      '   Dx = ${_r(dx).show}  →  x = Dx / D = ${_r(dx, d).show}',
      '   Dy = ${_r(dy).show}  →  y = Dy / D = ${_r(dy, d).show}',
      '   Dz = ${_r(dz).show}  →  z = Dz / D = ${_r(dz, d).show}',
      '${_l('Answer', 'Sagot')}: $answer',
    ].join('\n'),
  };
}

// ----- The graph for "line in the graph" problems -----
// A grid from −10 to 10 with the two whole-number dots marked and the line through them.
class LineGraph extends StatelessWidget {
  const LineGraph(this.points, {super.key});
  final List<num> points; // x1, y1, x2, y2
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SizedBox.square(
            dimension: 260, child: CustomPaint(painter: _Grid(points, Theme.of(context).colorScheme))),
      );
}

class _Grid extends CustomPainter {
  _Grid(this.p, this.colors);
  final List<num> p;
  final ColorScheme colors;
  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 20;
    Offset at(num x, num y) => Offset((x + 10) * unit, (10 - y) * unit);
    final grid = Paint()..color = colors.outlineVariant..strokeWidth = .5;
    final axis = Paint()..color = colors.onSurface..strokeWidth = 1.5;
    for (var i = -10; i <= 10; i++) {
      canvas.drawLine(at(i, -10), at(i, 10), i == 0 ? axis : grid);
      canvas.drawLine(at(-10, i), at(10, i), i == 0 ? axis : grid);
    }
    // The line, drawn across the whole grid (clipped to it).
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final m = (p[3] - p[1]) / (p[2] - p[0]);
    canvas.drawLine(at(-10, p[1] + m * (-10 - p[0])), at(10, p[1] + m * (10 - p[0])),
        Paint()..color = colors.primary..strokeWidth = 2.5);
    canvas.restore();
    for (var i = 0; i < 4; i += 2) {
      canvas.drawCircle(at(p[i], p[i + 1]), 4.5, Paint()..color = colors.primary);
    }
  }

  @override
  bool shouldRepaint(_Grid old) => old.p != p;
}
