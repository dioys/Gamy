import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamy/brain.dart';
import 'package:gamy/chat.dart';
import 'package:gamy/main.dart';
import 'package:gamy/quiz.dart';
import 'package:gamy/rules.dart';
import 'package:gamy/settings.dart';
import 'package:gamy/setup.dart';
import 'package:gamy/store.dart';
import 'package:gamy/strings.dart';
import 'package:gamy/terms.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'helpers.dart';

// Tests that tap through Gamy's screens like a student would.
// Every test starts with an empty Gamy saved in a temporary folder.
void main() {
  late Directory dir;
  setUp(() async {
    dir = await freshStore();
    await brain.start(); // no model in the temp folder, so the brain stays off
  });
  tearDown(() async {
    store.close(); // Windows can't delete a database file that is still open
    await dir.delete(recursive: true);
  });

  final t = store.t;

  // A tall test screen, so every quiz card is built at once.
  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 8000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  // Ends a test cleanly: removes the screens so their timers (naps, animations) stop.
  Future<void> close(WidgetTester tester) => tester.pumpWidget(const SizedBox());

  // Opens the Quiz tab with one module, picks it and the quiz type, and starts the quiz.
  Future<void> startQuiz(WidgetTester tester, String type) async {
    tallScreen(tester);
    store.subjects = [subject()];
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Quiz())));
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CSS').last); // the subject (folder)
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Module 1')); // then its module
    await tester.pumpAndSettle();
    await tester.tap(find.text(t(type)));
    await tester.pump();
    await tester.tap(find.text(t('start')));
    await tester.pumpAndSettle();
  }

  group('strings', () {
    test('English and Filipino have the same texts and the same {placeholders}', () {
      final en = strings['en']!, fil = strings['fil']!;
      expect(fil.keys.toSet(), en.keys.toSet());
      final holes = RegExp(r'\{\w+\}');
      for (final k in en.keys) {
        expect(holes.allMatches(fil[k]!).map((m) => m[0]).toSet(), holes.allMatches(en[k]!).map((m) => m[0]).toSet(),
            reason: k);
      }
    });

    test("every t('...') in the code has a text", () {
      for (final f in Directory('lib').listSync().whereType<File>()) {
        for (final m in RegExp(r"\bt\('(\w+)'\)").allMatches(f.readAsStringSync())) {
          expect(strings['en']!.containsKey(m[1]), isTrue, reason: '${f.path}: ${m[1]}');
        }
      }
    });
  });

  group("Gamy's humor", () {
    test('50 roasts per language: 17 high, 16 middle, 17 low, none repeated', () {
      for (final lang in ['en', 'fil']) {
        expect(roasts[lang]!.map((band) => band.length), [17, 16, 17], reason: lang);
        final all = roasts[lang]!.expand((band) => band).toList();
        expect(all.toSet(), hasLength(50), reason: '$lang: no repeats');
        expect(all.every((l) => l.trim().isNotEmpty), isTrue, reason: lang);
      }
      expect(roasts['en']![0], contains('Got lucky, huh?'));
      expect(roasts['en']![2], contains('Okay... that was dumb.'));
      expect(roasts['fil']![0], contains('Tsamba lang yan, boi.'));
    });

    test('the brain is told to use Taglish slang in Filipino, and English slang in English', () {
      expect(gamyIs(), contains('"bro"'));
      store.lang = 'fil';
      expect(gamyIs(), contains('Taglish'));
      expect(gamyIs(), contains('"boi"'));
    });

    test('the roast is about the answer, never the person', () {
      expect(gamyIs(), contains('Roast the answer, not the person'));
    });
  });

  group('saving (SQLite)', () {
    test('subjects, modules, scores and settings survive a restart', () async {
      store.agree();
      store.setLang();
      store.addSubject('Math');
      store.subjects.first['modules'].add({'name': 'm1', 'text': 'x'}); // in memory only: not saved
      store.addScore(store.subjects.first, {'module': 'm1', 'type': 'mc', 'right': 1, 'total': 2, 'date': '2026-11-18'});
      final again = Store();
      await again.load();
      expect(again.agreed, isTrue);
      expect(again.lang, 'fil');
      expect(again.subjects.single['name'], 'Math');
      expect(again.subjects.single['modules'], isEmpty, reason: 'only addModule saves modules');
      expect(again.subjects.single['scores'].single,
          {'module': 'm1', 'type': 'mc', 'right': 1, 'total': 2, 'date': '2026-11-18'});
      again.close();
    });

    test('deleting a subject also deletes its scores; "Delete all my data" empties everything', () async {
      store.addSubject('Math');
      store.addSubject('Science');
      store.addScore(store.subjects.first, {'module': 'm', 'type': 'id', 'right': 3, 'total': 3, 'date': '2026-11-18'});
      store.remove(store.subjects, store.subjects.first);
      final again = Store();
      await again.load();
      expect(again.subjects.single['name'], 'Science');
      expect(again.subjects.single['scores'], isEmpty);

      store.agree();
      store.reset();
      await again.load();
      expect(again.subjects, isEmpty);
      expect(again.agreed, isFalse, reason: 'asks for the terms again');
      again.close();
    });

    test('an old gamy.json save is moved into the database once, then deleted', () async {
      final old = await Directory.systemTemp.createTemp('gamy_old');
      File('${old.path}/gamy.json').writeAsStringSync(jsonEncode({
        'lang': 'fil',
        'agreedTo': termsVersion,
        'dark': true,
        'uploads': 2,
        'subjects': [
          {
            'name': 'CSS',
            'modules': [
              {'name': 'Module 1', 'text': sample}
            ],
            'scores': [
              {'module': 'Module 1', 'type': 'mc', 'right': 5, 'total': 7, 'date': '2026-11-17'}
            ],
          }
        ],
      }));
      PathProviderPlatform.instance = FakePath(old.path);
      final s = Store();
      await s.load();
      expect(s.lang, 'fil');
      expect(s.dark, isTrue);
      expect(s.agreed, isTrue);
      expect(s.uploads, 2);
      expect(s.subjects.single['modules'].single['text'], cleanPrivate(sample));
      expect(s.subjects.single['modules'].single['text'], isNot(contains('@')), reason: 'old saves get filtered too');
      expect(s.subjects.single['scores'].single['right'], 5);
      expect(File('${old.path}/gamy.json').existsSync(), isFalse, reason: 'the old file is gone');
      await s.load(); // loading again must not copy it twice
      expect(s.subjects, hasLength(1));
      s.close();
      await old.delete(recursive: true);
    });

    test('a damaged old save file starts fresh instead of crashing', () async {
      final old = await Directory.systemTemp.createTemp('gamy_old');
      File('${old.path}/gamy.json').writeAsStringSync('{not json');
      PathProviderPlatform.instance = FakePath(old.path);
      final s = Store();
      await s.load();
      expect(s.subjects, isEmpty);
      s.close();
      await old.delete(recursive: true);
    });

    test('meaning vectors are stored as bytes and compared by closeness', () {
      final v = [0.6, 0.8, 0.0];
      expect(closeness(v, vectorBytes(v)), closeTo(1, 1e-6), reason: 'same meaning');
      expect(closeness([0.0, 0.0, 1.0], vectorBytes(v)), closeTo(0, 1e-6), reason: 'unrelated');
      expect(vectorBytes(List.filled(768, 0.1)), hasLength(768 * 4), reason: '3 KB per piece');
    });

    test('free plan limits (for when billing is turned on)', () {
      store.pro = false;
      expect(store.itemsLeft, 70);
      store.useItems(30);
      expect(store.itemsLeft, 40);
      store.uploads = 3;
      expect(store.canUpload, isFalse);
      store.pro = true;
      expect(store.itemsLeft, 100);
      expect(store.canUpload, isTrue);
    });
  });

  group('first launch', () {
    testWidgets('full-screen terms, agree (18+ in the same checkbox), then sign in or skip', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Setup()));
      expect(find.text(termsText), findsOneWidget);
      final go = find.text(t('continue'));
      await tester.tap(go);
      await tester.pumpAndSettle();
      expect(find.text(t('keep_safe')), findsNothing, reason: 'nothing happens before ticking the box');

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(go);
      await tester.pumpAndSettle();
      // The sign-in recommendation, with its reasons and "Skip for now".
      expect(find.text(t('keep_safe')), findsOneWidget);
      expect(find.text(t('why_1')), findsOneWidget);
      expect(store.agreed, isFalse);
      await tester.ensureVisible(find.text(t('skip')));
      await tester.tap(find.text(t('skip')));
      await tester.pumpAndSettle();
      // Then Gamy's brain: what it does and its size, with "Download now" or "Skip for now".
      expect(find.text(t('brain_step')), findsOneWidget);
      expect(find.text(t('brain_now')), findsOneWidget);
      expect(store.agreed, isFalse);
      await tester.ensureVisible(find.text(t('skip')));
      await tester.tap(find.text(t('skip')));
      expect(store.agreed, isTrue);
    });

    testWidgets('the language button switches to Filipino', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Setup()));
      await tester.tap(find.text('Filipino'));
      await tester.pumpAndSettle();
      expect(store.lang, 'fil');
      expect(find.text(strings['fil']!['agree']!), findsOneWidget);
    });
  });

  group('quiz', () {
    testWidgets('identification: right answers count even with other capitals and a period', (tester) async {
      await startQuiz(tester, 'id');
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(facts.length));
      for (var i = 0; i < facts.length; i++) {
        final q = tester.widget<Text>(find.textContaining(RegExp('^${i + 1}\\. '))).data!;
        final meaning = meaningOf(q);
        await tester.enterText(fields.at(i), '${facts[meaning]!.toUpperCase()}.');
      }
      await tester.tap(find.text(t('submit')));
      await tester.pump();
      expect(find.text('${t('score')}: ${facts.length} / ${facts.length}'), findsOneWidget);
      expect(store.subjects.single['scores'], hasLength(1), reason: 'the score is saved');
      expect(roasts['en']![0].where((l) => find.text(l).evaluate().isNotEmpty), hasLength(1),
          reason: 'a perfect score gets a perfect-score roast ("Got lucky, huh?" and friends)');
      await close(tester);
    });

    testWidgets('3 of 7 right (43%, like 4/10) gets a low-score roast', (tester) async {
      await startQuiz(tester, 'id');
      final fields = find.byType(TextField);
      for (var i = 0; i < facts.length; i++) {
        final q = tester.widget<Text>(find.textContaining(RegExp('^${i + 1}\\. '))).data!;
        // 3 right, the rest wrong (every question must be answered before checking)
        await tester.enterText(fields.at(i), i < 3 ? facts[meaningOf(q)]! : 'no idea');
      }
      await tester.tap(find.text(t('submit')));
      await tester.pump();
      expect(find.text('${t('score')}: 3 / ${facts.length}'), findsOneWidget);
      expect(roasts['en']![2].where((l) => find.text(l).evaluate().isNotEmpty), hasLength(1));
      await close(tester);
    });

    testWidgets('multiple choice: 4 choices each; blanks are not checked; all wrong scores 0 and review shows the right ones',
        (tester) async {
      await startQuiz(tester, 'mc');
      expect(find.byType(ChoiceChip), findsNWidgets(facts.length * 4));
      // Blank answers: Gamy says which ones, and doesn't check yet.
      await tester.tap(find.text(t('submit')));
      await tester.pumpAndSettle();
      expect(find.text(t('answer_all').replaceFirst('{n}', List.generate(facts.length, (i) => i + 1).join(', '))),
          findsOneWidget);
      expect(find.textContaining('${t('score')}: '), findsNothing);
      // Now pick a wrong choice in every question.
      for (var i = 0; i < facts.length; i++) {
        final q = tester.widget<Text>(find.textContaining(RegExp('^${i + 1}\\. '))).data!;
        final right = facts[meaningOf(q)];
        final chips = find.descendant(of: find.byType(Card).at(i), matching: find.byType(ChoiceChip));
        for (var c = 0; c < 4; c++) {
          final label = tester.widget<Text>(find.descendant(of: chips.at(c), matching: find.byType(Text))).data;
          if (label != right) {
            await tester.tap(chips.at(c));
            await tester.pump();
            break;
          }
        }
      }
      await tester.tap(find.text(t('submit')));
      await tester.pump();
      expect(find.text('${t('score')}: 0 / ${facts.length}'), findsOneWidget);
      expect(roasts['en']![2].where((l) => find.text(l).evaluate().isNotEmpty), hasLength(1),
          reason: 'a score below 50% gets a low-score roast');
      await tester.tap(find.text(t('review')));
      await tester.pump();
      expect(find.textContaining('${t('correct')}: '), findsNWidgets(facts.length));
      await close(tester);
    });

    testWidgets('true or false: 2 choices each, and the score adds up', (tester) async {
      await startQuiz(tester, 'tf');
      expect(find.byType(ChoiceChip), findsNWidgets(facts.length * 2));
      for (var i = 0; i < facts.length; i++) {
        await tester.tap(find.text(t('true')).at(i)); // answer True to everything
        await tester.pump();
      }
      await tester.tap(find.text(t('submit')));
      await tester.pump();
      expect(find.textContaining(RegExp('^${t('score')}: \\d / ${facts.length}\$')), findsOneWidget);
      await close(tester);
    });

    testWidgets('fill in the blank: every question has a blank', (tester) async {
      await startQuiz(tester, 'fill');
      expect(find.textContaining('____'), findsNWidgets(facts.length));
      await close(tester);
    });

    testWidgets('matching: one dropdown of meanings per term', (tester) async {
      await startQuiz(tester, 'match');
      expect(find.byType(DropdownButton<String>), findsNWidgets(facts.length));
      await close(tester);
    });

    testWidgets('mixed: makes a full quiz', (tester) async {
      await startQuiz(tester, 'mix');
      expect(find.textContaining(RegExp(r'^\d+\. ')), findsNWidgets(facts.length));
      await close(tester);
    });

    testWidgets('a module with no definitions shows a message instead of crashing', (tester) async {
      tallScreen(tester);
      store.subjects = [
        {
          'name': 'CSS',
          'modules': [
            {'name': 'Notes', 'text': 'We will have fun learning today, everyone.'}
          ],
          'scores': []
        }
      ];
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Quiz())));
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CSS').last); // the subject (folder)
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Notes')); // then its module
      await tester.pumpAndSettle();
      await tester.tap(find.text(t('start')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500)); // let the message slide in
      expect(find.text(t('no_facts')), findsOneWidget);
      await close(tester);
    });
  });

  group('quiz picker', () {
    Future<void> openQuiz(WidgetTester tester, List<Map<String, dynamic>> modules) async {
      tester.view.physicalSize = const Size(1000, 8000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      store.subjects = [
        {'name': 'CSS', 'modules': modules, 'scores': []},
        {'name': 'Math', 'modules': [], 'scores': []}, // empty folders aren't listed
      ];
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Quiz())));
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      expect(find.text('Math'), findsNothing, reason: 'a subject without modules is not listed');
      await tester.tap(find.text('CSS').last);
      await tester.pumpAndSettle();
    }

    testWidgets('pick 2 modules: the quiz uses both', (tester) async {
      await openQuiz(tester, [
        {'name': 'Module 1', 'text': sample},
        {
          'name': 'Module 2',
          'text': 'A router is a device that sends data between networks.\n'
              'A switch is a device that connects computers inside one network.'
        },
      ]);
      final start = find.widgetWithText(FilledButton, t('start'));
      expect(tester.widget<FilledButton>(start).onPressed, isNull, reason: 'nothing picked yet');
      await tester.tap(find.widgetWithText(FilterChip, 'Module 1'));
      await tester.tap(find.widgetWithText(FilterChip, 'Module 2'));
      await tester.pump();
      await tester.tap(find.text(t('id')));
      await tester.pump();
      await tester.tap(start);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(facts.length + 2), reason: '7 terms + router + switch');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('long modules are never blocked: the quiz still starts', (tester) async {
      await openQuiz(tester, [
        {'name': 'Huge', 'text': '$sample\n${'Extra filler line without a definition here.\n' * 6000}'},
      ]);
      await tester.tap(find.widgetWithText(FilterChip, 'Huge'));
      await tester.pump();
      final start = find.widgetWithText(FilledButton, t('start'));
      expect(tester.widget<FilledButton>(start).onPressed, isNotNull, reason: 'never blocked');
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pumpAndSettle();
      expect(find.textContaining(RegExp(r'^\d+\. ')), findsWidgets, reason: 'the quiz was made');
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('chat (brain off)', () {
    testWidgets('quotes the module line that answers the question', (tester) async {
      store.subjects = [subject()];
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Chat())));
      await tester.enterText(find.byType(TextField), 'What is the motherboard?');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      expect(find.textContaining('main circuit board'), findsWidgets);
      // Nov 22: without the brain he says how to get it (where to tap), once per chat.
      expect(find.textContaining(t('chat_needs_brain')), findsOneWidget);
      // Nov 23: his reply can be reported (Google Play rule for AI-made content).
      expect(find.byTooltip(t('report')), findsOneWidget);

      // Not in any module, and tests have no internet: Gamy says it's not there and he can't look it up.
      await tester.enterText(find.byType(TextField), 'photosynthesis chlorophyll');
      await tester.tap(find.byIcon(Icons.send));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100)); // the (failed) Wikipedia lookup
      }
      expect(find.textContaining(t('not_found_offline')), findsWidgets);
      expect(find.textContaining(t('chat_needs_brain')), findsOneWidget, reason: 'said once, not after every reply');

      await tester.pump(const Duration(seconds: 16)); // let Gamy finish "talking"
      await close(tester);
    });
  });

  group('whole app', () {
    testWidgets('no DEBUG banner', (tester) async {
      store.agree();
      await tester.pumpWidget(const GamyApp());
      expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).debugShowCheckedModeBanner, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('tabs and Settings open without errors', (tester) async {
      store.agree();
      await tester.pumpWidget(const GamyApp());
      await tester.pump();
      expect(find.text(t('hello')), findsWidgets); // his greeting

      await tester.tap(find.text(t('quiz')));
      await tester.pump();
      expect(find.text(t('need_module')), findsOneWidget);

      await tester.tap(find.text(t('upload')));
      await tester.pump();
      expect(find.text(t('no_subjects')), findsOneWidget);

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      expect(find.byType(Settings), findsOneWidget);
      // Short statuses in the rows; the details (and the Download button) open when a row is tapped.
      expect(find.text(t('status_off')), findsNWidgets(2), reason: 'brain and smart search not downloaded yet');
      expect(find.text(t('brain_note')), findsNothing);
      await tester.tap(find.text(t('search_title')));
      await tester.pumpAndSettle();
      expect(find.text(t('search_note')), findsOneWidget);
      expect(find.text(t('brain_get')), findsOneWidget);
      await close(tester);
    });
  });
}
