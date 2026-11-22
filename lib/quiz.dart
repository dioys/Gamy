import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'brain.dart';
import 'gamy.dart';
import 'paywall.dart';
import 'rules.dart';
import 'solve.dart';
import 'store.dart';
import 'wiki.dart';

class Q {
  final String type, q, answer, why, hint;
  final String topic; // what to look up on Wikipedia for "More about..." in the review ('' = nothing)
  final List<String> choices;
  final Map<String, String> wrong; // what each wrong option actually is
  const Q(this.type, this.q, this.answer, this.why, this.hint,
      {this.choices = const [], this.wrong = const {}, this.topic = ''});
}

// Quiz types that need Gamy Pro (free: multiple choice, true or false, identification).
const _proTypes = {'fill', 'match', 'mix', 'solve'};

// Paste your Google Form's pre-filled link here, with the word QUESTION where the details go.
// While it's empty, the Report button stays hidden.
const reportForm = '';

// Gamy's verdict on the score, by band: high (80% and up), middle (50% and up), low (below 50%).
// 50 lines per language (17 / 16 / 17), picked at random. No mercy for the score, never for the person.
// Picks the next of [n] lines for [key] without repeating any until all of them were used (a shuffled deck).
final _decks = <String, List<int>>{};
int nextLine(String key, int n) {
  final deck = _decks[key] ??= [];
  if (deck.isEmpty) deck.addAll(List.generate(n, (i) => i)..shuffle());
  return deck.removeLast();
}

const roasts = {
  'en': [
    ["Got lucky, huh?", "Okay, who gave you the answers?", "Not bad... for a human.", "Show-off.",
     "Did you study, or did you sell your soul?", "Fine, I’m impressed. Don’t let it go to your head.",
     "Calm down, Einstein.", "Suspiciously good.", "Wow, you actually opened the book this time.",
     "Big brain energy.", "Was that skill or a glitch?", "I’ll allow it.", "Someone’s been drinking their milk.",
     "Teacher’s pet detected.", "Who are you, and what did you do with the real you?", "Flex detected.",
     "Okay okay, you cooked."],
    ["Meh. Could be worse.", "Half a brain, full effort.", "Studying on one neuron?", "Almost. Almost.",
     "The bare minimum, as usual.", "Passing... barely breathing.", "You guessed half of those, didn’t you?",
     "Mid. Very mid.", "Close, but no trophy.", "That neuron needs a friend.", "You skimmed, didn’t you?",
     "Respectable. Barely.", "C’s get degrees, I guess.", "Was that a 50/50 or a coin flip?",
     "Getting there... slowly.", "Points for showing up."],
    ["Okay... that was dumb.", "Did you even review??", "Bro answered with vibes.", "Were you asleep?",
     "Did you even read the questions?", "I’ve seen better scores from a cat on a keyboard.", "That’s... a choice.",
     "Your brain went on vacation without you.", "Loading intelligence... failed.",
     "Did you study the wrong subject?", "The answers were right there.", "Not your day, huh?",
     "Reset and try again. Please.", "Error 404: brain not found.", "You good? Blink twice.",
     "Random guessing would’ve scored higher.", "Let’s pretend this never happened."],
  ],
  'fil': [
    ["Ang lupit!", "Sana all matalino.", "Tsamba lang yan, boi.", "Sino nagbigay ng sagot?",
     "Grabe, nag-aral ka pala?", "Ikaw na. Ikaw na talaga.", "Petmalu!", "Lodi!", "Ay, may utak naman pala.",
     "Sige na, ikaw na bida.", "Kinabahan ako sa’yo ah.", "Yabang mo na niyan?", "Nakakagulat, seryoso.",
     "Henyo ka ba o swerte lang?", "Uminom ka ba ng vitamins?", "Pak! Ganern!", "Walang kupas!"],
    ["Pwede na.", "Pasang-awa.", "Medyo lang, ‘di ba?", "Isang neuron lang ba gumagana?", "Konti na lang!",
     "Hula-hula lang no?", "Sakto lang.", "Hindi masama, hindi rin maganda.", "Kalahating utak, kalahating swerte.",
     "Nag-review ka ba o nag-scroll lang?", "Pwede pa ‘yan galingan.", "Ayos na rin, kesa wala.", "Muntik na!",
     "Eeny meeny miny mo ba ‘yan?", "Tiyaga lang, aabot ka rin.", "Mid ka today, pre."],
    ["Kailangan mo na magkape.", "Kulang sa kiss?", "Ano ba ‘yan?!", "Nag-review ka ba talaga?",
     "Tulog ka ba habang sumasagot?", "Lutang ka na naman.", "Ay, sayang.", "Hala, anyare?", "Utak, nasaan ka?",
     "Kulang sa tulog ‘yan.", "Hindi ka pa kumakain no?", "Mas mataas pa score ng pusa namin.", "Ulitin mo, dali.",
     "Grabe, wala man lang?", "Charot lang ba ‘yan?", "Hay naku, anak.", "Kalimutan na lang natin ‘to."],
  ],
};

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

class Quiz extends StatefulWidget {
  const Quiz({super.key});
  @override
  State<Quiz> createState() => _QuizState();
}

// Most text one quiz may use (about 100 pages). More would take too long to read and make into questions.

class _QuizState extends State<Quiz> {
  int? pick; // which subject (folder)
  final chosen = <Map>{}; // which of its modules go into the quiz
  int count = 10;
  String type = 'mc';
  Map? subject;
  String? moduleName;
  List<Q>? qs;
  final answers = <int, String>{};
  final hints = <int>{};
  final explain = <int, String>{}; // the brain's explanation of a wrong typed answer
  final more = <int, WikiPage>{}; // "More about..." from Wikipedia for wrong answers (online only)
  final _scroll = ScrollController();
  final _cards = <int, GlobalKey>{}; // to scroll to a question (the first blank one)
  final _blank = <int>{}; // questions left blank when "Check" was pressed: highlighted until answered
  bool done = false, review = false;
  bool making = false; // the quiz is being made (long modules take a while)
  String roast = '';

  List<Map> get _folders => [for (final s in store.subjects) if ((s['modules'] as List).isNotEmpty) s];

  // Typed answers are compared loosely: capitals, hyphens, extra spaces, punctuation and a leading "the" don't
  // matter ("CPU." = "cpu", "random access memory" = "Random-access memory").
  String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim()
      .replaceFirst(RegExp(r'^(the|a|an|ang|mga) '), '');

  // An answer removes that question's "no answer yet" mark.
  void _answered(int i, String v) {
    setState(() {
      answers[i] = v;
      if (v.trim().isNotEmpty) _blank.remove(i);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _quit() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(store.t('quit_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(store.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(store.t('quit_quiz'))),
        ],
      ),
    );
    if (yes == true) _reset();
  }
  // Problem solving checks the number instead (within 1%, units allowed: "12 V").
  bool _ok(int i) => qs![i].type == 'solve'
      ? numberOk(answers[i] ?? '', qs![i].answer)
      : _norm(answers[i] ?? '') == _norm(qs![i].answer);
  int get _right => [for (var i = 0; i < qs!.length; i++) if (_ok(i)) i].length;

  // One question from rules.dart's item, or null if it's broken.
  Q? _question(Map m) {
    // The item's own type: rules.dart turns multiple choice into identification when a module has fewer
    // than 4 terms, and fill in the blank into identification when the term isn't in its sentence.
    final t = '${m['type'] ?? type}';
    if (!['mc', 'tf', 'fill', 'id', 'solve'].contains(t) || m['q'] is! String || m['answer'] is! String) return null;
    final q = Q(t, m['q'], t == 'tf' ? _cap(m['answer']) : m['answer'], '${m['why'] ?? ''}', '${m['hint'] ?? ''}',
        topic: ['mc', 'fill', 'id'].contains(t) ? '${m['answer']}' : '${m['topic'] ?? ''}',
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
        Q('match', p.key, p.value, '${p.key}: ${p.value}', '', topic: p.key, choices: meanings, wrong: {
          for (final o in pairs.entries)
            if (o.key != p.key) o.value: '${store.t('meaning_of')} ${o.key}.'
        }),
    ];
  }

  // Gamy builds the quiz himself from the whole module (rules.dart), instantly.
  Future<void> _start(Map folder, List<Map> modules) async {
    final t = store.t;
    // Free plan: not enough quiz items left this week -> show the Pro frame instead.
    if (count > store.itemsLeft) {
      final date = store.refreshText;
      showPro(context,
          '${t('pro_items').replaceFirst('{left}', '${store.itemsLeft}')} ${date.isEmpty ? '' : t('refreshes').replaceFirst('{date}', date)}');
      return;
    }
    // Show "Making your quiz..." first, so long modules don't look frozen.
    setState(() => making = true);
    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;
    try {
      final text = modules.map((m) => m['text'] as String).join('\n');
      final items = type == 'solve' ? solveItems(text, count) : localItems(text, type, count);
      final list = type == 'match' ? _matching(items) : [for (final m in items) ?_question(m)];
      if (list.isEmpty) throw 'bad_quiz';
      // Fewer good questions than asked for: say so instead of padding the quiz with junk.
      if (list.length < count) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(t('fewer').replaceFirst('{n}', '${list.length}'))));
      }
      store.useItems(list.length); // counts toward the free weekly 70
      setState(() {
        subject = folder;
        moduleName = modules.map((m) => m['name']).join(', ');
        qs = list;
        _cards.clear();
        _blank.clear();
        answers.clear();
        hints.clear();
        explain.clear();
        more.clear();
        done = review = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar() // a new message replaces the old one instead of waiting behind it
        ..showSnackBar(
          SnackBar(content: Text(t(e == 'no_facts' || e == 'no_formulas' ? '$e' : 'bad_quiz'))));
    } finally {
      if (mounted) setState(() => making = false);
    }
  }

  void _submit() {
    final t = store.t, n = qs!.length;
    // Every question needs an answer first: say which ones are blank and scroll to the first.
    final blank = [for (var i = 0; i < n; i++) if ((answers[i] ?? '').trim().isEmpty) i];
    if (blank.isNotEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar() // a new message replaces the old one instead of waiting behind it
        ..showSnackBar(
          SnackBar(content: Text(t('answer_all').replaceFirst('{n}', blank.map((i) => i + 1).join(', ')))));
      setState(() => _blank
        ..clear()
        ..addAll(blank));
      final card = _cards[blank.first]?.currentContext;
      if (card != null) Scrollable.ensureVisible(card, duration: const Duration(milliseconds: 300), alignment: 0.1);
      return;
    }
    final r = _right;
    try {
      store.addScore(subject!, {
        'module': moduleName,
        'type': type,
        'right': r,
        'total': n,
        'date': DateTime.now().toIso8601String().substring(0, 10),
      });
    } catch (e) {
      // The score still shows; only the history misses it.
      debugPrint('Score not saved: $e');
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar() // a new message replaces the old one instead of waiting behind it
        ..showSnackBar(SnackBar(content: Text(t('score_not_saved'))));
    }
    final band = r / n >= .8 ? 0 : r / n >= .5 ? 1 : 2; // high, middle, low
    // Blunt or sarcastic, not just sad: smug when he's (grudgingly) impressed or judging you,
    // playful when he's teasing, surprised at a middle score, and sad only now and then.
    const poses = [
      ['smug', 'playful'],
      ['surprised', 'playful'],
      ['smug', 'playful', 'smug', 'playful', 'sad'],
    ];
    final options = poses[band], now = DateTime.now().microsecond;
    store.setMood(1, r == n ? 'smug' : options[now % options.length]);
    final lines = roasts[store.lang]![band];
    setState(() {
      done = true;
      roast = lines[nextLine('${store.lang}$band', lines.length)]; // all lines once before any repeats
    });
    // The score card starts at the top of the page (the student may have scrolled to the last question).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
    _explainWrong();
    _lookUp();
  }

  // For each wrong answer, a short "More about..." from Wikipedia, after the module's own explanation.
  // Tried with the subject's name first ("Latches Cpe"), so the page fits the lesson better.
  Future<void> _lookUp() async {
    final quiz = qs!, subjectName = '${subject?['name'] ?? ''}';
    for (var i = 0; i < quiz.length; i++) {
      final q = quiz[i];
      if (_ok(i) || q.topic.isEmpty) continue;
      final page = await wiki('${q.topic} $subjectName', sentences: 2) ?? await wiki(q.topic, sentences: 2);
      if (!mounted || qs != quiz) return; // the student left this quiz
      if (page == null) continue;
      setState(() => more[i] = page);
    }
  }

  // With the brain on, Gamy explains each wrong typed answer (fill in the blank, identification) in his
  // own words, from the module's sentence. One at a time, in the background, while the student reads the score.
  Future<void> _explainWrong() async {
    final quiz = qs!;
    for (var i = 0; i < quiz.length; i++) {
      final q = quiz[i], a = (answers[i] ?? '').trim();
      if (!brain.ready || !['fill', 'id'].contains(q.type) || a.isEmpty || _ok(i)) continue;
      var text = '';
      try {
        // The joke comes from Gamy's curated lines; the brain only explains, plainly (small models joke badly).
        final low = roasts[store.lang]![2], jab = low[DateTime.now().microsecond % low.length]; // const list: no shuffle
        await for (final w in brain.say(
          'You explain quiz mistakes in one short, plain sentence, using only the module line given.'
              '${store.lang == 'fil' ? ' Reply in Filipino.' : ''}',
          'Module line: ${q.why}\nCorrect answer: ${q.answer}\nStudent answered: $a\n'
              'In one sentence, say why "$a" is wrong.',
          maxTokens: 60,
        )) {
          if (!mounted || qs != quiz) return; // the student left this quiz
          text += w;
          setState(() => explain[i] = '$jab ${cleanReply(text)}');
        }
      } catch (_) {
        return; // the review still works without these
      }
    }
  }

  void _reset() {
    setState(() => qs = null);
    store.setMood(1, 'idle');
  }

  String _show(Q q, String a) => q.type == 'tf' ? store.t(a.toLowerCase()) : a;

  @override
  Widget build(BuildContext context) {
    final t = store.t;
    if (making) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(t('making_quiz')),
        ]),
      );
    }
    if (qs == null) return _setup(t);
    // A Column (not a ListView) so every question is built, and "scroll to the first blank one" can find it.
    return SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (!done)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(onPressed: _quit, icon: const Icon(Icons.close), label: Text(t('quit_quiz'))),
        ),
      if (done)
        // The result fills the screen with everything centered (Gamy, his comment, the score and the buttons);
        // the answer sheet is below it when the student scrolls down.
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: (MediaQuery.sizeOf(context).height - 200).clamp(0, 700)),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // On phones Gamy is hidden during the quiz, so he shows up here: his comment right above his head.
                ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420, maxHeight: 200), child: Bubble(roast)),
                GamySprite(store.moods[1], size: MediaQuery.sizeOf(context).width < 700 ? 140 : 200),
                Text('${t('score')}: $_right / ${qs!.length}',
                    textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                  if (!review) FilledButton(onPressed: () => setState(() => review = true), child: Text(t('review'))),
                  OutlinedButton.icon(
                      onPressed: _reset, icon: const Icon(Icons.arrow_back), label: Text(t('new_quiz'))),
                ]),
                const SizedBox(height: 8),
                Text(t('mistakes'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
              ]),
            ),
          ),
        ),
      if (!done || review)
        for (var i = 0; i < qs!.length; i++) ...[
          // Mixed quiz: a heading at the start of each part ("Part II: True or false")
          if (type == 'mix' && (i == 0 || qs![i].type != qs![i - 1].type))
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
              child: Text(
                '${t('part')} ${const ['I', 'II', 'III', 'IV', 'V'][qs!.take(i + 1).map((q) => q.type).toSet().length - 1]}: '
                '${t(qs![i].type)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          _card(i, t),
        ],
      if (!done) FilledButton(onPressed: _submit, child: Text(t('submit'))),
    ]));
  }

  Widget _card(int i, String Function(String) t) {
    final q = qs![i], a = answers[i], ok = _ok(i);
    final missing = !done && _blank.contains(i); // left blank when "Check" was pressed
    final color = missing ? Colors.red : (!review ? null : (ok ? Colors.green : Colors.red));
    final wrongWhy = q.wrong[a] ?? explain[i];
    return Card(
      key: _cards.putIfAbsent(i, GlobalKey.new),
      shape: color == null
          ? null
          : RoundedRectangleBorder(side: BorderSide(color: color, width: 3), borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${i + 1}. ${q.q}', style: const TextStyle(fontWeight: FontWeight.bold)),
          if (missing) Text(t('no_answer_yet'), style: TextStyle(color: Colors.red.shade700)),
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
                    onSelected: (_) => _answered(i, c),
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
              onChanged: (v) => _answered(i, v!),
            )
          else
            TextField(
              keyboardType: q.type == 'solve' ? const TextInputType.numberWithOptions(decimal: true, signed: true) : null,
              onChanged: (v) {
                answers[i] = v; // no rebuild while typing
                if (_blank.contains(i) && v.trim().isNotEmpty) setState(() => _blank.remove(i));
              },
            ),
          if (!done && !hints.contains(i) && q.hint.isNotEmpty)
            TextButton(onPressed: () => setState(() => hints.add(i)), child: Text(t('hint'))),
          if (!done && hints.contains(i)) Padding(padding: const EdgeInsets.only(top: 8), child: Text('💡 ${q.hint}')),
          // Problem solving always shows its full solution in the review, right or wrong.
          if (review && (!ok || q.type == 'solve')) ...[
            const Divider(),
            if (!ok)
              Text('${t('correct')}: ${_show(q, q.answer)}',
                  style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold)),
            if (q.type == 'solve')
              // Even-width font so the step table's columns line up; it scrolls sideways on phones.
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(q.why,
                    style: const TextStyle(
                        fontFamily: 'monospace', fontFamilyFallback: ['Consolas', 'Courier New'], fontSize: 12, height: 1.4)),
              )
            else
              Text(q.why),
            if (wrongWhy != null && a != null) ...[
              const SizedBox(height: 6),
              Text('${t('your_answer')} (${_show(q, a)}): $wrongWhy', style: TextStyle(color: Colors.red.shade800)),
            ],
            if (more[i] != null) ...[
              const SizedBox(height: 6),
              Text(t('more_about').replaceFirst('{term}', more[i]!.title),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Text(cleanReply(more[i]!.text), style: const TextStyle(fontSize: 12)),
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
    final folders = _folders;
    if (folders.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(t('need_module'), textAlign: TextAlign.center)));
    }
    if (pick != null && pick! >= folders.length) pick = null;
    final folder = pick == null ? null : folders[pick!];
    final mods = folder == null ? const <Map>[] : [for (final m in folder['modules']) m as Map];
    chosen.retainWhere(mods.contains); // forget modules that were deleted
    final picked = [for (final m in mods) if (chosen.contains(m)) m];
    final Iterable scores = folder == null ? const [] : (folder['scores'] as List).reversed.take(5);
    return ListView(padding: const EdgeInsets.all(16), children: [
      // First the subject (folder), then which of its modules
      Text(t('pick_subject')),
      DropdownButton<int>(
        isExpanded: true,
        value: pick,
        items: [
          for (var i = 0; i < folders.length; i++)
            DropdownMenuItem(value: i, child: Text('${folders[i]['name']}', overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (v) => setState(() {
          pick = v;
          chosen.clear();
        }),
      ),
      if (folder != null) ...[
        const SizedBox(height: 12),
        Text(t('pick_modules')),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final m in mods)
            FilterChip(
              label: Text('${m['name']}'),
              selected: chosen.contains(m),
              onSelected: (on) => setState(() => on ? chosen.add(m) : chosen.remove(m)),
            ),
        ]),
      ],
      const SizedBox(height: 16),
      Text(t('pick_type')),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final k in ['mc', 'tf', 'fill', 'id', 'match', 'mix', 'solve'])
          ChoiceChip(
            avatar: !store.pro && _proTypes.contains(k) ? const Icon(Icons.lock, size: 16) : null,
            label: Text(t(k)),
            selected: type == k,
            onSelected: (_) {
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
          ChoiceChip(label: Text('$n'), selected: count == n, onSelected: (_) => setState(() => count = n)),
        // Or type any number; anything above 100 counts as 100.
        SizedBox(
          width: 110,
          child: TextField(
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
      const SizedBox(height: 16),
      FilledButton(onPressed: picked.isEmpty ? null : () => _start(folder!, picked), child: Text(t('start'))),
      if (scores.isNotEmpty) ...[
        const SizedBox(height: 24),
        Text(t('history'), style: const TextStyle(fontWeight: FontWeight.bold)),
        for (final s in scores) Text('${s['date']} • ${s['module']} • ${t(s['type'])}: ${s['right']}/${s['total']}'),
      ],
    ]);
  }
}
