import 'package:flutter_test/flutter_test.dart';
import 'package:gamy/rules.dart';
import 'package:gamy/store.dart';

import 'helpers.dart';

// Tests for Gamy's own quiz maker and module search (rules.dart). No files, no AI.
void main() {
  setUp(() => store.lang = 'en');

  group('reading the module', () {
    test('skips course details and contact info', () {
      final all = sentences(sample).join(' ');
      expect(all, isNot(contains('@')));
      expect(all, isNot(contains('Juan')));
      expect(all, isNot(contains('0917')));
    });

    test('finds every definition, and only those', () {
      final items = localItems(sample, 'id', 100);
      expect(items.map((m) => m['answer']).toSet(), facts.values.toSet());
    });

    test('never asks about contact info', () {
      for (final type in ['mc', 'tf', 'fill', 'id', 'mix']) {
        for (final m in localItems(sample, type, 100)) {
          expect('${m['q']} ${m['why']}', isNot(contains('@')), reason: type);
          expect('${m['q']} ${m['why']}', isNot(contains('Juan')), reason: type);
        }
      }
    });

    // From a real module (screenshot, Nov 18): headings, course labels, a schedule, an ownership notice,
    // a broken half-sentence, and lines cut with a trailing space. Only the 3 real definitions may come out.
    test('a messy real module: ignores headings, labels and notices, joins cut lines', () {
      const messy = 'BSCpE 3B\n'
          'Chapter 1\n'
          'Microprocessor Systems\n'
          'This is a property of PRESIDENT RAMON MAGSAYSAY STATE UNIVERSITY\n'
          'Time: 1:00-2:00PM\n'
          'Room: CpE Lab 2\n'
          'I/O Interfacing Introduction\n'
          "A microprocessor is great at solving problems, but if it can't communicate with the outside \n"
          'world it is of little worth.\n'
          'with external systems is crucial for engineering students.\n'
          'Latches are needed to hold the data because when the microprocessor executes an \n'
          'instruction, the data is only on the bus for a short time.\n'
          'Input devices are already TTL and compatible, and therefore can be \n'
          'connected directly to the bus.\n'
          'Chapter 4: Memory and storage of the system\n';
      final items = {for (final m in localItems(messy, 'match', 100)) m['term']: m['meaning']};
      expect(items, {
        'microprocessor': "Great at solving problems, but if it can't communicate with the outside world it is of little worth",
        'Latches': 'Needed to hold the data because when the microprocessor executes an instruction, '
            'the data is only on the bus for a short time',
        'Input devices': 'Already TTL and compatible, and therefore can be connected directly to the bus',
      });
    });

    // From a real module (Nov 21): a contact line, a teacher, headings, an instruction and a broken sentence
    // all became quiz terms or choices ("FB Account", "Direction", "Although there"...). Only the real one may.
    test('names, contact labels, headings and sentence starts never become terms', () {
      const junk = 'FB Account: Dionisio Martin Jr\n'
          'Prepared for: Ana P. Reyes\n'
          'Direction: Read the following questions carefully and answer them.\n'
          'Learning Module: Numerical methods for engineering students today\n'
          'Although there are many methods, this one converges very slowly.\n'
          'Adviser of the class: Juan Dela Cruz III\n'
          'Bisection method: a root-finding method that halves the interval each step.\n';
      final items = {for (final m in localItems(junk, 'match', 100)) m['term']: m['meaning']};
      expect(items.keys, ['Bisection method']);
    });

    test('a module with no definitions gives no_facts', () {
      expect(() => localItems('Hello there. We will have fun learning today, everyone.', 'mc', 5), throwsA('no_facts'));
    });

    test('gives at most the number of questions asked for', () {
      expect(localItems(sample, 'mc', 3), hasLength(3));
    });
  });

  group('pure Tagalog modules', () {
    const tagalog = 'Ang puso ay isang organ na nagbobomba ng dugo sa buong katawan.\n'
        'Ang baga ay ang bahagi ng katawan na tumutulong sa paghinga.\n'
        'Ang ibig sabihin ng fotosintesis ay ang paggawa ng pagkain ng halaman gamit ang liwanag ng araw.\n'
        'Ito ay napakahalaga sa ating buhay at kalusugan.\n'
        'Ang mga ugat ay tumutukoy sa mga daluyan ng dugo sa buong katawan.\n';

    test('finds "Ang X ay ..." definitions and skips "Ito ay ..."', () {
      final items = {for (final m in localItems(tagalog, 'match', 100)) m['term']: m['meaning']};
      expect(items, {
        'puso': 'Isang organ na nagbobomba ng dugo sa buong katawan',
        'baga': 'Ang bahagi ng katawan na tumutulong sa paghinga',
        'fotosintesis': 'Ang paggawa ng pagkain ng halaman gamit ang liwanag ng araw',
        'ugat': 'Mga daluyan ng dugo sa buong katawan',
      });
    });

    test('every quiz type works on a Tagalog module', () {
      store.lang = 'fil';
      for (final type in ['mc', 'tf', 'fill', 'id', 'mix']) {
        expect(localItems(tagalog, type, 10), hasLength(4), reason: type);
      }
    });
  });

  group('question types', () {
    test('multiple choice: 4 different choices, one right answer, wrong ones explained', () {
      for (final m in localItems(sample, 'mc', 100)) {
        final choices = (m['choices'] as List).cast<String>();
        expect(choices, hasLength(4));
        expect(choices.toSet(), hasLength(4), reason: 'no repeated choices');
        expect(choices, contains(m['answer']));
        expect((m['wrong'] as Map).keys.toSet(), choices.where((c) => c != m['answer']).toSet());
      }
    });

    test('multiple choice with fewer than 4 terms turns into identification', () {
      const two = 'A router is a device that sends data between networks.\n'
          'A switch is a device that connects computers inside one network.';
      for (final m in localItems(two, 'mc', 10)) {
        expect(m['type'], 'id');
      }
    });

    test('true or false: answer is True or False, and a False one says whose meaning it was', () {
      for (final m in localItems(sample, 'tf', 100)) {
        expect(['True', 'False'], contains(m['answer']));
        expect((m['wrong'] as Map).keys.single, m['answer'] == 'True' ? 'False' : 'True');
      }
    });

    test('true or false reads like a normal sentence, not "X means: ..."', () {
      for (final m in localItems(sample, 'tf', 100)) {
        expect(m['q'], isNot(contains('means:')), reason: m['q']);
        expect(m['q'], endsWith('.'));
        expect(m['q'], matches(RegExp(r' (is|are|refers to|means) ')), reason: m['q']);
      }
      const colon = 'Resistor: a part that opposes the flow of electric current.\n'
          'Watt: the measure of power used by electrical devices.\n'
          'Volt: the measure of electric potential difference between points.\n';
      for (final m in localItems(colon, 'tf', 10)) {
        expect(m['q'], matches(RegExp(r'^(Resistor|Watt|Volt) is [a-z]')), reason: m['q']);
      }
    });

    test('a mixed quiz is balanced: the 4 types take turns', () {
      final big = [
        for (final w in ['alpha', 'bravo', 'charlie', 'delta', 'echo', 'foxtrot', 'golf', 'hotel', 'india', 'juliet', 'kilo', 'lima'])
          'A $w gizmo is a part of the system that handles the $w work for the computer.'
      ].join('\n');
      for (var run = 0; run < 5; run++) {
        final types = [for (final m in localItems(big, 'mix', 12)) m['type']];
        for (final k in ['mc', 'tf', 'fill', 'id']) {
          expect(types.where((x) => x == k).length, 3, reason: '$k in $types');
        }
        // ...and grouped into parts like a printed exam: identification, true or false, multiple choice, fill in
        expect(types, [for (final k in mixOrder) ...List.filled(3, k)]);
      }
    });

    test('questions come from the whole module, not just its first pages', () {
      final lines = [
        for (var i = 0; i < 100; i++)
          'A ${String.fromCharCode(97 + i % 26)}${String.fromCharCode(97 + i ~/ 26)}x widget is a gadget that does job number ${'z' * (i % 7 + 1)} in the lab.'
      ];
      final where = {for (var i = 0; i < 100; i++) '${lines[i].split(' ')[1]} widget': i};
      final picked = [for (final m in localItems(lines.join('\n'), 'id', 10)) where[(m['answer'] as String)]!];
      expect(picked.any((i) => i >= 90), isTrue, reason: 'the last pages are used too: $picked');
      expect(picked.any((i) => i < 10), isTrue, reason: 'and the first: $picked');
    });

    test('fill in the blank: the term is blanked out of the sentence', () {
      for (final m in localItems(sample, 'fill', 100)) {
        expect(m['q'], contains('____'));
        expect((m['q'] as String).toLowerCase(), isNot(contains((m['answer'] as String).toLowerCase())));
      }
    });

    test('identification: the question shows the meaning, the answer is its term', () {
      for (final m in localItems(sample, 'id', 100)) {
        final meaning = meaningOf(m['q']);
        expect(m['q'], '$meaning.', reason: 'Nov 22: just the description, no "What is being described?"');
        expect(facts[meaning], m['answer']);
        expect(m['hint'], startsWith('Starts with "${(m['answer'] as String)[0].toUpperCase()}"'));
      }
    });

    test('matching: pairs each term with its meaning', () {
      final items = localItems(sample, 'match', 100);
      expect(items, hasLength(facts.length));
      for (final m in items) {
        expect(facts[m['meaning']], m['term']);
      }
    });

    test('mixed: only real question types', () {
      for (final m in localItems(sample, 'mix', 100)) {
        expect(['mc', 'tf', 'fill', 'id'], contains(m['type']));
      }
    });

    test('Filipino texts are used when the language is Filipino', () {
      store.lang = 'fil';
      expect(localItems(sample, 'id', 1).single['hint'], startsWith('Nagsisimula sa'));
    });
  });

  group('privacy and formatting filter', () {
    test('removes emails, links and phone numbers', () {
      final out = cleanPrivate('Email juan@school.edu, call 0917-123-4567 or +63 917 123 4567, '
          'landline (02) 8123-4567, see https://lms.example.com/course or www.example.com.');
      for (final bit in ['@', '0917', '+63', '8123', 'http', 'www']) {
        expect(out, isNot(contains(bit)), reason: bit);
      }
    });

    test('removes school names and teacher names', () {
      final out = cleanPrivate('This is a property of PRESIDENT RAMON MAGSAYSAY STATE UNIVERSITY.\n'
          'Prepared by: Engr. Juan Cruz\nInstructor: Ana Reyes\nBulacan State University College of Engineering');
      for (final bit in ['MAGSAYSAY', 'UNIVERSITY', 'Juan', 'Cruz', 'Ana Reyes', 'Bulacan', 'College']) {
        expect(out, isNot(contains(bit)), reason: bit);
      }
    });

    test('removes contact and teacher lines written any way (capitals, space before the colon)', () {
      final out = cleanPrivate('FB Account: Dionisio Martin Jr\nINSTRUCTOR : Dionisio Martin Jr.\n'
          'Course Facilitator: Ana P. Reyes\nMessenger: dmartin\nContact No.: 0917 123 4567\n'
          "Ohm's law: V = I x R\nThe teacher said that practice helps.");
      for (final bit in ['Dionisio', 'Reyes', 'dmartin', '0917']) {
        expect(out, isNot(contains(bit)), reason: bit);
      }
      expect(out, contains("Ohm's law: V = I x R"));
      expect(out, contains('The teacher said that practice helps.'), reason: 'ordinary sentences stay');
    });

    test('keeps the lesson: math, numbers and famous people', () {
      for (final line in [
        'V = I x R, so 12 V / 4 ohm = 3 A.',
        'The 8085 microprocessor has 40 pins and runs at 3 MHz.',
        'Sir Isaac Newton described gravity; Dr. Jose Rizal wrote Noli Me Tangere.',
        'x^2 + 5x + 6 = 0 has roots -2 and -3.',
      ]) {
        expect(cleanPrivate(line), line);
      }
    });

    test('PDF math letters, special hyphens and invisible spaces become normal text', () {
      expect(plainText('𝑓(𝑥) = 𝑥 3 − 𝑥 − 1, root 𝟏. 𝟑𝟐𝟒𝟔'), 'f(x) = x 3 − x − 1, root 1. 3246');
      expect(plainText('an in\u2011depth\u00A0look\u200B at ﬁles'), 'an in-depth look at files');
      expect(cleanReply('An in\u2011depth answer.'), 'An in-depth answer.', reason: 'Gamy\'s replies too (no box)');
    });

    test("Gamy's replies lose ** -- # and ` marks", () {
      expect(cleanReply('**Motherboard** -- the main board.'), 'Motherboard the main board.');
      expect(cleanReply('# Answer\nIt is `RAM`, __bro__.'), 'Answer\nIt is RAM, bro.');
    });

    test('quiz questions never show contact info, even from a messy module', () {
      for (final m in localItems(cleanPrivate(sample), 'mix', 100)) {
        expect('${m['q']} ${m['why']}', isNot(contains('@')));
      }
    });
  });

  group('smart search pieces', () {
    test('the module is cut into pieces of up to 3 sentences, with nothing lost or private', () {
      final pieces = chunks(sample);
      expect(pieces, isNotEmpty);
      expect(pieces.join(' '), sentences(sample).join(' '));
      for (final p in pieces) {
        expect(RegExp(r'(?<=[.!?])\s').allMatches(p).length, lessThanOrEqualTo(2), reason: p);
        expect(p, isNot(contains('@')));
      }
    });
  });

  group('chat search', () {
    final modules = [subject()['modules'][0] as Map];

    test('finds the sentence that answers the question', () {
      final reply = findAnswer('What is the motherboard?', modules);
      expect(reply, contains('main circuit board'));
      expect(reply, isNot(contains('Module 1')), reason: 'Chat no longer says which module it came from');
    });

    test('says so when the answer is not in the module', () {
      expect(findAnswer('photosynthesis chlorophyll', modules), store.t('r_not_found'));
    });

    test('asks for a real question when there is nothing to look for', () {
      expect(findAnswer('??', modules), store.t('r_ask_more'));
    });

    test('one shared word is not an answer (then Gamy looks it up on Wikipedia instead)', () {
      final q = 'How does a computer virus spread between computers?';
      expect(keywordsAnswer(q, bestLines(q, modules, 3)), isFalse);
      expect(keywordsAnswer('What is the motherboard?', bestLines('What is the motherboard?', modules, 3)), isTrue);
    });

    // Nov 22: "what is supervise learning" was answered from a line that only had "Learning" in it.
    test('a line sharing only one of two words is not the answer; word endings still match', () {
      final mods = [
        {'name': 'NM', 'text': 'This Learning Module covers the false position method in detail.'},
        {'name': 'ML', 'text': 'In supervised learning, the model learns from labeled examples.'},
      ];
      expect(keywordsAnswer('what is supervise learning', bestLines('what is supervise learning', [mods[0]], 3)), isFalse);
      expect(keywordsAnswer('what is supervise learning', bestLines('what is supervise learning', mods, 3)), isTrue,
          reason: '"supervise" finds "supervised", "learning" finds "learns"');
    });

    test('bestLines puts the closest match first and keeps to n lines', () {
      final lines = bestLines('cache memory processor', modules, 2)!;
      expect(lines, hasLength(2));
      expect(lines.first.text, startsWith('Cache memory'));
    });
  });

  // Nov 23: a big algebra book gave the question "...left to Problems 32–36 at the end of the chapter".
  test('lines that only point to other parts of the book never become questions', () {
    const text = 'The details are left to Problems 32–36 at the end of the chapter.\n'
        'The proof is shown in Figure 4 on the next page.\n'
        'The kernel is the set of elements that a homomorphism sends to the identity.\n';
    final items = localItems(text, 'id', 10);
    expect(items, hasLength(1));
    expect(items.single['answer'], 'kernel');
  });

  // Nov 23: chat showed "$ p^a q^b $"; math now reads like math, with real exponents.
  group('math that reads well', () {
    test(r'no $ signs or LaTeX words, and real exponents', () {
      expect(cleanReply(r'order $ p^a q^b $ (where $ p, q $ are prime and $ a + b > 1 $)'),
          'order pᵃ qᵇ (where p, q are prime and a + b > 1)');
      expect(mathText(r'\(x^2 + y^{n+1} = \frac{1}{2}\) and a \cdot b \leq c'), 'x² + yⁿ⁺¹ = (1)/(2) and a · b ≤ c');
      expect(mathText('x_1 + x_2 = 5, but file_2 stays'), 'x₁ + x₂ = 5, but file_2 stays');
    });

    // Nov 23: a long reply still showed "$$ \begin{bmatrix} ... $$", "\cdots", "\phi" and a lone "$".
    test(r'matrices, Greek letters and a "$" left alone are cleaned too', () {
      expect(mathText('like:\n\$\$\n\\begin{bmatrix}\na_{11} & a_{12} \\\\\na_{21} & a_{22}\n\\end{bmatrix}\n\$\$\nok'),
          'like:\n[a₁₁ a₁₂]\n[a₂₁ a₂₂]\nok');
      expect(mathText(r'a^1 y_1 + \cdots + a^n y_n = \phi(x), then $ \phi(2) = 3^1 +'),
          'a¹ y₁ + ⋯ + aⁿ yₙ = φ(x), then φ(2) = 3¹ +');
      expect(mathText(r"print('a\nb') costs $5"), r"print('a\nb') costs $5");
    });

    test('money and things without a small version are left alone', () {
      expect(mathText(r'It costs $5 and $10.'), r'It costs $5 and $10.');
      expect(powers('x^2.5 and p^q'), 'x^2.5 and p^q', reason: 'no small "." or "q": shown as typed, never wrong');
      expect(powers('e^(-x) and 2^10'), 'e⁻ˣ and 2¹⁰');
    });
  });
}
