import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'account.dart';
import 'brain.dart';
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
  await account.start(); // Firebase (optional Google account); Gamy works without it
  brain.start(); // loads Gamy's brain in the background if it was downloaded before
  if (_crashReports.isEmpty) {
    runApp(const GamyApp()); // tests and builds without the key: no crash reports
    return;
  }
  await SentryFlutter.init(crashReportOptions, appRunner: () => runApp(SentryWidget(child: const GamyApp())));
}

// ----- Crash reports (Sentry) -----
// Only when Gamy crashes or hits an error nobody caught: what went wrong, where in Gamy's code, Gamy's version
// and the device model / Windows or Android version. No name, email, account, lessons, chats or answers:
// no personal details, no screenshots, no screen layout, no trail of what the student tapped or typed,
// no speed tracking. The key comes from the build file (like the Windows sign-in key), never from the code.
const _crashReports = String.fromEnvironment('SENTRY_DSN');

void crashReportOptions(SentryFlutterOptions o) {
  o.dsn = _crashReports;
  o.sendDefaultPii = false; // no IP address, user or device names
  o.attachScreenshot = false;
  o.attachViewHierarchy = false;
  o.tracesSampleRate = 0; // no speed tracking
  o.beforeBreadcrumb = (crumb, hint) => null; // no trail of taps, screens, network calls or log lines
  o.beforeSend = (event, hint) {
    event.user = null;
    event.serverName = null; // the computer's name
    return event;
  };
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
        listenable: Listenable.merge([store, account]),
        builder: (context, _) => MaterialApp(
          title: 'Gamy',
          debugShowCheckedModeBanner: false,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          themeMode: store.dark ? ThemeMode.dark : ThemeMode.light,
          home: !store.agreed // first launch: age check and terms
              ? Setup() // not const, so it redraws when the store changes
              : Builder(builder: (context) {
            // In Chat, Gamy stands center stage (see chat.dart). The quiz uses the whole screen; Gamy only
            // shows up on its score (see quiz.dart).
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
                  // Shrinks the tab buttons if they don't fit (small phones, longer Filipino labels)
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
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
                ),
                Expanded(child: IndexedStack(index: tab, children: [
                  // A new key after changing account: the old account's chat and quiz are gone too.
                  Chat(key: ValueKey('chat${store.fresh}')),
                  Quiz(key: ValueKey('quiz${store.fresh}')),
                  Upload(),
                ])),
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
