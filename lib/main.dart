import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'chat.dart';
import 'gamy.dart';
import 'quiz.dart';
import 'settings.dart';
import 'setup.dart';
import 'store.dart';
import 'upload.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  pdfrxFlutterInitialize();
  await store.load();
  runApp(const GamyApp());
}

class GamyApp extends StatefulWidget {
  const GamyApp({super.key});
  @override
  State<GamyApp> createState() => _GamyAppState();
}

class _GamyAppState extends State<GamyApp> {
  int tab = 0;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) => MaterialApp(
          title: 'Gamy',
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          themeMode: store.dark ? ThemeMode.dark : ThemeMode.light,
          home: !store.agreed || store.key == null
              ? Setup() // not const, so it redraws when the store changes
              : Builder(builder: (context) {
            final wide = MediaQuery.sizeOf(context).width >= 700;
            // In Chat, Gamy stands center stage (see chat.dart). In Quiz he sits bottom-left on big screens
            // while the quiz is made and answered; on the result he moves to the middle (see quiz.dart).
            final showGamy = tab == 1 && wide && const ['idle', 'think'].contains(store.moods[1]);
            return Scaffold(
              appBar: AppBar(
                leading: Padding(padding: const EdgeInsets.all(8), child: Image.asset('assets/gamy/head.png')),
                title: const Text('Gamy'),
                actions: [
                  IconButton(
                    tooltip: store.t('settings'),
                    icon: const Icon(Icons.settings),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const Settings())),
                  ),
                ],
              ),
              body: Column(children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: SegmentedButton<int>(
                    segments: [
                      ButtonSegment(value: 0, icon: const Icon(Icons.chat), label: Text(store.t('chat'))),
                      ButtonSegment(value: 1, icon: const Icon(Icons.quiz), label: Text(store.t('quiz'))),
                      ButtonSegment(value: 2, icon: const Icon(Icons.upload_file), label: Text(store.t('upload'))),
                    ],
                    selected: {tab},
                    onSelectionChanged: (s) => setState(() => tab = s.first),
                  ),
                ),
                Expanded(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    if (showGamy) QuizBuddy(), // not const, so his bubble and pose update
                    Expanded(child: IndexedStack(index: tab, children: [Chat(), Quiz(), Upload()])),
                  ]),
                ),
              ]),
            );
          }),
        ),
      );
}

// Light mode: soft cream-brown background. Night mode: dark cocoa. Cards keep thick outlines like Gamy's drawings.
ThemeData _theme(Brightness b) {
  final night = b == Brightness.dark;
  final bg = night ? const Color(0xFF2A211B) : const Color(0xFFF6EBDD);
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7A4A2A), brightness: b),
    scaffoldBackgroundColor: bg,
    appBarTheme: AppBarTheme(backgroundColor: bg, surfaceTintColor: Colors.transparent),
    cardTheme: CardThemeData(
      color: night ? const Color(0xFF3A2E26) : Colors.white,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: night ? const Color(0xFFC9A27E) : ink, width: 2.5),
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  );
}
