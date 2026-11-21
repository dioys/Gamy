import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamy/brain.dart';
import 'package:gamy/main.dart';
import 'package:gamy/store.dart';

import 'helpers.dart';

// Runs the whole app on phone-sized screens, with and without the keyboard open.
// If anything doesn't fit (the yellow-and-black stripes), Flutter reports an overflow and the test fails.
// Note: tests draw text in a blocky test font that is wider than the real one, so these are a bit
// stricter than a real phone.

// Screen size in real pixels, pixels per point, and how much the keyboard covers (in points).
const _phones = {
  'Samsung A53': (Size(1080, 2400), 2.625, 300.0),
  'small phone': (Size(720, 1280), 2.0, 260.0),
};

void main() {
  late Directory dir;
  setUp(() async {
    dir = await freshStore();
    await brain.start();
  });
  tearDown(() async {
    store.close(); // Windows can't delete a database file that is still open
    await dir.delete(recursive: true);
  });

  for (final phone in _phones.entries) {
    for (final lang in ['en', 'fil']) {
      for (final keyboard in [false, true]) {
        testWidgets('${phone.key}, ${lang == 'en' ? 'English' : 'Filipino'}, keyboard ${keyboard ? 'open' : 'closed'}',
            (tester) async {
          final (size, ratio, keys) = phone.value;
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = ratio;
          if (keyboard) tester.view.viewInsets = FakeViewPadding(bottom: keys * ratio);
          addTearDown(tester.view.reset);
          store.lang = lang;
          store.agree();
          store.subjects = [subject()];
          final t = store.t;

          await tester.pumpWidget(const GamyApp());
          await tester.pump();

          // Chat: ask something, so Gamy has a long reply on screen
          await tester.enterText(find.byType(TextField).first, 'What is the motherboard?'); // first = Chat's box
          await tester.tap(find.byIcon(Icons.send));
          await tester.pump();
          expect(find.textContaining('main circuit board'), findsWidgets);

          // Quiz and Upload tabs
          await tester.tap(find.text(t('quiz')));
          await tester.pump();
          await tester.tap(find.text(t('upload')));
          await tester.pump();

          // Settings
          if (!keyboard) {
            await tester.tap(find.byIcon(Icons.settings));
            await tester.pumpAndSettle();
            expect(find.text(t('brain')), findsOneWidget);
          }

          await tester.pump(const Duration(seconds: 16)); // let Gamy finish "talking"
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
}
