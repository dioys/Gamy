import 'dart:async';

import 'package:flutter/material.dart';

import 'store.dart';

const ink = Color(0xFF2B1D14); // Gamy's outline color

// Moods with more than one drawing are animated by cycling through them.
const _frames = {
  'talk': ['idle', 'talk'],
  'think': ['think_1', 'think_2', 'think_3'],
  'happy': ['happy_1', 'happy_2'],
  'sleep': ['sleep_1', 'sleep_2'],
};
const _speed = {'talk': 160, 'think': 600, 'happy': 500, 'sleep': 900}; // ms per frame

class GamySprite extends StatefulWidget {
  const GamySprite(this.mood, {super.key, this.size = 200});
  final String mood;
  final double size;
  @override
  State<GamySprite> createState() => _GamySpriteState();
}

class _GamySpriteState extends State<GamySprite> {
  Timer? _timer;
  int _i = 0;

  void _restart() {
    _timer?.cancel();
    _i = 0;
    final ms = _speed[widget.mood];
    if (ms != null) _timer = Timer.periodic(Duration(milliseconds: ms), (_) => setState(() => _i++));
  }

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(GamySprite old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood) _restart();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = _frames[widget.mood] ?? [widget.mood];
    return Image.asset('assets/gamy/${f[_i % f.length]}.png', height: widget.size, gaplessPlayback: true);
  }
}

// Gamy "talks": his mouth moves for about as long as it takes to read [text].
Future<void> talk(int tab, String text) async {
  store.setMood(tab, 'talk');
  await Future.delayed(Duration(milliseconds: (text.length * 60).clamp(1200, 15000)));
  if (store.moods[tab] == 'talk') store.setMood(tab, 'idle');
}

// While the student answers, Gamy shares a quote or sings one of his own study jingles.
// (Real song lyrics are copyrighted, so he only sings his own.)
// Famous lines and proverbs (some with Gamy's twist): one shows under his greeting when Chat opens.
const quotes = [
  '"Knowledge is power."\n- Francis Bacon',
  '"Genius is one percent inspiration and ninety-nine percent perspiration."\n- Thomas Edison',
  '"The important thing is not to stop questioning."\n- Albert Einstein',
  '"I have no special talents. I am only passionately curious."\n- Albert Einstein',
  '"Education is the most powerful weapon which you can use to change the world."\n- Nelson Mandela',
  '"Study hard what interests you the most in the most undisciplined, irreverent and original manner possible."\n- Richard Feynman',
  '"Kapag may tiyaga, may nilaga."\n- Filipino proverb',
  '"Ang hindi lumingon sa pinanggalingan ay hindi makararating sa paroroonan."\n- Filipino proverb',
  // Proverbs with Gamy's twist
  '"Kapag may tiyaga, may nilaga. Kapag walang review, may bagsak."\n- Gamy\'s version',
  '"Nasa Diyos ang awa, nasa tao ang gawa. Nasa\'yo ang pag-review."\n- Gamy\'s version',
  '"Ang hindi lumingon sa module ay hindi makakapasa sa exam."\n- Gamy\'s version',
  '"Habang maikli ang kumot, matutong mag-review nang maaga."\n- Gamy\'s version',
  '"Walang mahirap na quiz sa taong matiyagang mag-aral."\n- Gamy\'s version',
  '"Ang tamang sagot ay parang jowa: hinahanap, hindi hinuhulaan."\n- Gamy',
  '"Pag may isinuksok, may madudukot. Pag may ni-review, may maisasagot."\n- Gamy\'s version',
  '"Ang lumalakad nang matulin, kung matinik ay malalim. Basahin mo muna ang tanong."\n- Gamy\'s version',
  '♪ Read it once, then read it twice, getting answers right feels nice ♪\n- Gamy',
  '♪ Don\'t you panic, don\'t you cry, read the question, then reply ♪\n- Gamy',
  '♪ Eyes on the quiz, not on me, I\'m just a bear, as you can see ♪\n- Gamy',
  '♪ Tick, tock, take your time, wrong answers are a bigger crime ♪\n- Gamy',
];

// A comic-style speech bubble: white, thick outline, with a tail pointing down at Gamy.
class Bubble extends StatelessWidget {
  const Bubble(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _BubblePainter(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
          child: SingleChildScrollView(child: Text.rich(_split(text))),
        ),
      );
}

// Gamy's spelling/grammar correction (the line starting with ✏️) shows smaller, below his answer.
TextSpan _split(String text) {
  final i = text.indexOf('✏️');
  return TextSpan(style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ink), children: [
    TextSpan(text: (i < 0 ? text : text.substring(0, i)).trim()),
    if (i >= 0)
      TextSpan(
        text: '\n\n${text.substring(i)}',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, fontStyle: FontStyle.italic, color: Colors.brown.shade700),
      ),
  ]);
}

class _BubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height - 16, mid = size.width / 2;
    final shape = Path.combine(
      PathOperation.union,
      Path()..addRRect(RRect.fromLTRBR(2, 2, size.width - 2, h, const Radius.circular(22))),
      Path()
        ..moveTo(mid - 16, h - 4)
        ..lineTo(mid, size.height - 2)
        ..lineTo(mid + 16, h - 4)
        ..close(),
    );
    canvas.drawPath(shape, Paint()..color = Colors.white);
    canvas.drawPath(shape, Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
