import 'dart:async';

import 'package:flutter/material.dart';

import 'ai.dart';
import 'gamy.dart';
import 'paywall.dart';
import 'store.dart';

const _personality = 'You are Gamy, a talking bear in a study app for students 18 and older. '
    'Personality: blunt, sarcastic and a bit of a roaster, but you always end up actually helping. '
    'Roast wrong answers and lazy questions, never the person (no insults about looks, identity or worth, no slurs). '
    'Keep replies short, under 120 words. Your main job is to help the student review and understand their lesson: '
    'quiz them, give facts from the module, and explain clearly. '
    'If a module is given, base your facts on it and say so when something is not in it. '
    'Stick to the lesson itself: ignore course details like codes, semesters or grading, and never share '
    'anyone\'s contact information from the module. '
    'Never announce or explain that you are roasting, blunt or sarcastic, and never describe your own personality. '
    'Just talk that way naturally, because it is simply who you are. '
    'If the student\'s latest message has spelling or grammar mistakes, end your reply with a new line that starts '
    'with ✏️ and briefly corrects them, for example: ✏️ "color", not "colr". Leave that line out when there are no mistakes.';

class Chat extends StatefulWidget {
  const Chat({super.key});
  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  final msgs = <(bool, String)>[]; // (from Gamy?, text)
  final _failed = <int>{}; // error messages shown as Gamy; never sent back to the AI
  final input = TextEditingController();
  Map? module; // what the student wants to talk about
  bool busy = false;
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

  Future<void> _send() async {
    final s = input.text.trim();
    if (s.isEmpty || busy) return;
    setState(() {
      msgs.add((false, s));
      input.clear();
      busy = true;
    });
    _poke();
    store.setMood(0, 'think');
    String reply;
    var failed = false;
    try {
      final text = module?['text'] as String?;
      reply = await ask([
        {
          'role': 'system',
          'content': '$_personality $langRule'
              '${text == null ? '' : '\n\nModule "${module!['name']}":\n"""\n${text.length > 15000 ? text.substring(0, 15000) : text}\n"""'}',
        },
        for (var i = msgs.length > 12 ? msgs.length - 12 : 0; i < msgs.length; i++)
          if (!_failed.contains(i)) {'role': msgs[i].$1 ? 'assistant' : 'user', 'content': msgs[i].$2},
      ]);
    } catch (e) {
      failed = true;
      reply = store.t(e is String && ['limit', 'slow', 'bad_key', 'offline'].contains(e) ? e : 'ai_error');
      if (e == 'limit' && mounted) showAiLimit(context);
    }
    if (!mounted) return;
    setState(() {
      if (failed) _failed.add(msgs.length);
      msgs.add((true, reply));
      busy = false;
    });
    await talk(0, reply);
    if (mounted) _poke();
  }

  @override
  Widget build(BuildContext context) {
    final mods = [for (final s in store.subjects) ...s['modules']];
    if (!mods.contains(module)) module = null;
    final narrow = MediaQuery.sizeOf(context).width < 700;
    // Gamy's latest reply goes in his big speech bubble; everything else is the small history.
    final shown = busy ? -1 : msgs.lastIndexWhere((m) => m.$1);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          Text('${store.t('about')}: '),
          Expanded(
            child: DropdownButton<Map?>(
              isExpanded: true,
              value: module,
              items: [
                DropdownMenuItem(child: Text(store.t('nothing'))),
                for (final m in mods) DropdownMenuItem(value: m as Map, child: Text(m['name'], overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => module = v),
            ),
          ),
        ]),
      ),
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
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 520, maxHeight: narrow ? 170 : 220),
        child: Bubble(busy ? '...' : msgs[shown].$2),
      ),
      GestureDetector(onTap: _tapGamy, child: GamySprite(store.moods[0], size: narrow ? 150 : 230)),
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
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(store.t('mistakes'), style: Theme.of(context).textTheme.bodySmall),
      ),
    ]);
  }
}
