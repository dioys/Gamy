import 'package:flutter_test/flutter_test.dart';
import 'package:gamy/examples.dart';
import 'package:gamy/solve.dart';
import 'package:gamy/store.dart';

// Worked examples from different subjects, written the way modules usually write them.
const _module = '''
Example 1. A gas occupies 2.5 L at 300 K. What volume will it occupy at 350 K at the same pressure?
Solution:
V2 = V1 × T2 / T1 = 2.5 L × 350 K / 300 K = 2.92 L
Example 2: How many moles are in 36 g of water if its molar mass is 18 g/mol?
n = m / M = 36 / 18 = 2 mol
Example 3. A car starts from rest and accelerates at 3 m/s² for 5 s. Find its final speed and the distance it travels.
v = a × t = 3 × 5 = 15 m/s
d = ½ a t² = 0.5 × 3 × 5² = 37.5 m
Example 4. The scores are 4, 8, 6, 5 and 7. Find the mean.
mean = (4 + 8 + 6 + 5 + 7) / 5 = 30 / 5 = 6
Example 5. You deposit 5000 pesos at 6% simple interest for 3 years. How much interest do you earn?
I = P × r × t = 5000 × 0.06 × 3 = 900 pesos
''';

// Worked problems written as paragraphs, the way many books do it ("For example, suppose..."). Written for this
// test in the style of a chemistry book (Nov 24: Gamy missed these and only found bare formulas).
const _prose = '''
Boyle's law says P1V1 = P2V2 when the temperature stays the same.
For example, suppose a gas fills 6.00 liters at 2.00 atm, and you squeeze it into 3.00 liters.
What is the new pressure? Put the numbers into the formula:
P1V1 = P2V2
P2 = (2.00 atm)(6.00 L)/3.00 L = 4.00 atm
That makes sense: less room, more pressure.
Charles's law says V1/T1 = b V2/T2 = b
For example, imagine a balloon of 2.00 liters on a cold day at –13°C.
You bring it into a room at 27°C. What is its new volume?
Change both temperatures to Kelvin first:
Outside: –13°C + 273 = 260 K
Inside: 27°C + 273 = 300 K
Now solve V1/T1 = V2/T2 for V2:
[V1T2]/T1 = V2
Then put in the numbers:
[(2.00 L)(300 K)]/260 K = V2 = 2.31 L
''';

List<double> _numbers(String q) =>
    [for (final m in RegExp(r'(?<![\w.])\d+(?:\.\d+)?').allMatches(q.split('\n').first)) double.parse(m[0]!)];

void main() {
  setUp(() => store.lang = 'en');

  test('every example it can re-check becomes one problem with new numbers; unsafe ones are skipped', () {
    final items = exampleItems(_module);
    expect(items, hasLength(4), reason: 'gas, moles, motion, interest; the mean (5 in two roles) is skipped');
    expect(items.map((m) => m['key']).toSet(), hasLength(4), reason: 'one per example, no repeats');
    expect(items.any((m) => (m['q'] as String).contains('scores')), isFalse);
  });

  test('the answers are right for the new numbers (re-solved independently)', () {
    for (var round = 0; round < 30; round++) {
      for (final m in exampleItems(_module)) {
        final q = m['q'] as String, n = _numbers(q), answer = numberOf(m['answer'])!;
        final expected = switch (q) {
          _ when q.contains('gas occupies') => n[0] * n[2] / n[1],
          _ when q.contains('moles') => n[0] / n[1],
          _ when q.contains('accelerates') => 0.5 * n[0] * n[1] * n[1],
          _ => n[0] * n[1] / 100 * n[2],
        };
        expect(answer, closeTo(expected, expected.abs() * .02 + .01), reason: '$q -> ${m['answer']}');
        expect(m['why'], contains(m['answer']), reason: 'the solution ends with the answer');
      }
    }
  });

  test('new numbers every time, and the question asks for what the last step finds', () {
    final motion = exampleItems(_module).firstWhere((m) => (m['q'] as String).contains('accelerates'));
    expect(_numbers(motion['q']), isNot([3, 5]), reason: 'not the module\'s own numbers');
    expect(motion['q'], endsWith('Find d (m).'));
    expect(motion['why'], contains('v = a × t = '), reason: 'every step of the module is shown');
    final interest = exampleItems(_module).firstWhere((m) => (m['q'] as String).contains('interest'));
    expect(interest['q'], isNot(contains(' 6%')), reason: 'the rate changes too (6% is 0.06 in the solution)');
  });

  test('problem solving uses the examples first, and doesn\'t ask their formulas again', () {
    final items = solveItems(_module, 10);
    expect(items.where((m) => '${m['key']}'.startsWith('ex|')), hasLength(4));
    expect(items.where((m) => (m['q'] as String).startsWith('Using V2 = V1')), isEmpty);
  });

  test('a module without worked examples or formulas still says so', () {
    expect(exampleItems('Mitosis is cell division. Example: skin cells divide often.'), isEmpty);
    expect(() => solveItems('Mitosis is cell division. Example: skin cells divide often.', 10), throwsA('no_formulas'));
  });

  test('worked problems written as paragraphs are found and re-solved (gas laws, Nov 24)', () {
    for (var round = 0; round < 30; round++) {
      final items = exampleItems(_prose);
      expect(items, hasLength(2), reason: "Boyle's law and Charles's law");
      for (final m in items) {
        final q = m['q'] as String, n = _numbers(q), answer = numberOf(m['answer'])!;
        expect(q, isNot(startsWith('For example')), reason: 'starts with the problem itself');
        final expected = q.contains('pressure') ? n[1] * n[0] / n[2] : n[0] * (n[2] + 273) / (273 - n[1]);
        expect(answer, closeTo(expected, expected * .02), reason: '$q -> ${m['answer']}');
      }
    }
  });

  test('a piece of a longer equation is not a formula ("V1/T1 = b V2/T2" gives no "T1 = b V2/T2")', () {
    expect(formulas(_prose).where((f) => f.text.startsWith('T1') || f.text.startsWith('T2')), isEmpty);
  });
}
