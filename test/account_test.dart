import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamy/account.dart';
import 'package:gamy/settings.dart';
import 'package:gamy/store.dart';
import 'package:gamy/upload.dart';

import 'helpers.dart';

// Tests for the optional account (account.dart) without going online: the pieces that decide what goes
// online, restoring lessons into this device, and the "not saved" notices. Firebase itself isn't started
// in tests, so Gamy behaves like a student who never signed in.
void main() {
  late Directory dir;
  setUp(() async => dir = await freshStore());
  tearDown(() async {
    store.close();
    await dir.delete(recursive: true);
  });

  group('online copy pieces', () {
    test('same name = same online id, and ids never contain "/"', () {
      expect(cloudId('Science'), cloudId('Science'));
      expect(cloudId('Science'), isNot(cloudId('Math')));
      for (final name in ['A/B', 'Module 1.pdf', 'Agham ñ 😀', '..']) {
        expect(cloudId(name), isNot(contains('/')), reason: name);
        expect(cloudId(name), isNot(anyOf('.', '..')), reason: name);
      }
    });

    test('module text is cut into parts that fit, and joins back exactly', () {
      final text = '${'a' * (partChars - 1)}😀${'b' * (partChars + 10)}';
      final parts = textParts(text);
      expect(parts.join(), text);
      for (final p in parts) {
        expect(p.length, lessThanOrEqualTo(partChars));
      }
      expect(parts.first.endsWith('a'), isTrue, reason: 'the emoji is not cut in half');
      expect(textParts('short'), ['short']);
      expect(textParts(''), isEmpty);
    });

    test('signed out: changes stay on this device and nothing breaks', () async {
      expect(account.user, isNull);
      store.addSubject('Science');
      final s = store.subjects.single;
      store.restoreModule(s, 'Module 1', 'A cell is the basic unit of life.');
      store.remove(s['modules'], (s['modules'] as List).single);
      store.remove(store.subjects, s);
      expect(store.subjects, isEmpty);
    });
  });

  group('restoring lessons from the online copy', () {
    test('adds missing subjects and modules, keeps them after a restart, and counts no uploads', () async {
      store.addSubject('Science');
      final s = store.subjectNamed('Science');
      expect(store.subjects, hasLength(1), reason: 'an existing subject is reused, not doubled');
      store.restoreModule(s, 'Cells.pdf', 'A cell is the basic unit of life. Email me at juan@school.edu.');
      store.restoreModule(store.subjectNamed('Math'), 'Algebra.pdf', 'A variable is a letter that stands for a number.');
      expect(store.uploads, 0);

      await store.load(); // like opening Gamy again
      expect(store.subjects.map((s) => s['name']), ['Science', 'Math']);
      final cells = (store.subjects.first['modules'] as List).single;
      expect(cells['name'], 'Cells.pdf');
      expect(cells['text'], isNot(contains('@')), reason: 'the privacy filter also runs on restored text');
    });
  });

  // Bug from Nov 21: after reopening Gamy, finishing a quiz crashed ("_Map<dynamic, dynamic> is not a subtype
  // of Map<String, dynamic>") because the saved scores list only accepted one kind of map.
  test('a quiz score can be saved after Gamy is reopened', () async {
    store.addSubject('Science');
    store.addScore(store.subjects.first, {'module': 'm', 'type': 'mc', 'right': 1, 'total': 2, 'date': '2026-11-21'});
    await store.load(); // reopen
    store.addScore(store.subjects.first, {'module': 'm', 'type': 'id', 'right': 2, 'total': 2, 'date': '2026-11-21'});
    store.restoreModule(store.subjects.first, 'Cells.pdf', 'A cell is the basic unit of life.');
    await store.load();
    expect(store.subjects.first['scores'], hasLength(2));
    expect(store.subjects.first['modules'], hasLength(1));
  });

  // Nov 22: changing account takes the old account's lessons off this device (they're safe online), so two
  // people's lessons never mix. Nothing else changes.
  test('changing account clears this device\'s lessons and scores, but keeps the settings', () async {
    store.agree();
    store.setLang(); // Filipino (saved)
    store.addSubject('Science');
    store.restoreModule(store.subjects.single, 'Cells.pdf', 'A cell is the basic unit of life.');
    store.addScore(store.subjects.single, {'module': 'Cells.pdf', 'type': 'id', 'right': 1, 'total': 1, 'date': 'd'});
    store.clearLessons();
    expect(store.subjects, isEmpty);
    await store.load(); // still empty after reopening
    expect(store.subjects, isEmpty);
    expect(store.agreedTo, isNotNull, reason: 'no new terms screen');
    expect(store.lang, 'fil');
    store.lang = 'en';
  });

  test('changing account also starts Chat and Quiz over (a new "fresh" number for them)', () {
    final before = store.fresh;
    store.clearLessons();
    expect(store.fresh, before + 1);
  });

  // Nov 23: after adding a subject the student had to tap it before uploading. Now it opens right away
  // (the file picker opens too; in tests there's no picker, which Gamy handles quietly).
  testWidgets('a new subject is open right away, with its upload button', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Upload())));
    await tester.tap(find.text(store.t('add_subject')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Algebra');
    await tester.tap(find.text(store.t('add')));
    await tester.pumpAndSettle();
    expect(store.subjects.single['name'], 'Algebra');
    expect(find.text(store.t('add_module')), findsOneWidget, reason: 'no extra tap on the subject');
  });

  group('notices', () {
    testWidgets('Settings says lessons are device-only and offers Google sign-in', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Settings()));
      // The row shows a short status; tapping it opens the details with the button.
      expect(find.text(store.t('not_signed_in')), findsOneWidget);
      expect(find.text(store.t('account_off')), findsNothing);
      await tester.tap(find.text(store.t('account')));
      await tester.pumpAndSettle();
      expect(find.text(store.t('account_off')), findsOneWidget);
      expect(find.text(store.t('sign_in')), findsOneWidget);
      expect(find.text(store.t('delete_account')), findsNothing, reason: 'only when signed in');
      expect(find.text(store.t('change_account')), findsNothing, reason: 'only when signed in');
    });

    testWidgets('the Upload tab warns that lessons are lost on reinstall or another device', (tester) async {
      store.lang = 'fil';
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Upload())));
      expect(find.text(store.t('not_saved')), findsOneWidget);
      expect(find.text(store.t('sign_in')), findsOneWidget);
    });
  });
}
