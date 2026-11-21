import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamy/quiz.dart';
import 'package:gamy/store.dart';

import 'helpers.dart';

// Quiz screen checks from the Nov 21 review: the number of questions, the "answer everything first" notice,
// and the score always showing after checking.

// 12 network terms, so a 10-question quiz has enough to choose from.
const _twelve = '''
A router is a device that sends data packets between two different networks.
A switch is a device that connects many computers inside one local network.
A modem is a device that turns phone line signals into internet data.
A firewall is a guard that blocks unwanted traffic coming from the internet.
A server is a computer that shares files and services with other computers.
A client is a computer that asks a server for files and services.
A gateway is a node that links a local network to an outside network.
A repeater is a device that boosts a weak signal so it travels farther.
A bridge is a device that joins two small network segments into one.
A hub is a simple box that copies every incoming signal to all of its ports.
A cable tester is a tool that checks whether a network cable works properly.
A load balancer is a system that spreads incoming requests across several servers.
''';

void main() {
  late Directory dir;
  setUp(() async => dir = await freshStore());
  tearDown(() async {
    store.close();
    await dir.delete(recursive: true);
  });

  final t = store.t;
  Finder questions() => find.textContaining(RegExp(r'^\d+\. '));

  // Opens the Quiz tab with one module and starts a quiz of [type] with the default 10 questions.
  Future<void> start(WidgetTester tester, String text, {String type = 'mc'}) async {
    tester.view.physicalSize = const Size(1000, 8000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    store.subjects = [
      {
        'name': 'Networks',
        'modules': [
          {'name': 'Module 1', 'text': text}
        ],
        'scores': [],
      }
    ];
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Quiz())));
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Networks').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Module 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t(type)));
    await tester.pump();
    await tester.tap(find.text(t('start')));
    await tester.pumpAndSettle();
  }

  testWidgets('asking for 10 multiple choice questions gives exactly 10', (tester) async {
    await start(tester, _twelve);
    expect(questions(), findsNWidgets(10));
    expect(find.textContaining(t('fewer').split('{n}').last), findsNothing, reason: 'no "only found" notice');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('every quiz type gives exactly 10 when the module has enough', (tester) async {
    for (final type in ['tf', 'fill', 'id', 'mix']) {
      await start(tester, _twelve, type: type);
      expect(questions(), findsNWidgets(10), reason: type);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('fewer good questions than asked: Gamy says how many he found', (tester) async {
    await start(tester, _twelve.split('\n').take(5).join('\n'));
    expect(questions(), findsNWidgets(5));
    expect(find.text(t('fewer').replaceFirst('{n}', '5')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('multiple choice with only 3 terms still shows its 3 questions (as identification)', (tester) async {
    await start(tester, _twelve.split('\n').take(3).join('\n'));
    expect(questions(), findsNWidgets(3));
    expect(find.byType(TextField), findsNWidgets(3));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('blank answers: Gamy lists them and waits; answering the rest shows the score', (tester) async {
    await start(tester, _twelve, type: 'id');
    final fields = find.byType(TextField);
    for (var i = 0; i < 10; i++) {
      if (i != 2 && i != 6) await tester.enterText(fields.at(i), 'router');
    }
    await tester.tap(find.text(t('submit')));
    await tester.pumpAndSettle();
    expect(find.text(t('answer_all').replaceFirst('{n}', '3, 7')), findsOneWidget);
    expect(find.textContaining('${t('score')}: '), findsNothing);
    expect(questions(), findsNWidgets(10), reason: 'the quiz and its answers stay');

    await tester.enterText(fields.at(2), 'switch');
    await tester.enterText(fields.at(6), 'hub');
    await tester.tap(find.text(t('submit')));
    await tester.pumpAndSettle();
    expect(find.textContaining(RegExp('^${t('score')}: \\d+ / 10\$')), findsOneWidget);
    expect(store.subjects.single['scores'], hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('blank questions get a red "No answer yet" mark until they are answered', (tester) async {
    await start(tester, _twelve, type: 'id');
    final fields = find.byType(TextField);
    for (var i = 1; i < 10; i++) {
      await tester.enterText(fields.at(i), 'router');
    }
    await tester.tap(find.text(t('submit')));
    await tester.pumpAndSettle();
    expect(find.text(t('no_answer_yet')), findsOneWidget);
    await tester.enterText(fields.at(0), 'switch');
    await tester.pump();
    expect(find.text(t('no_answer_yet')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('answers ignore capitals, hyphens, "the" and punctuation', (tester) async {
    await start(tester, _twelve, type: 'id');
    final terms = {
      for (final m in RegExp(r'^An? (.+?) is (.+)\.$', multiLine: true).allMatches(_twelve))
        m[2]![0].toUpperCase() + m[2]!.substring(1): m[1]!
    };
    final fields = find.byType(TextField);
    for (var i = 0; i < 10; i++) {
      final q = tester.widget<Text>(find.textContaining(RegExp('^${i + 1}\\. '))).data!;
      final term = terms[RegExp(r'"(.*)"').firstMatch(q)![1]]!;
      await tester.enterText(fields.at(i), 'The ${term.toUpperCase().replaceAll(' ', '-')}.');
    }
    await tester.tap(find.text(t('submit')));
    await tester.pumpAndSettle();
    expect(find.text('${t('score')}: 10 / 10'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Quit quiz asks first, then goes back to the quiz setup', (tester) async {
    await start(tester, _twelve);
    await tester.tap(find.text(t('quit_quiz')));
    await tester.pumpAndSettle();
    expect(find.text(t('quit_confirm')), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, t('quit_quiz')));
    await tester.pumpAndSettle();
    expect(questions(), findsNothing);
    expect(find.text(t('start')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('no answers for 45 seconds: Gamy teases in a message bar', (tester) async {
    await start(tester, _twelve, type: 'tf');
    Finder tease() => find.byWidgetPredicate((w) => w is Text && (w.data ?? '').startsWith('🐻 '));
    expect(tease(), findsNothing);
    await tester.pump(const Duration(seconds: 46));
    await tester.pumpAndSettle();
    expect(tease(), findsOneWidget);
    final line = tester.widget<Text>(tease()).data!.substring(3);
    expect(teases['en'], contains(line));
    await tester.pumpWidget(const SizedBox());
  });

  test('score lines never repeat until all of them were used', () {
    final seen = {for (var i = 0; i < 17; i++) nextLine('test', 17)};
    expect(seen, hasLength(17));
  });

  test('Gamy has many different tease lines in both languages', () {
    expect(teases['en'], hasLength(greaterThanOrEqualTo(20)));
    expect(teases['fil'], hasLength(greaterThanOrEqualTo(20)));
  });

  testWidgets('after reopening Gamy, a finished quiz still shows its score (the Nov 21 crash)', (tester) async {
    store.addSubject('Networks');
    await store.load(); // reopen: the lists now come from the database
    final s = store.subjects.single;
    store.restoreModule(s, 'Module 1', _twelve);
    tester.view.physicalSize = const Size(1000, 8000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Quiz())));
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Networks').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Module 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t('id')));
    await tester.pump();
    await tester.tap(find.text(t('start')));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    for (var i = 0; i < 10; i++) {
      await tester.enterText(fields.at(i), 'router');
    }
    await tester.tap(find.text(t('submit')));
    await tester.pumpAndSettle();
    expect(find.textContaining(RegExp('^${t('score')}: \\d+ / 10\$')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
