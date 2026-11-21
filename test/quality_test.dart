import 'package:flutter_test/flutter_test.dart';
import 'package:gamy/rules.dart';
import 'package:gamy/solve.dart';
import 'package:gamy/store.dart';

// Quiz-quality set: excerpts of real modules (Nov 2026), exactly as the PDF reader saves them, run through
// every quiz type. Real names, emails, numbers and the school are swapped for made-up ones in the same format.
// If a change to rules.dart lets junk through again, this test says which module and quiz type.

const _microprocessor = '''CpE 323 –
Microprocessor Systems
This is a property of
SUNRISE VALLEY STATE UNIVERSITY
NOT FOR SALE
Copyright. Republic Act 8293 Section 176 provides that “No copyright shall subsist in any work of
the Government of the Philippines.
Borrowed materials included in this module are owned by their respective copyright holders.
Learning Module Development Team
Chapter Title Author
Chapter 1: Structural Components of
Microprocessor/Microcontroller
Juana P. Santos Jr.
Evaluators:
Dr. Pedro Lim Reyes, Program Chair
Engr. Mario Cruz, Dean
• Schedule: BSCpE 3A – Tuesday and Thursday, 12:30 PM - 3:30 PM
• Name of Faculty: Juana P. Santos Jr.
• Contact Details
Email: jpsantosjr@svsu.edu.ph
Mobile Number: 0917-555-0123
FB Account: Juana Santos Jr.
• Consultation
Day: MWF
Time: 1:00-2:00PM
Direction: Read the following questions carefully and answer them.
Learning Module: Microprocessor Systems for engineering students today
A microprocessor is a programmable chip that fetches, decodes and executes instructions.
The basic input device is a set of three-state buffers.
A latch is a circuit that holds the data while the microprocessor reads it from the bus.
An output port is the part that moves data out of the microprocessor to the I/O device.
The data bus is the set of lines that carries data between the microprocessor and memory.
Although there are many devices, most switch-based devices are either open or connected.
''';

const _numerical = '''CpE 221 – Numerical
Methods
This is a property of
SUNRISE VALLEY STATE UNIVERSITY
NOT FOR SALE
Chapter 1: Introduction to Numerical Methods
Juana P. Santos Jr. Chapter 2: Root Finding
Evaluators:
(First Name, Middle Initial, Last Name), Position
• Name of Faculty: Juana P. Santos Jr.
• Contact Details
Email: jpsantosjr@svsu.edu.ph
Mobile Number: 0917-555-0123
FB Account: Juana Santos Jr.
Numerical methods are techniques to approximate mathematical procedures such as integrals.
The bisection method is a root-finding method that halves the interval at every step.
The false position method is a root-finding method that joins two points with a straight line.
Regula falsi refers to the Latin name of the method of false position.
A root of an equation is a value of the variable that makes the function equal to zero.
Example 1.) Find a root of an equation 𝑓(𝑥) = 𝑥
3 − 𝑥 − 1 using False Position method
using 𝑑
𝑘 ≤ 0.0001 to stop iterations.
Example 2.) Find a root of an equation 𝑓(𝑥) = 𝑒
𝑥 − 4√𝑥 using False Position method using
''';

// Nothing personal, no school, no course paperwork may ever show up in a question, a choice or an answer.
const _banned = [
  'Santos', 'Juana', 'Reyes', 'Cruz', '@', '0917', 'Faculty', 'FB Account', 'UNIVERSITY', 'Evaluators',
  'Program Chair', 'NOT FOR SALE', 'Republic Act', 'Copyright', 'Consultation', 'BSCpE',
];

String _all(Map m) => [m['q'], m['answer'], m['why'], m['term'], m['meaning'], ...(m['choices'] as List? ?? [])]
    .whereType<String>()
    .join(' | ');

void main() {
  setUp(() => store.lang = 'en');

  for (final (name, module) in [('Microprocessor', _microprocessor), ('Numerical Methods', _numerical)]) {
    group(name, () {
      final text = cleanPrivate(module); // what Gamy keeps after an upload

      for (final type in ['mc', 'tf', 'fill', 'id', 'match', 'mix']) {
        test('$type: no names, contacts, school or paperwork; no repeats; real terms only', () {
          final items = localItems(text, type, 100);
          expect(items, isNotEmpty);
          for (final m in items) {
            final all = _all(m);
            for (final bad in _banned) {
              expect(all, isNot(contains(bad)), reason: '$type: "$bad" in: $all');
            }
            final term = '${m['term'] ?? m['answer']}';
            expect(term, isNot(matches(RegExp(r'^(Direction|Learning Module|Although|Chapter)', caseSensitive: false))),
                reason: '$type: "$term" is not a term');
            if (m['choices'] != null && m['type'] == 'mc') {
              final choices = (m['choices'] as List).toSet();
              expect(choices, hasLength(4), reason: 'four different choices');
              expect(choices, contains(m['answer']));
            }
          }
          final questions = [for (final m in items) m['q'] ?? m['term']];
          expect(questions.toSet(), hasLength(questions.length), reason: '$type: a question is repeated');
        });
      }
    });
  }

  test('Numerical Methods: problem solving uses only the module\'s own methods and functions', () {
    final items = solveItems(cleanPrivate(_numerical), 100);
    expect(items, isNotEmpty);
    for (final m in items) {
      expect(m['q'], anyOf(contains('false position method'), contains('bisection method')), reason: m['q']);
      expect(m['q'], anyOf(contains('f(x) = x^3 − x − 1'), contains('f(x) = e^x − 4√x')), reason: m['q']);
      expect(m['why'], contains('f(x-)'), reason: 'every problem has its step table');
    }
  });

  test('Microprocessor: no formulas or methods, so problem solving says so instead of inventing', () {
    expect(() => solveItems(cleanPrivate(_microprocessor), 10), throwsA('no_formulas'));
  });
}
