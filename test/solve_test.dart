import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamy/brain.dart';
import 'package:gamy/quiz.dart';
import 'package:gamy/rules.dart';
import 'package:gamy/solve.dart';
import 'package:gamy/store.dart';

import 'helpers.dart';

// Tests for problem solving (solve.dart): finding formulas, the calculator, checking answers, and a full quiz.

// A pretend electronics module: formulas mixed with ordinary sentences that look a bit like formulas.
const _module = '''
Electronics Module 2
Ohm's law states that V = I x R, where V is voltage in volts.
Power is computed as P = V × I.
Total resistance in series: R_T = R1 + R2 + R3
Force: F = m × a, where m is mass.
Energy E = mc² is famous.
The answer = yes, of course.
Set x = 5 and continue.
Parallel: R_P = R1 R2 / (R1 + R2)
y = 2x^2 + 3x - 5
''';

void main() {
  setUp(() => store.lang = 'en');

  group('finding formulas', () {
    test('finds the 7 formulas and nothing else', () {
      expect(formulas(_module).map((f) => f.text), [
        'V = I x R',
        'P = V × I',
        'R_T = R1 + R2 + R3',
        'F = m × a',
        'E = mc²',
        'R_P = R1 R2 / (R1 + R2)',
        'y = 2x^2 + 3x - 5',
      ]);
    });

    test('knows what each formula needs', () {
      final f = {for (final x in formulas(_module)) x.result: x.inputs};
      expect(f['V'], ['I', 'R']);
      expect(f['R_T'], ['R1', 'R2', 'R3']);
      expect(f['E'], ['m', 'c']);
    });

    test('"y = f(x)" is function notation, not "f times x"', () {
      const text = 'The relation is written y = f(x) in the module.';
      expect(formulas(text), isEmpty);
      expect(functions(text), isEmpty);
    });

    test("the module's own function becomes find f(...) problems with the right answers", () {
      // (No method named here: "false position" in the text would give method problems instead.)
      const text = 'The function f(x) = e^x − 4√x grows fast.';
      final f = functions(text).single;
      expect(f.text, 'f(x) = e^x − 4√x');
      expect(f.calc({'x': 1}), closeTo(exp(1) - 4, 1e-9));
      final items = solveItems(text, 5);
      expect(items, hasLength(5));
      for (final m in items) {
        final x = double.parse(RegExp(r'find f\(([\d.]+)\)\.$').firstMatch(m['q'])![1]!);
        expect(numberOk(m['answer'], fmt(exp(x) - 4 * sqrt(x))), isTrue, reason: m['q']);
      }
    });

    test('functions from a real PDF: math letters, spaces and flattened powers (Nov 21 module)', () {
      // How the Numerical Methods module comes out of the PDF, after plainText().
      const pdf = 'Example 1.) Find a root of an equation f(x) = x 3 − x − 1 using False Position method\n'
          'Example 2.) Find a root of an equation f(x) = e x − 4√x using False Position method using\n'
          'Example 3.) Find a root of an equation f(x) = e −x − x using Successive Substitution\n'
          'Example 4.) Find the roots of an equation f (x ) = x 3 + 2x 2 + 10x − 20 using the method.';
      final fs = {for (final f in functions(pdf)) f.text: f};
      expect(fs.keys, ['f(x) = x^3 − x − 1', 'f(x) = e^x − 4√x', 'f(x) = e^(−x) − x', 'f(x) = x^3 + 2x^2 + 10x − 20']);
      expect(fs['f(x) = x^3 − x − 1']!.calc({'x': 2}), 5);
      expect(fs['f(x) = e^(−x) − x']!.calc({'x': 1}), closeTo(exp(-1) - 1, 1e-9));
      expect(fs['f(x) = x^3 + 2x^2 + 10x − 20']!.calc({'x': 1}), -7);
    });

    // Exactly how Gamy saved the Numerical Methods PDF (Nov 22): math letters, Windows line breaks, and every
    // power pushed onto the next line. This gave "f(x) = x" problems before.
    test("the module's saved text: powers on the next line are joined back", () {
      const saved = 'Example 1.) Find a root of an equation 𝑓(𝑥) = 𝑥\r\n3 − 𝑥 − 1 using False Position method\r\n'
          'using 𝑑\r\n𝑘 ≤ 0.0001 to stop iterations.\r\n'
          'Example 2.) Find a root of an equation 𝑓(𝑥) = 𝑒\r\n𝑥 − 4√𝑥 using False Position method using \r\n'
          'Example 1.) Find a root of an equation 𝑓(𝑥) = 𝑒\r\n−𝑥 − 𝑥 using Successive Substitution\r\n'
          'b. find the roots of 𝑓(𝑥) =\r\n𝑒\r\n3\r\n2\r\n− 3√𝑥 + 0.2 lies between\r\n';
      final text = plainText(saved);
      expect(functions(text).map((f) => f.text), ['f(x) = x^3 − x − 1', 'f(x) = e^x − 4√x', 'f(x) = e^(−x) − x']);
      final items = solveItems(text, 100);
      expect(items, isNotEmpty);
      for (final m in items) {
        expect(m['q'], contains('false position method'), reason: 'only the method this module names');
        expect(m['q'], isNot(contains('f(x) = x,')), reason: 'never the useless "f(x) = x"');
      }
    });

    test('"f(x) = x" alone is not a function to make problems from', () {
      expect(functions('Here f(x) = x and nothing else'), isEmpty);
    });

    test('the false position and bisection methods give the same numbers as the module', () {
      double f(double x) => x * x * x - x - 1;
      final fp = rootSteps('false_position', f, 1, 2);
      expect(fp.take(3).map((x) => x.toStringAsFixed(4)), ['1.1667', '1.2531', '1.2934']);
      expect(fp.last, closeTo(1.3247, 0.0002));
      expect(rootSteps('bisection', f, 1, 2).first, 1.5);
      double g(double x) => exp(x) - 4 * sqrt(x);
      expect(rootSteps('false_position', g, 1, 2).last, closeTo(1.6308, 0.0002), reason: "the module's Example 2");
    });

    test("a numerical methods module gets problems on its own methods and functions, with right answers", () {
      store.lang = 'en';
      const module = 'The False Position (Regula Falsi) Method. A shortcoming of the bisection method is speed.\n'
          'Example 1.) Find a root of an equation f(x) = x 3 − x − 1 using False Position method.';
      final items = solveItems(module, 100);
      expect(items, hasLength(8), reason: '2 methods x (steps 1, 2, 3 + the root)');
      for (final m in items) {
        expect(m['q'], contains('f(x) = x^3 − x − 1'));
        expect(m['q'], anyOf(contains('false position method'), contains('bisection method')));
      }
      final root = items.firstWhere((m) => (m['q'] as String).contains('false position') && (m['q'] as String).contains('find the root'));
      expect(numberOk('1.3247', root['answer']), isTrue);
      final step1 = items.firstWhere((m) => (m['q'] as String).contains('false position') && (m['q'] as String).contains('step 1'));
      expect(step1['answer'], '1.1667');
    });

    test('every problem shows its full solution', () {
      store.lang = 'en';
      const module = 'The False Position (Regula Falsi) Method.\n'
          'Example 1.) Find a root of an equation f(x) = x 3 − x − 1 using False Position method.';
      final step1 = solveItems(module, 100)
          .firstWhere((m) => (m['q'] as String).contains('false position') && (m['q'] as String).contains('step 1'));
      final table = step1['why'] as String;
      expect(table, contains('f(x-)'), reason: 'the step table, like the module');
      expect(table, matches(RegExp(r'1\.1667[^\n]*<-')), reason: 'the asked step is marked');
      expect(table, contains('1.3247'), reason: 'and it ends with the root');
      // Formula problems show the numbers put in: "P = (3) × (4) = 12"
      for (final m in solveItems('Power is computed as P = V × I.', 20)) {
        expect(m['why'], contains('(')); // the given numbers in brackets
        expect(m['why'], contains('= ${m['answer']}'));
      }
      // Functions show the substitution: "f(2) = (2)^2 + 3(2) = 10"
      final fn = solveItems('The function f(x) = x^2 + 3x grows fast.', 1).single;
      expect(fn['why'], contains('= ${fn['answer']}'));
    });

    test('a module without methods still gets formula problems', () {
      expect(methodItems(_module), isEmpty);
      expect(solveItems(_module, 3).first['q'], startsWith('Using '));
    });

    test('a function a PDF garbled ("ex" instead of e^x) is skipped, not asked wrongly', () {
      expect(functions('f(x) = ex − 4√x'), isEmpty);
    });

    test('ordinary sentences are not formulas', () {
      expect(formulas('Hello there. The score = high. Set x = 5. Ohm is a unit.'), isEmpty);
    });
  });

  group('calculator', () {
    double calc(String formula, Map<String, double> values) => formulas(formula).single.calc(values);

    test('does the math in the right order', () {
      expect(calc('V = I x R', {'I': 3, 'R': 4}), 12);
      expect(calc('V = IR', {'I': 3, 'R': 4}), 12, reason: 'side by side means times');
      expect(calc('y = 2x^2 + 3x - 5', {'x': 2}), 9);
      expect(calc('R_P = R1 R2 / (R1 + R2)', {'R1': 6, 'R2': 3}), 2);
      expect(calc('E = mc²', {'m': 2, 'c': 3}), 18);
      expect(calc('y = -x^2', {'x': 3}), -9, reason: 'the power comes before the minus sign');
      expect(calc('y = (a + b) / 2', {'a': 3, 'b': 4}), 3.5);
    });
  });

  group('checking answers', () {
    test('accepts units, decimals and rounding within 1%', () {
      expect(numberOk('12', '12'), isTrue);
      expect(numberOk('12 V', '12'), isTrue);
      expect(numberOk('12.0', '12'), isTrue);
      expect(numberOk('0.33', '0.33'), isTrue);
      expect(numberOk('1,200', '1200'), isTrue);
      expect(numberOk('11.95', '12'), isTrue);
      expect(numberOk('11', '12'), isFalse);
      expect(numberOk('', '12'), isFalse);
      expect(numberOk('twelve', '12'), isFalse);
    });

    test('numbers are shown cleanly', () {
      expect(fmt(12), '12');
      expect(fmt(1 / 3), '0.33');
      expect(fmt(2.5), '2.5');
    });
  });

  group('making problems', () {
    test('every answer is right, and there are forward and backward problems', () {
      final items = solveItems(_module, 200);
      expect(items, hasLength(200));
      final kinds = <String>{};
      for (final m in items) {
        expect(m['type'], 'solve');
        expect(m['q'], startsWith('Using '));
        // Re-solve it from the question text: the formula, what to find, and the given values.
        final q = RegExp(r'^Using (.+), find (\w+) when (.+)\.$').firstMatch(m['q'])!;
        final f = formulas(q[1]!).single;
        final given = {
          for (final g in q[3]!.split(', ')) g.split(' = ')[0]: double.parse(g.split(' = ')[1])
        };
        final ask = q[2]!;
        if (ask == f.result) {
          kinds.add('forward');
          expect(numberOk(fmt(f.calc(given)), m['answer']), isTrue, reason: m['q']);
        } else {
          kinds.add('backward');
          // Put the expected answer back in: it must give the stated result.
          final all = {...given, ask: double.parse(m['answer'])};
          expect(numberOk(fmt(f.calc(all)), fmt(given[f.result]!)), isTrue, reason: m['q']);
        }
      }
      expect(kinds, {'forward', 'backward'});
    });

    test('a module without formulas says so', () {
      expect(() => solveItems('A router is a device that sends data between networks.', 5), throwsA('no_formulas'));
    });

    test('Filipino questions', () {
      store.lang = 'fil';
      expect(solveItems(_module, 1).single['q'], startsWith('Gamit ang '));
    });
  });

  group('problem solving quiz', () {
    late Directory dir;
    setUp(() async {
      dir = await freshStore();
      await brain.start();
    });
    tearDown(() async {
      store.close();
      await dir.delete(recursive: true);
    });

    testWidgets('solve every problem, typed with a unit, and get a perfect score', (tester) async {
      tester.view.physicalSize = const Size(1000, 8000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      store.subjects = [
        {
          'name': 'Electronics',
          'modules': [
            {'name': 'Power', 'text': 'Power is computed as P = V × I.'}
          ],
          'scores': [],
        }
      ];
      final t = store.t;
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Quiz())));
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Electronics').last); // the subject (folder)
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Power')); // then its module
      await tester.pumpAndSettle();
      await tester.tap(find.text(t('solve')));
      await tester.pump();
      await tester.tap(find.text(t('start')));
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      final n = fields.evaluate().length;
      expect(n, greaterThan(0));
      for (var i = 0; i < n; i++) {
        final q = tester.widget<Text>(find.textContaining(RegExp('^${i + 1}\\. '))).data!;
        final m = RegExp(r'find (\w+) when (\w+) = ([\d.]+), (\w+) = ([\d.]+)\.$').firstMatch(q)!;
        final v = {m[2]!: double.parse(m[3]!), m[4]!: double.parse(m[5]!)};
        final answer = switch (m[1]) {
          'P' => v['V']! * v['I']!,
          'V' => v['P']! / v['I']!,
          _ => v['P']! / v['V']!,
        };
        await tester.enterText(fields.at(i), '${fmt(answer)} W');
      }
      await tester.tap(find.text(t('submit')));
      await tester.pump();
      expect(find.text('${t('score')}: $n / $n'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
