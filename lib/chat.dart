import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'brain.dart';
import 'gamy.dart';
import 'rules.dart';
import 'store.dart';
import 'wiki.dart';

class Chat extends StatefulWidget {
  const Chat({super.key});
  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  final msgs = <(bool, String)>[]; // (from Gamy?, text)
  final input = TextEditingController();
  bool busy = false; // the brain is still writing
  Timer? _nap;

  @override
  void initState() {
    super.initState();
    msgs.add((true, store.t('hello')));
    _poke();
  }

  // Any activity wakes Gamy up and restarts his nap timer (he dozes off after a minute alone).
  void _poke() {
    if (store.moods[0] == 'sleep') store.setMood(0, 'idle');
    _nap?.cancel();
    _nap = Timer(const Duration(seconds: 60), () {
      if (store.moods[0] == 'idle') store.setMood(0, 'sleep');
    });
  }

  // Poking Gamy while he's awake makes him stick his tongue out.
  void _tapGamy() {
    if (store.moods[0] == 'idle') {
      store.setMood(0, 'playful');
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (store.moods[0] == 'playful') store.setMood(0, 'idle');
      });
    }
    _poke();
  }

  @override
  void dispose() {
    input.dispose();
    _nap?.cancel();
    super.dispose();
  }

  // Who Gamy is, plus his source: the module lines that match the question, or else a Wikipedia page.
  String _gamy(List<Line> lines, WikiPage? page) => '${gamyIs()} Answer in 1 to 3 short sentences, '
      '${page == null ? 'using only the module lines below. If they do not answer the question, say it is not in their module.'
          '\n\nModule lines:\n${lines.isEmpty ? '(nothing matched)' : lines.map((l) => '- ${l.text}').join('\n')}' : 'using only the Wikipedia text below. Say first that it is not in their module.'
          '\n\nWikipedia (${page.title}):\n${page.text}'}';

  // Gamy looks through ALL the student's modules first. Only when they don't have the answer does he look it
  // up on Wikipedia (online only), and then he says where it came from.
  // With the brain on, he answers in his own words; without it, he quotes the lines.
  Future<void> _send() async {
    final s = input.text.trim();
    if (s.isEmpty || busy) return;
    final mods = <Map>[for (final x in store.subjects) ...x['modules']];
    setState(() {
      msgs.add((false, s));
      input.clear();
      busy = true;
    });
    _poke();
    // 1. The modules: smart search (by meaning) when the brain has it, plus keyword search.
    final words = bestLines(s, mods, 3);
    var lines = brain.searchReady ? await store.search(s, mods, 3).catchError((_) => <Line>[]) : <Line>[];
    final inModule = keywordsAnswer(s, words) || (lines.isNotEmpty && lines.first.score >= 550);
    if (lines.isEmpty || lines.first.score < 550) lines = words ?? []; // smart search found nothing close
    // 2. Not in the modules: Wikipedia (null when offline or nothing matched).
    final page = inModule || words == null ? null : await wiki(s);
    final source = page == null ? '' : '\n\n${store.t('wiki_source').replaceFirst('{title}', page.title)}';
    if (!mounted) return;
    // No source at all (not in the modules, nothing online): say so, and don't let the brain guess.
    if (!brain.ready || (!inModule && page == null && words != null)) {
      final reply = page != null
          ? '${store.t('wiki_intro')}\n\n"${cleanReply(page.text)}"$source'
          : inModule || words == null
              ? findAnswer(s, mods)
              : store.t('not_found_offline');
      setState(() {
        msgs.add((true, reply));
        busy = false;
      });
      await talk(0, reply);
      if (mounted) _poke();
      return;
    }
    setState(() => msgs.add((true, '')));
    store.setMood(0, 'talk'); // his mouth moves while the words come in
    var reply = '';
    try {
      await for (final w in brain.say(_gamy(lines, page), s)) {
        reply += w;
        if (mounted) setState(() => msgs.last = (true, cleanReply(reply)));
      }
    } catch (e) {
      reply = ''; // the brain failed: fall back to quoting below
    }
    reply = reply.trim().isEmpty ? findAnswer(s, mods) : '${cleanReply(reply)}$source';
    if (!mounted) return;
    setState(() {
      msgs.last = (true, reply);
      busy = false;
    });
    store.setMood(0, 'idle');
    _poke();
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 700;
    // Bubble and Gamy shrink on short screens (small windows, or a phone with the keyboard open)
    // so the input box always fits. The message history takes whatever space is left.
    // When even that is too tight, Gamy steps aside and his replies go in the history too.
    return LayoutBuilder(builder: (context, box) {
      final room = box.maxHeight * .22, tight = room < 70;
      // Gamy's latest reply goes in his big speech bubble; everything else is the small history.
      final shown = tight ? -1 : msgs.lastIndexWhere((m) => m.$1);
      return Column(children: [
        Expanded(
          child: ListView(reverse: true, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            for (var i = msgs.length - 1; i >= 0; i--)
              if (i != shown)
                Align(
                  alignment: msgs[i].$1 ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    constraints: const BoxConstraints(maxWidth: 360),
                    decoration: BoxDecoration(
                      color: msgs[i].$1 ? Colors.white : const Color(0xFFE8C9A0),
                      border: Border.all(color: ink, width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(msgs[i].$2, style: const TextStyle(fontSize: 13, color: ink)), // light bubble, dark text in both modes
                  ),
                ),
          ]),
        ),
        if (!tight) ...[
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 520, maxHeight: min(narrow ? 170.0 : 220.0, room)),
            child: Bubble(msgs[shown].$2.isEmpty ? '...' : msgs[shown].$2),
          ),
          GestureDetector(onTap: _tapGamy, child: GamySprite(store.moods[0], size: min(narrow ? 150.0 : 230.0, room))),
        ],
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: input,
                onSubmitted: (_) => _send(),
                onChanged: (_) => _poke(),
                decoration: InputDecoration(
                  hintText: store.t('type_msg'),
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                ),
              ),
            ),
            IconButton.filled(onPressed: busy ? null : _send, icon: const Icon(Icons.send)),
          ]),
        ),
        if (!tight)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(store.t('mistakes'), style: Theme.of(context).textTheme.bodySmall),
          ),
      ]);
    });
  }
}
