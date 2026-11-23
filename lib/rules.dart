import 'dart:math';

import 'store.dart';

// ----- Gamy's own brain (no AI) -----
// Finds definitions in the module ("X is ...", "X: ...") and turns them into quiz items,
// in the same JSON shape the AI returns, so the quiz screen treats both the same way.

final _rng = Random();

// Sentences about the course or school, ownership notices and people's contact details are never used.
final _skip = RegExp(
    r'@|https?://|www\.|\d{3,4}[- ]\d{3}[- ]\d{4}|\b(semester|course code|instructor|professor|e-?mail|mobile|contact|grading|syllabus'
    r'|property of|copyright|all rights reserved|prepared by|university|college|school|department|campus)\b',
    caseSensitive: false);

// ----- Privacy filter -----
// Removes personal and school details from module text (when it's uploaded) and from everything Gamy says:
// emails, links, phone numbers, school names, and names after titles like "Prof." or "Engr.".
final _private = [
  RegExp(r'\S+@\S+\.\w+'), // emails
  RegExp(r'(https?://|www\.)\S+', caseSensitive: false), // links
  RegExp(r'(\+?63[\s-]?|0)9\d{2}[\s-]?\d{3}[\s-]?\d{4}'), // PH mobile: 0917 123 4567, +63 917-123-4567
  RegExp(r'\(?0\d{1,2}\)?[\s-]?\d{3,4}[\s-]\d{4}\b'), // landline: (02) 8123-4567
  RegExp(r'\b\d{3,4}[- ]\d{3}[- ]\d{4}\b'), // other phone numbers
  // School names: "President Ramon Magsaysay State University", "XYZ COLLEGE OF ENGINEERING"
  RegExp(r"\b(?:[A-Z][\w.'&-]*[ \t]+){0,6}(?:University|UNIVERSITY|College|COLLEGE|School|SCHOOL|Institute|INSTITUTE"
      r"|Academy|ACADEMY|Polytechnic|POLYTECHNIC)\b(?:[ \t]+(?:of|OF)(?:[ \t]+[A-Z][\w.'&-]*){1,4})?"),
  // A teacher's name after a title: "Prof. Juan Dela Cruz", "Engr. Santos".
  // (Not "Dr." or "Sir": modules mention people like Dr. Jose Rizal or Sir Isaac Newton.)
  RegExp(r"\b(?:Prof|Engr)\.?[ \t]+(?:[A-Z][\w.'-]*[ \t]?){1,3}"),
  // Whole lines with a teacher label, in any capitals, with or without a space before the colon:
  // "Instructor: Ana Reyes", "INSTRUCTOR : ...", "Course Facilitator: ...", "Prepared by: ...".
  RegExp(r'^[^\n]*\b(?:instructor|teacher|professor|faculty|advis[eo]r|lecturer|facilitator|prepared by|submitted to'
      r'|checked by|approved by|reviewed by|noted by|written by|author)[ \t]*:[^\n]*',
      multiLine: true, caseSensitive: false),
  // Whole lines with contact details: "FB Account: Dionisio Martin Jr", "Messenger: ...", "Contact No.: ...".
  RegExp(r'^[ \t]*(?:fb|facebook|messenger|gmail|e-?mail|contact|mobile|cell(?:phone)?|phone|tel|telephone|instagram|ig'
      r'|gcash|viber|telegram|twitter|tiktok|youtube)\b[^:\n]{0,20}:[^\n]*',
      multiLine: true, caseSensitive: false),
];

String cleanPrivate(String text) {
  text = plainText(text);
  for (final r in _private) {
    text = text.replaceAll(r, '');
  }
  return text.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
}

// For Gamy's own words: the privacy filter, plus formatting marks the brain sometimes writes
// (**bold**, __bold__, # headings, `code`, -- dashes).
// Turns special characters from PDFs into normal ones: math letters (𝑓, 𝑥, 𝟏) into f, x, 1, special hyphens
// and spaces into normal ones, and ligatures (ﬁ) into letters. Without this, some fonts show a box ("in▯depth"),
// and the formulas can't be read.
String plainText(String s) {
  final out = StringBuffer();
  for (final r in s.runes) {
    if (r >= 0x1D400 && r <= 0x1D6A3) {
      final i = (r - 0x1D400) % 52; // 13 styles (bold, italic...) of A-Z then a-z
      out.writeCharCode(i < 26 ? 0x41 + i : 0x61 + i - 26);
    } else if (r >= 0x1D7CE && r <= 0x1D7FF) {
      out.writeCharCode(0x30 + (r - 0x1D7CE) % 10); // math digits
    } else if (r == 0x210E) {
      out.write('h'); // the italic h lives elsewhere
    } else {
      out.writeCharCode(r);
    }
  }
  return out
      .toString()
      .replaceAll(RegExp('[\u2010\u2011\u2012\u2043]'), '-')
      .replaceAll(RegExp('[\u00A0\u2007\u2009\u200A\u202F]'), ' ')
      .replaceAll(RegExp('[\u00AD\u200B\u200C\u200D\u2060\uFEFF]'), '')
      .replaceAll('ﬁ', 'fi')
      .replaceAll('ﬂ', 'fl')
      .replaceAll('ﬀ', 'ff')
      .replaceAll('ﬃ', 'ffi')
      .replaceAll('ﬄ', 'ffl');
}

String cleanReply(String text) => mathText(cleanPrivate(text))
    .replaceAll(RegExp(r'\*\*|__|`|^#+\s*', multiLine: true), '')
    .replaceAll(RegExp(r'\s*-{2,}\s*'), ' ')
    .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
    .trim();

// ----- Math that reads well (Nov 23: the brain writes LaTeX like "$ p^a q^b $") -----
const _sup = {
  '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴', '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹', '+': '⁺',
  '-': '⁻', '−': '⁻', '=': '⁼', '(': '⁽', ')': '⁾', 'a': 'ᵃ', 'b': 'ᵇ', 'c': 'ᶜ', 'd': 'ᵈ', 'e': 'ᵉ', 'f': 'ᶠ',
  'g': 'ᵍ', 'h': 'ʰ', 'i': 'ⁱ', 'j': 'ʲ', 'k': 'ᵏ', 'l': 'ˡ', 'm': 'ᵐ', 'n': 'ⁿ', 'o': 'ᵒ', 'p': 'ᵖ', 'r': 'ʳ',
  's': 'ˢ', 't': 'ᵗ', 'u': 'ᵘ', 'v': 'ᵛ', 'w': 'ʷ', 'x': 'ˣ', 'y': 'ʸ', 'z': 'ᶻ',
};
const _sub = {
  '0': '₀', '1': '₁', '2': '₂', '3': '₃', '4': '₄', '5': '₅', '6': '₆', '7': '₇', '8': '₈', '9': '₉', 'a': 'ₐ', 'e': 'ₑ',
  'h': 'ₕ', 'i': 'ᵢ', 'j': 'ⱼ', 'k': 'ₖ', 'l': 'ₗ', 'm': 'ₘ', 'n': 'ₙ', 'o': 'ₒ', 'p': 'ₚ', 'r': 'ᵣ', 's': 'ₛ', 't': 'ₜ',
  'u': 'ᵤ', 'v': 'ᵥ', 'x': 'ₓ', '+': '₊', '-': '₋',
};

// Real exponents: "x^2" -> "x²", "e^(-x)" -> "e⁻ˣ", "p^{n+1}" -> "pⁿ⁺¹". Left as is when a character has no
// small version (like "q" or a decimal point), so nothing is ever shown wrong.
String powers(String s) =>
    s.replaceAllMapped(RegExp(r'\^(?:\{([^{}]{1,12})\}|\(([^()]{1,12})\)|(-?\d+(?:\.\d+)?|[A-Za-z]))'), (m) {
      final p = (m[1] ?? m[2] ?? m[3]!).replaceAll(' ', '');
      return p.split('').every(_sup.containsKey) ? p.split('').map((c) => _sup[c]).join() : m[0]!;
    });

// LaTeX the brain (or Wikipedia) writes, as plain readable math: no "$", "\frac", "\cdot"...
String mathText(String s) {
  const words = {
    'cdot': '·', 'times': '×', 'div': '÷', 'leq': '≤', 'le': '≤', 'geq': '≥', 'ge': '≥', 'neq': '≠', 'ne': '≠',
    'pm': '±', 'approx': '≈', 'infty': '∞', 'pi': 'π', 'theta': 'θ', 'alpha': 'α', 'beta': 'β', 'gamma': 'γ',
    'delta': 'δ', 'Delta': 'Δ', 'sigma': 'σ', 'Sigma': 'Σ', 'mu': 'μ', 'lambda': 'λ', 'sum': 'Σ', 'in': '∈',
    'to': '→', 'rightarrow': '→', 'circ': '°', 'ldots': '…', 'dots': '…', 'left': '', 'right': '',
    'cdots': '⋯', 'vdots': '⋮', 'ddots': '⋱', 'phi': 'φ', 'varphi': 'φ', 'Phi': 'Φ', 'psi': 'ψ', 'Psi': 'Ψ',
    'omega': 'ω', 'Omega': 'Ω', 'rho': 'ρ', 'tau': 'τ', 'epsilon': 'ε', 'varepsilon': 'ε', 'eta': 'η', 'kappa': 'κ',
    'nu': 'ν', 'xi': 'ξ', 'chi': 'χ', 'zeta': 'ζ', 'Gamma': 'Γ', 'Lambda': 'Λ', 'Pi': 'Π', 'Theta': 'Θ',
    'prod': 'Π', 'int': '∫', 'partial': '∂', 'nabla': '∇', 'forall': '∀', 'exists': '∃', 'subset': '⊂',
    'subseteq': '⊆', 'cup': '∪', 'cap': '∩', 'emptyset': '∅', 'mid': '|', 'quad': ' ', 'qquad': ' ', 'equiv': '≡',
    'cong': '≅', 'otimes': '⊗', 'oplus': '⊕', 'neg': '¬', 'Rightarrow': '⇒', 'iff': '⇔', 'mapsto': '↦',
  };
  // Matrices: each row on its own line in brackets, "&" as spaces: [a b c]
  s = s.replaceAllMapped(RegExp(r'\\begin\{[pbvB]?matrix\}([\s\S]*?)\\end\{[pbvB]?matrix\}'), (m) {
    final rows = m[1]!.split(r'\\').map((r) => r.replaceAll('&', ' ').replaceAll(RegExp(r'\s+'), ' ').trim());
    return rows.where((r) => r.isNotEmpty).map((r) => '[$r]').join('\n');
  });
  s = s
      .replaceAllMapped(RegExp(r'\$\$\s*([\s\S]{1,800}?)\s*\$\$'), (m) => m[1]!) // a "$$ ... $$" block, even on many lines
      .replaceAllMapped(RegExp(r'\$\s*(?!\d)([^$\n]{1,160}?)\s*\$'), (m) => m[1]!) // "$ x^2 $", not "$5 and $10"
      .replaceAll(RegExp(r'\\[()\[\]]'), '')
      .replaceAllMapped(RegExp(r'\\(?:text|mathrm|mathbf|mathbb|operatorname)\{([^{}]*)\}'), (m) => m[1]!)
      .replaceAllMapped(RegExp(r'\\[dt]?frac\{([^{}]+)\}\{([^{}]+)\}'), (m) => '(${m[1]})/(${m[2]})')
      .replaceAllMapped(RegExp(r'\\sqrt\{([^{}]+)\}'), (m) => '√(${m[1]})')
      .replaceAllMapped(RegExp(r'\\([A-Za-z]+)'), (m) => words[m[1]] ?? (m[1]!.length > 2 ? m[1]! : m[0]!)) // unknown: the word without "\" ("\n" stays)
      .replaceAll(RegExp(r'\\[,;!:]'), ' ')
      .replaceAll(RegExp(r'\$(?!\d) ?'), '') // a "$" left alone (Gamy still writing, or a broken pair); "$5" stays
      // x_1 -> x₁, y_n -> yₙ (after a single letter only, so Python names like file_2 stay)
      .replaceAllMapped(RegExp(r'(?<=(?:^|[^\w])[A-Za-z])_(?:\{([0-9a-z+-]{1,4})\}|([0-9]{1,3}|[a-z]))(?![\w.])'), (m) {
        final p = m[1] ?? m[2]!;
        return p.split('').every(_sub.containsKey) ? p.split('').map((c) => _sub[c]).join() : m[0]!;
      });
  return powers(s);
}

// "Cache memory is a small, fast memory..." -> term + meaning
final _isDef = RegExp(r'^(?:The |An? )?([A-Za-z][\w ()/-]{1,50}?) (?:is defined as|refers to|means|is|are) (.{10,})$',
    caseSensitive: false);
// Tagalog: "Ang puso ay isang organ...", "Ang mga ugat ay tumutukoy sa...", "Ang ibig sabihin ng X ay...".
final _isDefFil = RegExp(
    r'^(?:Ang ibig sabihin ng |Ang (?:mga )?|Si )?([A-Za-zñÑ][\wñÑ ()/-]{1,50}?) ay (?:tumutukoy sa |nangangahulugang )?(.{10,})$',
    caseSensitive: false);
// "Cache memory: a small, fast memory..." (one line)
final _colonDef = RegExp(r'^([A-Z][\w ()/-]{1,40}?)\s*[:–—-]\s+(.{10,})$');
// Labels like "Time: 1:00-2:00PM" or "Chapter 4: Memory" are course info, not terms.
final _label = RegExp(
    r'^(time|date|day|schedule|room|chapter|module|lesson|unit|week|topic|activity|quiz|exam|course'
    r'|subject|teacher|name|year|block|objectives?|references?|note|page)\b',
    caseSensitive: false);
// Whole terms that are labels, headings or contact fields, never real terms ("Direction: Read the following...",
// "FB Account: ..."). Only the whole term: "Direction of current" is still a real term.
final _labelOnly = RegExp(
    r'^(learning modules?|directions?|instructions?|lessons?|tasks?|assessments?|exercises?|examples?|solutions?'
    r'|answers?|score|account|fb( account)?|facebook|messenger|contact|instructor|professor|adviser|facilitator'
    r'|prepared by|submitted to|pre-?test|post-?test|introduction|summary|overview|reminder|remarks)$',
    caseSensitive: false);
// A meaning that is only a person's name, like "Dionisio Martin Jr" or "Ana P. Reyes" (a suffix or a middle
// initial gives it away), is never a definition.
final _personName = RegExp(
    r"^[A-Z][a-zñ'-]+(?: (?:[A-Z][a-zñ'-]+|[A-Z]\.|de|del|dela|delos|de la))* (?:(?:[A-Z]\. )[A-Z][a-zñ'-]+|[A-Z][a-zñ'-]+,? (?:Jr|Sr|II|III|IV)\.?)$");
// Meanings starting with these aren't definitions ("Microprocessors are used in...")
final _weak = RegExp(r'^(used|also|not|very|now|being|often|usually|important|available|able|called|known|shown|given|done|made|based'
    r'|ginagamit|hindi|din|rin|napaka\w*|mahalaga)\b',
    caseSensitive: false);
// Sentences starting with these are not definitions ("It is...", "This is...", "With external systems is...")
final _pronoun = RegExp(
    r'^(it|this|that|these|those|they|there|he|she|we|you|which|what|one|each|all|some|here|where|why|how'
    r'|although|though|however|also|thus|therefore|hence|since|unlike|after|before|during|then|whether|even|yet'
    r'|still|moreover|furthermore|once|until|unless|whereas|besides|meanwhile|instead|otherwise|indeed|finally'
    r'|with|of|in|on|for|to|from|by|and|or|but|as|at|into|so|because|if|when|while'
    r'|ito|iyon|iyan|sila|siya|kami|tayo|kayo|nito|dito|kung|kapag|dahil|at|o|pero)\b',
    caseSensitive: false);
// A real term never has these words inside or at its end. They mean a heading got glued onto a sentence
// ("Microprocessor Systems This", "I/O Interfacing Introduction A microprocessor").
// A pointer to another part of the book, not a fact: "see Figure 3", "Problems 32–36", "the end of the chapter".
final _crossRef = RegExp(
    r'\b(?:problems?|exercises?|examples?|figures?|fig\.|tables?|sections?|chapters?|pages?|equations?|eqs?\.|'
    r'theorems?|lemmas?|propositions?|corollar(?:y|ies)|appendix)\s*\(?(?:\d|[IVX]+\b)|\bend of (?:the |this )?(?:chapter|section|book)',
    caseSensitive: false);
final _glued = RegExp(r'\b(a|an|the|this|that|these|those|it|is|are)\b', caseSensitive: false);

// A line only joins the next one when the sentence clearly continues: it ends with a small letter or comma
// (spaces after it are fine; PDFs often leave them) AND the next line starts with a small letter.
// So headings and labels don't get glued onto real sentences.
List<String> sentences(String text) => text
    .replaceAll(RegExp(r'(?<=[a-z,])[ \t]*\r?\n(?=[ \t]*[a-z0-9(])'), ' ')
    .split(RegExp(r'(?<=[.!?])\s+|\n'))
    .map((s) => s.replaceAll(RegExp(r'\s+'), ' ').trim())
    .where((s) => s.length >= 30 && s.length <= 300 && !_skip.hasMatch(s))
    .toList();

// Smart search pieces: about 3 sentences each (small enough for the search model, big enough to make sense).
List<String> chunks(String text) {
  final s = sentences(text);
  return [for (var i = 0; i < s.length; i += 3) s.skip(i).take(3).join(' ')];
}

typedef _Fact = ({String term, String meaning, String source});

List<_Fact> _facts(String text) {
  final seen = <String>{};
  final out = <_Fact>[];
  void add(String term, String meaning, String source) {
    term = term.trim();
    meaning = meaning.trim().replaceAll(RegExp(r'[.\s]+$'), '');
    if (term.split(' ').length > 5 ||
        meaning.length < 10 ||
        meaning.split(' ').length < 3 ||
        _pronoun.hasMatch(term) ||
        _glued.hasMatch(term) ||
        _label.hasMatch(term) ||
        _labelOnly.hasMatch(term) ||
        _personName.hasMatch(meaning.replaceAll(RegExp(r'[.\s]+$'), '')) ||
        RegExp(r'\d').hasMatch(term) || // "Chapter 4", "BSCpE 3B"
        RegExp(r'\d:\d\d').hasMatch(meaning) || // a time like 1:00
        _weak.hasMatch(meaning) ||
        _crossRef.hasMatch(meaning) || // Nov 23: "left to Problems 32–36 at the end of the chapter"
        !seen.add(term.toLowerCase())) {
      return;
    }
    out.add((term: term, meaning: meaning[0].toUpperCase() + meaning.substring(1), source: source));
  }


  for (final line in text.split('\n')) {
    final l = line.trim(), m = _colonDef.firstMatch(l);
    if (m != null && !_skip.hasMatch(l)) add(m[1]!, m[2]!, l);
  }
  for (final s in sentences(text)) {
    // Only whole sentences: starting with a capital letter and ending with . ! or ?
    // (a cut-off line like "...when the microprocessor executes an" is skipped)
    final m = RegExp(r'^[A-Z].*[.!?]$').hasMatch(s) ? _isDef.firstMatch(s) ?? _isDefFil.firstMatch(s) : null;
    if (m != null) add(m[1]!, m[2]!, s);
  }
  return out; // in module order: localItems spreads its picks over the whole module
}

// A natural true-or-false sentence: the module's own sentence with [meaning] in it
// ("A router is a device that..."), or "Term is meaning." when the module wrote "Term: meaning".
String _statement(_Fact f, String meaning) {
  final m = meaning.length > 1 && meaning[1] == meaning[1].toLowerCase()
      ? meaning[0].toLowerCase() + meaning.substring(1) // "A device that..." -> "a device that..."
      : meaning; // an acronym or a name keeps its capitals
  final at = f.source.toLowerCase().indexOf(f.meaning.toLowerCase());
  final before = at > 0 ? f.source.substring(0, at) : '';
  if (before.isNotEmpty && !before.contains(':')) return '$before$m.';
  return store.t('r_is').replaceFirst('{t}', f.term).replaceFirst('{m}', m);
}

String _fill(String template, Map<String, String> values) =>
    values.entries.fold(template, (s, e) => s.replaceAll('{${e.key}}', e.value));

// Up to [count] quiz items of [type] built from the module text. Throws 'no_facts' if it finds no definitions.
List<Map> localItems(String text, String type, int count) {
  final facts = _facts(text);
  if (facts.isEmpty) throw 'no_facts';
  // Spread the questions over the WHOLE module (not just its first pages): when there are more definitions
  // than questions, take one from each part of the module, then shuffle the order.
  final n = facts.length, c = min(count, n), step = n / c, start = _rng.nextDouble() * step;
  final t = store.t, picked = [for (var i = 0; i < c; i++) facts[(start + i * step).floor().clamp(0, n - 1)]]
    ..shuffle(_rng);
  if (type == 'match') return [for (final f in picked) {'term': f.term, 'meaning': f.meaning}];

  // A mixed quiz is balanced: the types take turns (10 questions with 4 types = 3, 3, 2, 2), in random order.
  // (Multiple choice needs 4 terms to choose from.)
  final kinds = ['tf', 'fill', 'id', if (n >= 4) 'mc']..shuffle(_rng);
  final mixed = [for (var i = 0; i < c; i++) kinds[i % kinds.length]]..shuffle(_rng);
  var turn = 0;

  final items = [
    for (final f in picked)
      () {
        var k = type == 'mix' ? mixed[turn++] : type;
        if (k == 'mc' && facts.length < 4) k = 'id';
        final others = [for (final o in facts) if (o != f) o]..shuffle(_rng);
        final hint = _fill(t('r_hint'), {'c': f.term[0].toUpperCase(), 'n': '${f.term.length}'});
        // Just the description, like most teachers' identification tests ("A device that sends data...").
        final askWhat = RegExp(r'[.?!]$').hasMatch(f.meaning) ? f.meaning : '${f.meaning}.';
        switch (k) {
          case 'mc':
            final wrong = others.take(3).toList();
            return {
              'type': 'mc',
              'q': askWhat,
              'choices': [f.term, for (final o in wrong) o.term]..shuffle(_rng),
              'answer': f.term,
              'why': f.source,
              'hint': hint,
              'wrong': {for (final o in wrong) o.term: _fill(t('r_means'), {'t': o.term, 'm': o.meaning})},
            };
          case 'tf':
            // Half the time, swap in another term's meaning to make a false statement.
            final lie = others.isNotEmpty && _rng.nextBool();
            final shown = lie ? others.first : f;
            return {
              'type': 'tf',
              'q': _statement(f, shown.meaning), // "Blue is the color of blood."
              'answer': lie ? 'False' : 'True',
              'why': _statement(f, f.meaning),
              'hint': '',
              'wrong': lie
                  ? {'True': _fill(t('r_belongs'), {'t': shown.term})}
                  : {'False': t('r_as_is')},
            };
          case 'fill':
            final blanked = f.source.replaceFirst(RegExp(RegExp.escape(f.term), caseSensitive: false), '____');
            if (blanked != f.source) {
              return {'type': 'fill', 'q': blanked, 'answer': f.term, 'why': f.source, 'hint': hint};
            }
        }
        // 'id', or a fill-in whose sentence doesn't contain the term
        return {'type': 'id', 'q': askWhat, 'answer': f.term, 'why': f.source, 'hint': hint};
      }(),
  ];
  // A mixed quiz is grouped into parts like a printed exam: identification first, then true or false,
  // multiple choice, and fill in the blank (the quiz screen shows a heading for each part).
  if (type == 'mix') items.sort((a, b) => mixOrder.indexOf('${a['type']}').compareTo(mixOrder.indexOf('${b['type']}')));
  return items;
}

const mixOrder = ['id', 'tf', 'mc', 'fill'];

// ----- Chat without AI: find the module sentences that best match the question -----
const _stop = {
  'what', 'when', 'where', 'which', 'with', 'that', 'this', 'there', 'their', 'about', 'does', 'have', 'from',
  'into', 'your', 'mean', 'means', 'explain', 'tell', 'gamy', 'paano', 'bakit', 'saan', 'kailan', 'anong', 'yung', 'para',
};

typedef Line = ({int score, String text, String module});

// The [n] module sentences that share the most words with the question (best first).
// null means the question has no real words to look for.
// The question's important words, without common endings, so "supervise" also finds "supervised"
// and "learning" finds "learn".
Set<String> _words(String question) => RegExp(r'[\p{L}\p{N}]{4,}', unicode: true)
    .allMatches(question.toLowerCase())
    .map((m) => m[0]!)
    .where((w) => !_stop.contains(w))
    .map((w) => w.length > 5 ? w.replaceFirst(RegExp(r'(ing|ed|es|s)$'), '') : w)
    .toSet();

List<Line>? bestLines(String question, List<Map> modules, int n) {
  final words = _words(question);
  if (words.isEmpty) return null;
  final found = <Line>[];
  for (final m in modules) {
    for (final s in sentences(m['text'] as String)) {
      final low = s.toLowerCase(), k = words.where(low.contains).length;
      if (k > 0) found.add((score: k, text: s, module: '${m['name']}'));
    }
  }
  found.sort((a, b) => b.score.compareTo(a.score));
  return found.take(n).toList();
}

// Whether keyword search really found the answer: one module line has ALL the question's important words
// (when there are 1 to 3), or at least two thirds of them. One shared word like "learning" isn't enough;
// then Gamy looks it up on Wikipedia instead of answering from an unrelated line.
bool keywordsAnswer(String question, List<Line>? lines) {
  final n = _words(question).length;
  return lines != null && lines.isNotEmpty && lines.first.score >= (n <= 3 ? n : (n * 2 / 3).ceil());
}

// Chat without the brain: quote the 2 best sentences.
String findAnswer(String question, List<Map> modules) {
  final t = store.t, top = bestLines(question, modules, 2);
  if (top == null) return t('r_ask_more');
  if (top.isEmpty) return t('r_not_found');
  final intro = t('r_found_${_rng.nextInt(3)}');
  return cleanReply('$intro\n\n${top.map((e) => '"${e.text}"').join('\n\n')}');
}
