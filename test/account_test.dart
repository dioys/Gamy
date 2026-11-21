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

  group('notices', () {
    testWidgets('Settings says lessons are device-only and offers Google sign-in', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Settings()));
      expect(find.text(store.t('account_off')), findsOneWidget);
      expect(find.text(store.t('sign_in')), findsOneWidget);
      expect(find.text(store.t('delete_account')), findsNothing, reason: 'only when signed in');
    });

    testWidgets('the Upload tab warns that lessons are lost on reinstall or another device', (tester) async {
      store.lang = 'fil';
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Upload())));
      expect(find.text(store.t('not_saved')), findsOneWidget);
      expect(find.text(store.t('sign_in')), findsOneWidget);
    });
  });
}
