import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gamy/brain.dart';
import 'package:gamy/rules.dart';
import 'package:gamy/store.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'helpers.dart';

// Tests the real brain with the downloaded model, and measures its speed on this computer.
// Skipped unless you point GAMY_BRAIN_DIR at the folder that holds brain.gguf. Tests don't get the
// llama.cpp files copied next to them like the app does, so LLAMADART_NATIVE_LIB_DIR points at the ones
// the last `flutter run -d windows` built. On Windows, after downloading the brain in the app (Settings),
// run in PowerShell:
//   $env:GAMY_BRAIN_DIR = "$env:APPDATA\BuddyBear\Gamy"
//   $env:LLAMADART_NATIVE_LIB_DIR = "C:\Gamy\build\native_assets\windows"
//   flutter test test/brain_test.dart
final _dir = Platform.environment['GAMY_BRAIN_DIR'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the brain loads and answers from the module lines', () async {
    PathProviderPlatform.instance = FakePath(_dir!);
    final load = Stopwatch()..start();
    await brain.start();
    expect(brain.ready, isTrue, reason: 'brain.gguf should load');
    // ignore: avoid_print
    print('Loaded in ${load.elapsedMilliseconds} ms');

    final clock = Stopwatch()..start();
    int? first;
    var reply = '', pieces = 0;
    await for (final w in brain.say(
      'You are Gamy, a blunt study bear. Answer in 1 to 2 short sentences using only this module line:\n'
          '- The motherboard is the main circuit board that connects all the parts of a computer together.',
      'What is the motherboard?',
    )) {
      first ??= clock.elapsedMilliseconds;
      reply += w;
      pieces++;
    }
    // ignore: avoid_print
    print('First word after $first ms, whole reply after ${clock.elapsedMilliseconds} ms ($pieces pieces):\n$reply');
    expect(reply.trim(), isNotEmpty);
    expect(reply, isNot(contains('<think>')), reason: 'thinking mode should be off');
  },
      skip: _dir == null ? 'Set GAMY_BRAIN_DIR to the folder with brain.gguf to run this' : false,
      timeout: const Timeout(Duration(minutes: 5)));

  test('two requests at once both finish (Chat and Quiz take turns)', () async {
    if (!brain.ready) {
      PathProviderPlatform.instance = FakePath(_dir!);
      await brain.start();
    }
    final clock = Stopwatch()..start();
    // The same kind of request the quiz review sends for a wrong typed answer.
    final explain = brain
        .say(
          '${gamyIs()} Use only the module line given.',
          'Module line: The motherboard is the main circuit board that connects all the parts of a computer together.\n'
              'Correct answer: motherboard\nStudent answered: hard disk drive\n'
              'In one or two short sentences, tell the student why "hard disk drive" is wrong.',
          maxTokens: 80,
        )
        .join();
    final chat = brain.say(gamyIs(), 'Say hi in five words.', maxTokens: 20).join();
    final replies = await Future.wait([explain, chat]);
    // ignore: avoid_print
    print('Both done after ${clock.elapsedMilliseconds} ms\nExplanation: ${replies[0]}\nChat: ${replies[1]}');
    expect(replies[0].trim(), isNotEmpty);
    expect(replies[1].trim(), isNotEmpty);
  },
      skip: _dir == null ? 'Set GAMY_BRAIN_DIR to the folder with brain.gguf to run this' : false,
      timeout: const Timeout(Duration(minutes: 5)));

  test('Gamy roasts a wrong answer in Taglish', () async {
    if (!brain.ready) {
      PathProviderPlatform.instance = FakePath(_dir!);
      await brain.start();
    }
    store.lang = 'fil';
    final reply = await brain
        .say(
          '${gamyIs()} Use only the module line given.',
          'Module line: The motherboard is the main circuit board that connects all the parts of a computer together.\n'
              'Correct answer: motherboard\nStudent answered: keyboard\n'
              'In one or two short sentences, tell the student why "keyboard" is wrong.',
          maxTokens: 80,
        )
        .join();
    store.lang = 'en';
    // ignore: avoid_print
    print('Taglish roast: $reply');
    expect(reply.trim(), isNotEmpty);
  },
      skip: _dir == null ? 'Set GAMY_BRAIN_DIR to the folder with brain.gguf to run this' : false,
      timeout: const Timeout(Duration(minutes: 5)));

  test('smart search finds the English line for a Taglish question', () async {
    if (!brain.ready) {
      PathProviderPlatform.instance = FakePath(_dir!);
      await brain.start();
    }
    expect(brain.searchReady, isTrue, reason: 'search.gguf should load (download it in Settings first)');
    final pieces = sentences(sample);
    final clock = Stopwatch()..start();
    final vectors = await brain.embedChunks(pieces);
    final made = clock.elapsedMilliseconds;
    final q = await brain.embedQuestion('Ano yung nag-iistore ng data kahit naka-off ang computer?');
    final ranked = [for (var i = 0; i < pieces.length; i++) (closeness(q, vectorBytes(vectors[i])), pieces[i])]
      ..sort((a, b) => b.$1.compareTo(a.$1));
    // ignore: avoid_print
    print('Embedded ${pieces.length} sentences in $made ms. Best match (${ranked.first.$1.toStringAsFixed(2)}): ${ranked.first.$2}');
    expect(ranked.first.$2, contains('hard disk drive'));
  },
      skip: _dir == null ? 'Set GAMY_BRAIN_DIR to the folder with brain.gguf to run this' : false,
      timeout: const Timeout(Duration(minutes: 5)));

  // Nov 23: Chat hung on a 700-page algebra book, because smart search read the whole book before answering.
  // Now the question is answered right away and the book is read in the background, saved as it goes.
  test('a chat question never waits for smart search to read a big module', () async {
    if (!brain.searchReady) {
      PathProviderPlatform.instance = FakePath(_dir!);
      await brain.start();
    }
    final dir = await freshStore(); // the models stay loaded; the lessons go to a new empty folder
    store.restoreModule(store.subjectNamed('Algebra'), 'Big book', List.filled(300, sample).join('\n'));
    final clock = Stopwatch()..start();
    await store.search('What stores data when the computer is off?', store.subjects.single['modules'], 3);
    // ignore: avoid_print
    print('Answered in ${clock.elapsedMilliseconds} ms while the book is still being read');
    expect(clock.elapsedMilliseconds, lessThan(5000));
    await Future<void>.delayed(const Duration(seconds: 5));
    final found = await store.search('What stores data when the computer is off?', store.subjects.single['modules'], 3);
    expect(found, isNotEmpty, reason: 'the first pieces were read and saved meanwhile');
    store.close();
    await dir.delete(recursive: true);
  },
      skip: _dir == null ? 'Set GAMY_BRAIN_DIR to the folder with brain.gguf to run this' : false,
      timeout: const Timeout(Duration(minutes: 5)));

  // Bug from Nov 22: smart search always said "Download failed" because the file name had a capital "M"
  // ("300M-Q4_0"); Hugging Face's file is "embeddinggemma-300m-Q4_0.gguf" and names are case-sensitive.
  test('the download links use the exact Hugging Face file names', () {
    final code = File('lib/brain.dart').readAsStringSync();
    expect(code, contains('/resolve/main/embeddinggemma-300m-Q4_0.gguf'));
    expect(code, contains('/resolve/main/Qwen_Qwen3-0.6B-Q4_K_M.gguf'));
  });

  // Nov 22: the download error says the real reason instead of always "check your internet and free space".
  test('a failed download says why', () {
    expect(whyFailed(const SocketException('Failed host lookup')), 'why_net');
    expect(whyFailed(const FileSystemException('write', 'brain.gguf.part', OSError('No space left on device', 28))),
        'why_space');
    expect(whyFailed(const FileSystemException('write', 'x', OSError('There is not enough space on the disk', 112))),
        'why_space');
    expect(whyFailed('HTTP 404'), 'why_missing');
    expect(whyFailed('cut'), 'why_cut');
    for (final lang in ['en', 'fil']) {
      store.lang = lang;
      for (final k in ['why_net', 'why_space', 'why_missing', 'why_cut']) {
        expect(store.t('brain_failed').replaceFirst('{why}', store.t(k)), isNot(contains('{')), reason: k);
      }
    }
    store.lang = 'en';
  });
}
