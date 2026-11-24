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

// A piece of Numerical Methods Module 3 (Part III), as Gamy's PDF reader saves it: the general form (letters,
// not numbers), worked examples, the answers written as "x = 2", a repeated example and a reordered one.
const _module3 = '''
Jacobi Method and Gauss-Seidel Method
a11x1 + a12x2 + a13x3 + a14x4 = b1 x1 =\r
a21x1 + a22x2 + a23x3 + a24x4 = b2 x2 =\r
Example 2: Solve the system of equations using the Jacobi Method.\r
3x − 2y + z = 11\r
x − 3y + 2z = 11\r
2x + y − 4z = −9\r
Obtain the final answer to one decimal place. Use absolute relative error d k ≤ 0.001.\r
x = 2\r
y = −1\r
z = 3\r
Example 3: Solve the following system of equations using Gauss-Seidel method.\r
45x1 + 2x2 + 3x3 = 58\r
−3x1 + 22x2 + 2x3 = 47\r
5x1 + x2 + 20x3 = 67\r
Obtain the final answers to two decimal places. Use absolute relative error d k ≤ 0.0001.\r
Example 4: the same system as Example 2.\r
3x − 2y + z = 11\r
x − 3y + 2z = 11\r
2x + y − 4z = −9\r
Example 5:\r
x + 4y − 2z = −2\r
2x + 3y + 8z = 39\r
5x + y + 2z = 19\r
3.) Use (x)0 = { 0, 0 }.\r
x1 − 5x2 = −4\r
7x1 − x2 = 6\r
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

    // Nov 23: a proof book's "L1 = p1L" (joining maps) became "find p1 when L = 11".
    test('equations inside proofs are not number formulas', () {
      final text = 'Suppose that L1 : U → V1 and L2 : U → V2 are linear maps. We recover L1 from L by L1 = p1L.\n'
          '${'Groups are studied in this book. ' * 10}\n'
          "Ohm's law states that V = I x R, where V is voltage.";
      expect(formulas(text).map((f) => f.text), ['V = I x R']);
    });

    // Nov 23: the algebra book still gave "Using k = m + 1, find m when k = 9" from its proofs.
    test('a proof book says so instead of making letter "problems"', () {
      final book = List.filled(40, 'Theorem 3. Let k = m + 1. Prove that the map L : U → V is an isomorphism.').join('\n');
      expect(proofBook(book), isTrue);
      expect(() => solveItems(book, 10), throwsA('proof_book'));
      expect(proofBook("A proof is shown. Ohm's law: V = I x R."), isFalse, reason: 'one word is not a proof book');
      expect(store.t('proof_book'), isNot(contains('{')));
    });

    // Nov 23: 50 problems from a 700-page book all came from its first 10%.
    test('problems come from the whole module, not just its first pages', () {
      final text = [for (var i = 1; i <= 100; i++) 'Rule $i says Q$i = R$i x S$i, where Q is a quantity.'].join('\n');
      final used = {
        for (final m in solveItems(text, 10)) int.parse(RegExp(r'Q(\d+) =').firstMatch(m['q'] as String)![1]!)
      };
      expect(used.where((i) => i <= 50), isNotEmpty);
      expect(used.where((i) => i > 50), isNotEmpty);
      expect(used, hasLength(10), reason: '10 different formulas, spread out');
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
      final items = [for (var i = 0; i < 5; i++) ...solveItems(text, 5)];
      expect(solveItems(text, 5), hasLength(1), reason: 'Nov 24: one function = one problem, no repeats');
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
        // Nov 23: this module also teaches successive substitution, so its problems come too.
        expect(m['q'], anyOf(contains('false position method'), contains('successive substitution method')),
            reason: 'only the methods this module names');
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
      // Every question Gamy can make about it: 2 methods x (steps 1, 2, 3 + the root)...
      final items = methodItems(module);
      expect(items, hasLength(8));
      // ...but a quiz asks about each problem once (Nov 24: no repeats): one per method.
      final quiz = solveItems(module, 100);
      expect(quiz, hasLength(2));
      expect(quiz.map((m) => (m['q'] as String).contains('false position')).toSet(), {true, false});
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
      final step1 = methodItems(module)
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
    // Nov 24: a biology module got "r = b − d" four times with new numbers. One formula = one question.
    test('a module with one formula gets one problem, not the same formula again and again', () {
      const biology = 'Population growth rate: r = b − d, where b is the birth rate and d the death rate.';
      expect(solveItems(biology, 10), hasLength(1));
    });

    test('every answer is right, and there are forward and backward problems', () {
      // Nov 24: each formula once per quiz, so 200 asked gives one problem per formula (no repeats)...
      final once = solveItems(_module, 200);
      expect(once.length, formulas(_module).length + functions(_module).length);
      expect(once.map((m) => RegExp(r'^Using (.+), find').firstMatch(m['q'])![1]).toSet(), hasLength(once.length));
      // ...and many quizzes in a row check the answers and both directions (new numbers every time).
      final items = [for (var i = 0; i < 40; i++) ...solveItems(_module, 200)];
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

  // Nov 22: Module 3 (systems of linear equations) gave no problems at all. Now it gets Jacobi and
  // Gauss-Seidel problems, solved like the module's own examples.
  group('systems of equations (Jacobi, Gauss-Seidel)', () {
    test("finds the module's systems once each, and nothing else", () {
      final found = systems(_module3);
      expect([for (final s in found) s.vars], [
        ['x', 'y', 'z'],
        ['x1', 'x2', 'x3'],
        ['x', 'y', 'z'],
        ['x1', 'x2'],
      ], reason: 'not the a11x1 general form, not the "x = 2" answers, and Example 4 only once');
      expect(found[0].a, [
        [3, -2, 1],
        [1, -3, 2],
        [2, 1, -4],
      ]);
      expect(found[0].b, [11, 11, -9]);
      expect(found[0].tol, 0.001);
      expect(found[1].tol, 0.0001, reason: "each system keeps its own stopping rule");
    });

    List<double> round4(List<double> x) => [for (final v in x) double.parse(v.toStringAsFixed(4))];

    test("Jacobi matches the module's Example 2", () {
      final rows = iterateSystem('jacobi', systems(_module3)[0])!;
      expect(round4(rows[1].x), [3.6667, -3.6667, 2.25]);
      expect(rows.last.d, lessThanOrEqualTo(0.001));
      for (final (v, want) in [(rows.last.x[0], 2.0), (rows.last.x[1], -1.0), (rows.last.x[2], 3.0)]) {
        expect(v, closeTo(want, 0.01));
      }
    });

    test("Gauss-Seidel matches the module's Example 3", () {
      final rows = iterateSystem('seidel', systems(_module3)[1])!;
      expect(round4(rows[1].x), [1.2889, 2.3121, 2.9122]);
      expect(round4(rows[2].x), [0.992, 2.0069, 3.0017]);
      expect(round4(rows.last.x), [1, 2, 3]);
    });

    test('new practice systems always work out to whole-number answers', () {
      for (var i = 0; i < 50; i++) {
        final s = practiceSystem();
        for (final m in ['jacobi', 'seidel']) {
          for (final v in iterateSystem(m, s)!.last.x) {
            expect(v, closeTo(v.roundToDouble(), 0.02), reason: '$m $s');
          }
        }
      }
    });

    test('problems ask about both methods, each with its full solution and the answer inside it', () {
      final items = [...systemItems(_module3)];
      expect(items.map((m) => m['topic']).toSet(), {'Jacobi method', 'Gauss–Seidel method'});
      // A quiz asks about each system once per method (Nov 24: no repeats).
      final quiz = solveItems(_module3, 500);
      expect(quiz.map((m) => m['key']).toSet(), hasLength(quiz.length));
      for (final m in items) {
        expect(m['type'], 'solve');
        expect(m['q'], anyOf(contains('Jacobi method'), contains('Gauss-Seidel method')));
        final why = m['why'] as String;
        for (final part in ['sys_rewrite', 'sys_table', 'sys_answer']) {
          expect(why, contains(store.t(part).split('{').first), reason: part);
        }
        expect(why, contains(m['answer']), reason: 'the answer is in the solution table');
        expect(numberOk(m['answer'], m['answer']), isTrue);
      }
    });

    test('Example 5 is put in a working order first, and the solution says so', () {
      final items = systemItems('Jacobi method\n${_module3.split('Example 5:\r\n')[1].split('3.)').first}', practice: 0);
      expect(items, isNotEmpty);
      expect(items.first['why'], contains(store.t('sys_order')));
      expect(items.first['q'], contains('x + 4y − 2z = −2'), reason: 'the question shows the system as written');
    });

    test('a big book that names Jacobi only in passing gets no Jacobi problems (Nov 23, algebra book)', () {
      final book = '${'Groups, rings and fields are studied in this chapter. ' * 4000}'
          'The Jacobi identity holds. Jacobi also studied elliptic functions.\n'
          '3x − 2y + z = 11\nx − 3y + 2z = 11\n2x + y − 4z = −9\n';
      expect(systemItems(book), isEmpty);
      expect(systemItems(_module3), isNotEmpty, reason: 'Module 3 really teaches it');
    });

    test('a module that never names the methods gets no system problems', () {
      expect(systemItems('3x − 2y + z = 11\nx − 3y + 2z = 11\n2x + y − 4z = −9'), isEmpty);
    });
  });

  // Nov 23: Module 2 teaches successive substitution, but Gamy made no problems for it.
  group('successive substitution (Module 2)', () {
    const module2 = 'The Successive Substitution Method. Given f(x) = 0, rewrite it as x = g(x).\n'
        'Example 1.) Find a root of an equation f(x) = e\n−x − x using Successive Substitution method.\n'
        'Example 2.) Find the roots of an equation f(x) = x\n3 − 3x + 1 using Successive Substitution method.\n'
        '2.) Find the roots of f(x) = x\n3 + 2x\n2 + 10x − 20 using the successive substitution method.';
    late List<Map> items;
    setUp(() {
      store.lang = 'en';
      items = successiveItems(module2);
    });
    Map root(String g) => items.firstWhere((m) => (m['q'] as String).contains('x = $g') && (m['q'] as String).contains('find the root'));

    test("matches the module's Example 1: x = e^(-x) from x0 = 1", () {
      final step1 = items.firstWhere((m) => (m['q'] as String).contains('x = e^(-x)') && (m['q'] as String).contains('iteration 1'));
      expect(step1['q'], contains('x0 = 1'));
      expect(step1['answer'], '0.3679');
      expect(numberOk('0.567', root('e^(-x)')['answer']), isTrue);
      expect(step1['why'], contains('|g′(1)| = 0.368 < 1'));
    });

    test("Example 2 uses the module's two rewrites, and finds all three roots", () {
      expect(numberOk('0.347', root('(x^3 + 1) / 3')['answer']), isTrue);
      // This rewrite finds two roots (-1.8794 and 1.5321): the module's is 1.532.
      final cubeRoot = [
        for (final m in items)
          if ((m['q'] as String).contains('x = (3x − 1)^(1/3)') && (m['q'] as String).contains('find the root')) m['answer']
      ];
      expect(cubeRoot.any((a) => numberOk('1.532', a)), isTrue, reason: '$cubeRoot');
      final roots = [for (final m in items) if ((m['q'] as String).contains('x^3 − 3x + 1') && (m['q'] as String).contains('find the root')) m];
      expect(roots, hasLength(3), reason: 'roots near -1.88, 0.35 and 1.53');
    });

    test('the assignment needs x taken out: x = 20 / (x^2 + 2x + 10)', () {
      expect(numberOk('1.3688', root('20 / (x^2 + 2x + 10)')['answer']), isTrue);
    });

    test('every problem has its table and a solution that says when to stop', () {
      for (final m in items) {
        expect(m['why'], contains('x(k+1)'));
        expect(m['why'], contains(store.t('sys_stop')));
        expect(m['why'], contains(m['answer']));
      }
      expect(store.t('ss_step'), isNot(contains('{x}')));
    });

    test('a module that never teaches it gets none', () {
      expect(successiveItems('Example: f(x) = x^3 − 3x + 1 using the bisection method.'), isEmpty);
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
