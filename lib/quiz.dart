import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ai.dart';
import 'gamy.dart';
import 'paywall.dart';
import 'store.dart';

class Q {
  final String type, q, answer, why, hint;
  final List<String> choices;
  final Map<String, String> wrong; // what each wrong option actually is
  const Q(this.type, this.q, this.answer, this.why, this.hint, {this.choices = const [], this.wrong = const {}});
}

const _kinds = {
  'mc': 'multiple choice questions with exactly 4 choices',
  'tf': 'true or false questions',
  'fill': 'fill in the blank questions',
  'id': 'identification questions (the question describes something; the answer is its name or term)',
  'mix': 'questions, mixing multiple choice, true or false, fill in the blank and identification',
};

// Quiz types that need Gamy Pro (free: multiple choice, true or false, identification).
const _proTypes = {'fill', 'match', 'mix'};

// Paste your Google Form's pre-filled link here, with the word QUESTION where the details go.
// While it's empty, the Report button stays hidden.
const reportForm = '';

// Gamy's comment on the final score, from best to worst: perfect, 70%+, 40%+, below.
const _roasts = {
  'en': [
    ["Perfect. Don't let it go to your head.", 'Not bad. I almost had nothing to roast.', 'Flawless. Who are you and what did you do with my student?'],
    ['Decent. Now fix the ones you missed.', 'Pretty good. Pretty. Not perfect.', 'You studied. I can tell. Barely.'],
    ['Half right is also half wrong.', 'That was... a choice. Review and try again.', 'Did you read the module or just look at it?'],
    ["Oof. Even I'm embarrassed, and I'm a bear.", 'Did you answer with your eyes closed?', "Let's pretend that didn't happen. Review time."],
  ],
  'fil': [
    ['Perpekto. Huwag kang magyabang.', 'Ayos. Wala akong maibanat.', 'Walang mali? Sino ka at nasaan ang estudyante ko?'],
    ["Pwede na. Ayusin mo 'yung mga mali.", 'Maganda. Maganda lang, hindi perpekto.', 'Nag-aral ka, halata. Medyo.'],
    ['Kalahating tama, kalahating mali rin.', "Ano 'yon? Mag-review ka ulit.", 'Binasa mo ba ang module o tiningnan lang?'],
    ['Aray. Pati ako nahiya, at oso ako.', 'Nakapikit ka ba habang sumasagot?', "Kunwari hindi nangyari 'yan. Review na."],
  ],
};

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

// The AI answers with JSON; free models sometimes wrap it in extra text, so cut out the [...] part.
dynamic _json(String s, String open, String close) =>
    jsonDecode(s.substring(s.indexOf(open), s.lastIndexOf(close) + 1));

class Quiz extends StatefulWidget {
  const Quiz({super.key});
  @override
  State<Quiz> createState() => _QuizState();
}

class _QuizState extends State<Quiz> {
  int? pick;
  int count = 10;
  String type = 'mc';
  Map? subject;
  String? moduleName;
  List<Q>? qs;
  final answers = <int, String>{};
  final hints = <int>{};
  final fillWhy = <int, String>{}; // AI's explanation of wrong typed answers
  bool busy = false, done = false, review = false;
  String roast = '';

  List<(Map, Map)> get _mods => [
        for (final s in store.subjects)
          for (final m in s['modules']) (s, m as Map)
      ];

  // Typed answers are compared loosely: "CPU." and "cpu" both match "CPU".
  String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N} ]', unicode: true), '').replaceAll(RegExp(r'\s+'), ' ').trim();
  bool _ok(int i) => _norm(answers[i] ?? '') == _norm(qs![i].answer);
  int get _right => [for (var i = 0; i < qs!.length; i++) if (_ok(i)) i].length;

  void _error(Object e) {
    if (e == 'limit') {
      showAiLimit(context);
      return;
    }
    final k = e is String && ['slow', 'ai_error', 'bad_key', 'offline'].contains(e) ? e : 'bad_quiz';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(store.t(k))));
  }

  // One question from the AI's JSON, or null if it's broken.
  Q? _question(Map m) {
    final t = type == 'mix' ? '${m['type']}' : type;
    if (!['mc', 'tf', 'fill', 'id'].contains(t) || m['q'] is! String || m['answer'] is! String) return null;
    final q = Q(t, m['q'], t == 'tf' ? _cap(m['answer']) : m['answer'], '${m['why'] ?? ''}', '${m['hint'] ?? ''}',
        choices: [for (final c in (m['choices'] as List? ?? [])) '$c'],
        wrong: {
          for (final e in ((m['wrong'] as Map?) ?? {}).entries) (t == 'tf' ? _cap('${e.key}') : '${e.key}'): '${e.value}'
        });
    return t == 'mc' && !q.choices.contains(q.answer) ? null : q;
  }

  // Matching: each term becomes a question whose choices are all the meanings, shuffled.
  // A wrong pick is explained by saying which term that meaning belongs to.
  List<Q> _matching(List<Map> items) {
    final pairs = {for (final m in items) if (m['term'] is String && m['meaning'] is String) '${m['term']}': '${m['meaning']}'};
    final meanings = pairs.values.toList()..shuffle();
    return [
      for (final p in pairs.entries)
        Q('match', p.key, p.value, '${p.key}: ${p.value}', '', choices: meanings, wrong: {
          for (final o in pairs.entries)
            if (o.key != p.key) o.value: '${store.t('meaning_of')} ${o.key}.'
        }),
    ];
  }

  // Asks the AI for [k] questions about one part of the module.
  Future<List<Q>> _batch(String part, int k) async {
    final task = type == 'match'
        ? 'Pick $k different key terms from the lesson. Return a JSON array of objects: '
            '{"term": the term, "meaning": its meaning in one short sentence}'
        : 'Write $k ${_kinds[type]}. Return a JSON array. Each item: {'
            '${type == 'mix' ? '"type": "mc", "tf", "fill" or "id", ' : ''}'
            '"q": the question (for fill in the blank, put ____ where the answer goes), '
            '"choices": 4 options (multiple choice only), '
            '"answer": the correct choice copied exactly for multiple choice, "True" or "False" for true or false, '
            'otherwise the word or short phrase, '
            '"why": one sentence explaining the correct answer, '
            '"hint": a clue that does not give the answer away, '
            '"wrong": {each wrong option: one sentence explaining what that option actually is} '
            '(multiple choice and true or false only)}';
    final reply = await ask([
      {
        'role': 'system',
        'content': 'You write quiz questions for a student reviewing a school module. '
            'Use only facts from the module. Ask only about the lesson itself: concepts, facts, definitions, '
            'processes and examples. Never ask about course or class details such as course codes, course titles, '
            'semesters, school years, schedules, units, instructors, grading or requirements. Reply with JSON only.',
      },
      {
        'role': 'user',
        'content': 'Module:\n"""\n$part\n"""\n\n$langRule\n$task',
      },
    ]);
    final items = [for (final m in _json(reply, '[', ']') as List) if (m is Map) m];
    return type == 'match' ? _matching(items) : [for (final m in items) ?_question(m)];
  }

  // Big quizzes are made in parts of up to 20 questions, each from a different section of the module,
  // all at the same time. If some parts fail, the quiz uses the parts that worked.
  Future<void> _start((Map, Map) sm) async {
    // Free plan: not enough quiz items left this week -> show the Pro frame instead.
    if (count > store.itemsLeft) {
      final t = store.t, date = store.refreshText;
      return showPro(context,
          '${t('pro_items').replaceFirst('{left}', '${store.itemsLeft}')} ${date.isEmpty ? '' : t('refreshes').replaceFirst('{date}', date)}');
    }
    setState(() => busy = true);
    store.setMood(1, 'think');
    final text = sm.$2['text'] as String;
    final n = (count / 20).ceil(), size = (text.length / n).ceil();
    Object? err;
    try {
      final parts = await Future.wait([
        for (var b = 0; b < n; b++)
          _batch(
            text.substring(min(b * size, text.length), min(text.length, b * size + min(size, 10000))),
            count ~/ n + (b < count % n ? 1 : 0),
          ).catchError((Object e) {
            err = e;
            return <Q>[];
          }),
      ]);
      final list = parts.expand((p) => p).toList();
      if (list.isEmpty) throw err ?? 'bad_quiz';
      store.useItems(list.length); // counts toward the free weekly 70
      setState(() {
        subject = sm.$1;
        moduleName = sm.$2['name'];
        qs = list;
        answers.clear();
        hints.clear();
        fillWhy.clear();
        done = review = false;
      });
      store.setMood(1, 'idle');
    } catch (e) {
      if (mounted) _error(e);
      store.setMood(1, 'idle');
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _submit() async {
    // Typed answers have no preset explanations, so ask the AI about the wrong ones.
    final wrongFill = [
      for (var i = 0; i < qs!.length; i++)
        if (['fill', 'id'].contains(qs![i].type) && !_ok(i) && (answers[i] ?? '').trim().isNotEmpty) i
    ];
    if (wrongFill.isNotEmpty) {
      setState(() => busy = true);
      try {
        final reply = await ask([
          {
            'role': 'user',
            'content': 'A student answered these quiz questions wrong. For each one, '
                'explain in one sentence what the student\'s answer actually is or means. $langRule\n'
                'Reply with only a JSON object mapping each number to the explanation.\n'
                '${[for (final i in wrongFill) '$i. Question: ${qs![i].q} | Correct: ${qs![i].answer} | Student: ${answers[i]}'].join('\n')}',
          },
        ]);
        (_json(reply, '{', '}') as Map).forEach((k, v) => fillWhy[int.tryParse('$k') ?? -1] = '$v');
      } catch (_) {} // the review still works without these
      busy = false;
    }
    final r = _right, n = qs!.length;
    store.addScore(subject!, {
      'module': moduleName,
      'type': type,
      'right': r,
      'total': n,
      'date': DateTime.now().toIso8601String().substring(0, 10),
    });
    final band = r == n ? 0 : r / n >= .7 ? 1 : r / n >= .4 ? 2 : 3;
    store.setMood(1, const ['smug', 'happy', 'surprised', 'sad'][band]);
    final lines = _roasts[store.lang]![band];
    setState(() {
      done = true;
      roast = lines[DateTime.now().millisecond % lines.length];
    });
  }

  void _reset() {
    setState(() => qs = null);
    store.setMood(1, 'idle');
  }

  String _show(Q q, String a) => q.type == 'tf' ? store.t(a.toLowerCase()) : a;

  @override
  Widget build(BuildContext context) {
    final t = store.t;
    if (qs == null) return _setup(t);
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (done) ...[
        // On phones Gamy is hidden during the quiz, so he shows up here for the result.
        // Result: Gamy stands in the middle with his comment right above his head.
        Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420, maxHeight: 200), child: Bubble(roast))),
        Center(child: GamySprite(store.moods[1], size: MediaQuery.sizeOf(context).width < 700 ? 140 : 200)),
        Text('${t('score')}: $_right / ${qs!.length}',
            textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
          if (!review) FilledButton(onPressed: () => setState(() => review = true), child: Text(t('review'))),
          OutlinedButton(onPressed: _reset, child: Text(t('new_quiz'))),
        ]),
        const SizedBox(height: 8),
        Text(t('mistakes'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
      ],
      if (!done || review)
        for (var i = 0; i < qs!.length; i++) _card(i, t),
      if (!done) FilledButton(onPressed: busy ? null : _submit, child: Text(t('submit'))),
    ]);
  }

  Widget _card(int i, String Function(String) t) {
    final q = qs![i], a = answers[i], ok = _ok(i);
    final color = !review ? null : (ok ? Colors.green : Colors.red);
    final wrongWhy = q.wrong[a] ?? fillWhy[i];
    return Card(
      shape: color == null
          ? null
          : RoundedRectangleBorder(side: BorderSide(color: color, width: 3), borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${i + 1}. ${q.q}', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (q.type == 'mc' || q.type == 'tf')
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in q.type == 'tf' ? ['True', 'False'] : q.choices)
                if (done)
                  _choice(_show(q, c), c == q.answer ? Colors.green.shade700 : (c == a ? Colors.red.shade700 : null))
                else
                  ChoiceChip(
                    label: Text(_show(q, c)),
                    selected: a == c,
                    onSelected: (_) => setState(() => answers[i] = c),
                  ),
            ])
          else if (done)
            _choice(a?.trim().isNotEmpty == true ? a! : t('no_answer'), ok ? Colors.green.shade700 : Colors.red.shade700)
          else if (q.type == 'match')
            DropdownButton<String>(
              isExpanded: true,
              itemHeight: null, // let long meanings wrap onto more lines
              hint: Text(t('pick_meaning')),
              value: a,
              items: [for (final c in q.choices) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => setState(() => answers[i] = v!),
            )
          else
            TextField(onChanged: (v) => answers[i] = v),
          if (!done && !hints.contains(i) && q.hint.isNotEmpty)
            TextButton(onPressed: () => setState(() => hints.add(i)), child: Text(t('hint'))),
          if (!done && hints.contains(i)) Padding(padding: const EdgeInsets.only(top: 8), child: Text('💡 ${q.hint}')),
          if (review && !ok) ...[
            const Divider(),
            Text('${t('correct')}: ${_show(q, q.answer)}',
                style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold)),
            Text(q.why),
            if (wrongWhy != null && a != null) ...[
              const SizedBox(height: 6),
              Text('${t('your_answer')} (${_show(q, a)}): $wrongWhy', style: TextStyle(color: Colors.red.shade800)),
            ],
          ],
          if (review && reportForm.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: Text(t('report')),
                onPressed: () => launchUrl(Uri.parse(reportForm.replaceFirst('QUESTION',
                    Uri.encodeComponent('${q.q}\nGamy\'s answer: ${q.answer}\nExplanation: ${q.why}')))),
              ),
            ),
        ]),
      ),
    );
  }

  // A review answer: green = correct answer, red = the student's wrong pick, plain = the rest.
  Widget _choice(String text, Color? c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: c?.withValues(alpha: .12),
          border: Border.all(color: c ?? Colors.grey, width: c == null ? 1 : 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: TextStyle(color: c ?? Colors.grey, fontWeight: c == null ? null : FontWeight.bold)),
      );

  Widget _setup(String Function(String) t) {
    final mods = _mods;
    if (mods.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(t('need_module'), textAlign: TextAlign.center)));
    }
    if (pick != null && pick! >= mods.length) pick = null;
    final Iterable scores = pick == null ? const [] : (mods[pick!].$1['scores'] as List).reversed.take(5);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text(t('pick_module')),
      DropdownButton<int>(
        isExpanded: true,
        value: pick,
        items: [
          for (var i = 0; i < mods.length; i++)
            DropdownMenuItem(value: i, child: Text('${mods[i].$1['name']} • ${mods[i].$2['name']}', overflow: TextOverflow.ellipsis)),
        ],
        onChanged: busy ? null : (v) => setState(() => pick = v),
      ),
      const SizedBox(height: 16),
      Text(t('pick_type')),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final k in ['mc', 'tf', 'fill', 'id', 'match', 'mix'])
          ChoiceChip(
            avatar: !store.pro && _proTypes.contains(k) ? const Icon(Icons.lock, size: 16) : null,
            label: Text(t(k)),
            selected: type == k,
            onSelected: busy
                ? null
                : (_) {
                    if (!store.pro && _proTypes.contains(k)) {
                      showPro(context, t('pro_types')); // locked type -> Pro frame
                    } else {
                      setState(() => type = k);
                    }
                  },
          ),
      ]),
      const SizedBox(height: 16),
      Text('${t('count')}: $count'),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        for (final n in [10, 15, 20, 25])
          ChoiceChip(label: Text('$n'), selected: count == n, onSelected: busy ? null : (_) => setState(() => count = n)),
        // Or type any number; anything above 100 counts as 100.
        SizedBox(
          width: 110,
          child: TextField(
            enabled: !busy,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
            decoration: InputDecoration(hintText: t('other_count'), isDense: true),
            onChanged: (v) {
              final n = int.tryParse(v);
              if (n != null) setState(() => count = n.clamp(1, 100));
            },
          ),
        ),
      ]),
      if (!store.pro)
        Text(
          '${t('items_left').replaceFirst('{left}', '${store.itemsLeft}')} '
          '${store.refreshText.isEmpty ? '' : t('refreshes').replaceFirst('{date}', store.refreshText)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      if (count > 20) Text(t('big_quiz').replaceFirst('{n}', '${(count / 20).ceil()}'), style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 16),
      if (busy) Text(t('making'), textAlign: TextAlign.center),
      FilledButton(onPressed: pick == null || busy ? null : () => _start(mods[pick!]), child: Text(t('start'))),
      if (scores.isNotEmpty) ...[
        const SizedBox(height: 24),
        Text(t('history'), style: const TextStyle(fontWeight: FontWeight.bold)),
        for (final s in scores) Text('${s['date']} • ${s['module']} • ${t(s['type'])}: ${s['right']}/${s['total']}'),
      ],
    ]);
  }
}
