import 'package:flutter_test/flutter_test.dart';
import 'package:gamy/algebra.dart';
import 'package:gamy/solve.dart';

// Algebra packs (Nov 24): every made problem is checked by putting its answer back into the problem.
double _at(String side, Map<String, double> values) => readExpression(side)!.calc(values);

void main() {
  group('answers students type', () {
    test('fractions, expressions in any correct form, and (x, y) pairs', () {
      expect(numberOf('−7/2'), -3.5);
      expect(numberOk('3/4', '0.75'), isTrue);
      expect(numberOk('12 V', '12'), isTrue, reason: 'units still fine');
      expect(exprOk('(x+3)(x+2)', 'x^2 + 5x + 6'), isTrue);
      expect(exprOk('y = 2/3x - 1', 'y = (2/3)x − 1'), isTrue);
      expect(exprOk('y = 2x - 1', 'y = (2/3)x − 1'), isFalse);
      expect(exprOk('hello', 'y = x'), isFalse);
      expect(pairOk('x = 2, y = -3', '(2, −3)'), isTrue);
      expect(pairOk('(-3, 2)', '(2, −3)'), isFalse);
      expect(pairOk('(1/2, 4)', '(0.5, 4)'), isTrue);
    });
  });

  group('topics', () {
    test('an algebra book gets its topics; a numerical methods module keeps its own problems', () {
      final book = List.filled(20, 'Solve each linear equation. Find the slope. Solve the system of equations.').join('\n');
      expect(topicsIn(book), ['linear', 'slope', 'systems']);
      final numerical = '${List.filled(20, 'The Jacobi method solves a system of linear equations.').join('\n')}\n'
          '${List.filled(20, 'Find the slope.').join('\n')}';
      expect(topicsIn(numerical), isEmpty);
    });

    test('a 15-question quiz over three topics: 5 each, grouped topic by topic', () {
      final items = algebraItems(['linear', 'slope', 'systems'], 2, 15);
      expect(items, hasLength(15));
      final parts = items.map((m) => m['part']).toList();
      expect(parts.toSet(), hasLength(3));
      for (var i = 1; i < parts.length; i++) {
        if (parts[i] != parts[i - 1]) expect(parts.sublist(i).contains(parts[i - 1]), isFalse, reason: 'in parts');
      }
    });
  });

  for (final level in [1, 2, 3]) {
    group('level $level', () {
      test('linear equations: the answer makes both sides equal', () {
        for (final m in algebraItems(['linear'], level, 30)) {
          final eq = (m['q'] as String).split(': ').last.split(' = '), x = numberOf(m['answer'])!;
          expect(_at(eq[0], {'x': x}), closeTo(_at(eq[1], {'x': x}), 1e-9), reason: '${m['q']} -> ${m['answer']}');
          expect(m['why'], contains(m['answer'].replaceFirst('-', '−')));
        }
      });

      test('slope and lines: the answer goes through the points', () {
        for (final m in algebraItems(['slope'], level, 30)) {
          final pts = [
            for (final p in RegExp(r'\((−?\d+), (−?\d+)\)').allMatches(m['q'] as String))
              [numberOf(p[1]!)!, numberOf(p[2]!)!]
          ];
          final g = m['graph'] as List?;
          if (g != null) pts.addAll([[g[0] * 1.0, g[1] * 1.0], [g[2] * 1.0, g[3] * 1.0]]);
          if (level == 1) {
            expect(numberOf(m['answer'])!, closeTo((pts[1][1] - pts[0][1]) / (pts[1][0] - pts[0][0]), 1e-9));
          } else {
            expect(m['check'], 'expr');
            final line = (m['answer'] as String).replaceFirst('y = ', '');
            for (final p in pts) {
              expect(_at(line, {'x': p[0]}), closeTo(p[1], 1e-9), reason: '${m['answer']} through $p');
            }
          }
        }
      });

      test('systems: the answer fits every equation', () {
        for (final m in algebraItems(['systems'], level, 30)) {
          final values = RegExp(r'−?\d+').allMatches(m['answer'] as String).map((v) => numberOf(v[0]!)!).toList();
          final names = {'x': values[0], 'y': values[1], if (values.length == 3) 'z': values[2]};
          final rows = (m['q'] as String).split('\n').skip(1);
          expect(rows, hasLength(level == 3 ? 3 : 2));
          for (final row in rows) {
            final eq = row.trim().split(' = ');
            expect(_at(eq[0], names), closeTo(numberOf(eq[1])!, 1e-9), reason: '$row with ${m['answer']}');
          }
        }
      });
    });
  }

  test('hard slope problems: different lines, even though the words are the same (Nov 24)', () {
    final items = algebraItems(['slope'], 3, 10);
    expect(items, hasLength(10));
    expect(items.map((m) => '${m['graph']}').toSet(), hasLength(10));
  });

  test('hard linear equations really use fractions, and the steps clear them', () {
    final items = algebraItems(['linear'], 3, 20);
    expect(items.every((m) => (m['q'] as String).contains('/')), isTrue);
    expect(items.every((m) => (m['why'] as String).contains('Least common denominator')), isTrue);
  });
}
