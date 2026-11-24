part of 'algebra.dart';

// ----- Statistics and probability (Nov 24). Decimal answers are checked within 1%, so normal rounding is fine.
// Left out for now: percentiles (books use different formulas, so one "right" answer would be unfair).

List<int> _data(int n, int lo, int hi) => [for (var i = 0; i < n; i++) _in(lo, hi)];
String _list(List<num> v) => v.map((x) => _dec(x)).join(', ');
double _mean(List<num> v) => v.fold<double>(0, (a, b) => a + b) / v.length; // (reduce fails on a List<int>)
double _squares(List<num> v) {
  final m = _mean(v);
  return v.fold(0.0, (s, x) => s + (x - m) * (x - m));
}

int _fact(int n) => n <= 1 ? 1 : n * _fact(n - 1);
int _choose(int n, int k) {
  var c = 1;
  for (var i = 1; i <= k; i++) {
    c = c * (n - k + i) ~/ i;
  }
  return c;
}

// The area under the standard normal curve to the left of z (what a z-table gives).
double _phi(double z) {
  final x = z.abs() / sqrt2, t = 1 / (1 + .3275911 * x);
  final erf = 1 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - .284496736) * t + .254829592) * t * exp(-x * x);
  return z >= 0 ? (1 + erf) / 2 : (1 - erf) / 2;
}

double _table(double z) => double.parse(_phi(z).toStringAsFixed(4)); // a z-table has 4 decimal places
double _z2(double z) => double.parse(z.toStringAsFixed(2)); // z-tables are read with 2 decimal places

String get _twoPlaces => _l('to 2 decimal places', 'hanggang 2 decimal places');
String get _fourPlaces => _l('to 4 decimal places', 'hanggang 4 decimal places');

// ----- Mean, median and mode -----
Map? _center(int level) {
  if (level == 1) {
    final v = _data(_in(5, 8), 10, 60), m = _mean(v);
    return {
      'q': '${_l('Find the mean of', 'Hanapin ang mean ng')}: ${_list(v)} ($_twoPlaces).',
      'answer': _dec(m),
      'hint': _l('Add them all, then divide by how many there are.', 'Pagsamahin lahat, tapos i-divide sa dami nila.'),
      'why': 'mean = (${v.join(' + ')}) / ${v.length} = ${v.reduce((a, b) => a + b)} / ${v.length} = ${_dec(m)}',
    };
  }
  if (level == 2) {
    final v = _data(_pick(const [6, 8]), 5, 95), s = [...v]..sort(), n = s.length, med = (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
    return {
      'q': '${_l('Find the median of', 'Hanapin ang median ng')}: ${_list(v)}.',
      'answer': _dec(med),
      'hint': _l('Sort them first. With an even count, average the two in the middle.',
          'Ayusin muna. Kapag even ang dami, kunin ang average ng dalawang nasa gitna.'),
      'why': '${_l('Sorted', 'Nakaayos')}: ${_list(s)}\n'
          '${_l('Even count', 'Even ang dami')} ($n): (${s[n ~/ 2 - 1]} + ${s[n ~/ 2]}) / 2 = ${_dec(med)}',
    };
  }
  final n = _in(4, 6), grades = _data(n, 75, 98), units = _data(n, 1, 5);
  final top = [for (var i = 0; i < n; i++) grades[i] * units[i]].reduce((a, b) => a + b), all = units.reduce((a, b) => a + b);
  return {
    'q': '${_l("A student's grades and units", 'Mga grade at units ng isang estudyante')}: '
        '${[for (var i = 0; i < n; i++) '${grades[i]} (${units[i]} ${_l('units', 'units')})'].join(', ')}. '
        '${_l('Find the weighted mean', 'Hanapin ang weighted mean')} ($_twoPlaces).',
    'answer': _dec(top / all),
    'hint': _l('Multiply each grade by its units, add them, then divide by the total units.',
        'I-multiply ang bawat grade sa units nito, pagsamahin, tapos i-divide sa kabuuang units.'),
    'why': '(${[for (var i = 0; i < n; i++) '${grades[i]}×${units[i]}'].join(' + ')}) / ($all) = $top / $all = ${_dec(top / all)}',
  };
}

// ----- Variance and standard deviation -----
Map? _spread(int level) {
  final v = level == 1 ? _data(5, 1, 20) : _data(6, 10, 40), m = _mean(v), ss = _squares(v);
  if (ss == 0) return null;
  final steps = [
    '${_l('Mean', 'Mean')} = ${_dec(m)}',
    '${_l('Squared distances from the mean', 'Squared na layo mula sa mean')}: ${v.map((x) => _dec((x - m) * (x - m))).join(' + ')} = ${_dec(ss)}',
  ];
  if (level == 1) {
    final variance = ss / v.length;
    return {
      'q': '${_l('Find the population variance of', 'Hanapin ang population variance ng')}: ${_list(v)} ($_twoPlaces).',
      'answer': _dec(variance),
      'hint': 'σ² = Σ(x − μ)² / N',
      'why': [...steps, 'σ² = ${_dec(ss)} / ${v.length} = ${_dec(variance)}'].join('\n'),
    };
  }
  final s = sqrt(ss / (v.length - 1));
  if (level == 2) {
    return {
      'q': '${_l('Find the sample standard deviation of', 'Hanapin ang sample standard deviation ng')}: ${_list(v)} ($_twoPlaces).',
      'answer': _dec(s),
      'hint': 's = √(Σ(x − x̄)² / (n − 1))',
      'why': [...steps, 's = √(${_dec(ss)} / ${v.length - 1}) = ${_dec(s)}'].join('\n'),
    };
  }
  final cv = s / m * 100;
  return {
    'q': '${_l('Find the coefficient of variation (in %) of the sample', 'Hanapin ang coefficient of variation (sa %) ng sample')}: '
        '${_list(v)} ($_twoPlaces).',
    'answer': _dec(cv),
    'hint': 'CV = s / x̄ × 100%',
    'why': [...steps, 's = √(${_dec(ss)} / ${v.length - 1}) = ${_dec(s, 4)}', 'CV = ${_dec(s, 4)} / ${_dec(m, 4)} × 100 = ${_dec(cv)}%']
        .join('\n'),
  };
}

// ----- z-scores -----
Map? _zScore(int level) {
  final mu = _in(50, 90), sigma = _in(3, 15);
  if (level == 1) {
    final x = mu + _nz(-2 * sigma, 2 * sigma), z = (x - mu) / sigma;
    return {
      'q': '${_l('Scores have mean', 'Ang mga score ay may mean na')} $mu ${_l('and standard deviation', 'at standard deviation na')} $sigma. '
          '${_l('Find the z-score of', 'Hanapin ang z-score ng')} $x ($_twoPlaces).',
      'answer': _dec(z),
      'hint': 'z = (x − μ) / σ',
      'why': 'z = ($x − $mu) / $sigma = ${_dec(z)}',
    };
  }
  final z = _nz(-10, 10) / 4;
  if (level == 2) {
    final x = mu + z * sigma;
    return {
      'q': '${_l('Scores have mean', 'Ang mga score ay may mean na')} $mu ${_l('and standard deviation', 'at standard deviation na')} $sigma. '
          '${_l('What score has a z-score of', 'Anong score ang may z-score na')} ${_dec(z)}?',
      'answer': _dec(x),
      'hint': 'x = μ + zσ',
      'why': 'x = $mu + (${_dec(z)})($sigma) = ${_dec(x)}',
    };
  }
  final x = mu + z * sigma;
  return {
    'q': '${_l('A score of', 'Ang score na')} ${_dec(x)} ${_l('has a z-score of', 'ay may z-score na')} ${_dec(z)} '
        '${_l('in a group with mean', 'sa grupong may mean na')} $mu. ${_l('Find the standard deviation', 'Hanapin ang standard deviation')}.',
    'answer': '$sigma',
    'hint': _l('Solve z = (x − μ) / σ for σ.', 'Lutasin ang σ sa z = (x − μ) / σ.'),
    'why': 'σ = (x − μ) / z = (${_dec(x)} − $mu) / ${_dec(z)} = $sigma',
  };
}

// ----- Probability -----
Map? _probability(int level) {
  if (level == 1) {
    final counts = {_l('red', 'pula'): _in(1, 12), _l('blue', 'asul'): _in(1, 12), _l('green', 'berde'): _in(1, 12)};
    final total = counts.values.reduce((a, b) => a + b), color = _pick(counts.keys.toList()), p = _r(counts[color]!, total);
    return {
      'q': '${_l('A bag has', 'Ang bag ay may')} ${counts.entries.map((e) => '${e.value} ${e.key}').join(', ')} '
          '${_l('marbles. One is picked at random. What is the probability that it is', 'na marbles. Isa ang kinuha nang random. Ano ang probability na ito ay')} $color?',
      'answer': '$p',
      'hint': _l('Probability = favorable outcomes ÷ all outcomes.', 'Probability = favorable outcomes ÷ lahat ng outcomes.'),
      'why': 'P = ${counts[color]} / $total${p.d != total ? ' = ${p.show}' : ''}',
    };
  }
  if (level == 2) {
    // Two dice, addition rule: P(A or B) = P(A) + P(B) − P(A and B)
    final s = _in(6, 10), k = _in(1, 6), doubles = _rng.nextBool();
    bool a(int x, int y) => x + y > s;
    bool b(int x, int y) => doubles ? x == y : x == k || y == k;
    var na = 0, nb = 0, both = 0;
    for (var x = 1; x <= 6; x++) {
      for (var y = 1; y <= 6; y++) {
        if (a(x, y)) na++;
        if (b(x, y)) nb++;
        if (a(x, y) && b(x, y)) both++;
      }
    }
    final p = _r(na + nb - both, 36);
    final bText = doubles ? _l('both dice show the same number', 'pareho ang numero ng dalawang dice') : _l('at least one die shows $k', 'may $k sa kahit isang dice');
    return {
      'q': '${_l('Two dice are rolled. What is the probability that the sum is greater than', 'Dalawang dice ang inihagis. Ano ang probability na ang sum ay higit sa')} $s '
          '${_l('or', 'o')} $bText?',
      'answer': '$p',
      'hint': _l('P(A or B) = P(A) + P(B) − P(A and B). There are 36 outcomes.',
          'P(A o B) = P(A) + P(B) − P(A at B). May 36 na outcomes.'),
      'why': 'P = $na/36 + $nb/36 − $both/36 = ${na + nb - both}/36${p.d != 36 ? ' = ${p.show}' : ''}',
    };
  }
  final r = _in(3, 8), b = _in(3, 8), n = r + b, same = _rng.nextBool();
  final p = same ? _r(r * (r - 1), n * (n - 1)) : _r(2 * r * b, n * (n - 1));
  return {
    'q': '${_l('A box has', 'Ang kahon ay may')} $r ${_l('red and', 'pula at')} $b ${_l('blue balls. Two are drawn without replacement. What is the probability of', 'asul na bola. Dalawa ang kinuha nang hindi ibinabalik. Ano ang probability na')} '
        '${same ? _l('getting two red balls', 'parehong pula') : _l('getting one of each color', 'isa sa bawat kulay')}?',
    'answer': '$p',
    'hint': _l('Multiply along the draws: after the first draw there is one ball fewer.',
        'I-multiply sa bawat kuha: pagkatapos ng unang kuha, kulang na ng isa ang bola.'),
    'why': same
        ? 'P = $r/$n × ${r - 1}/${n - 1} = ${p.show}'
        : 'P = $r/$n × $b/${n - 1} + $b/$n × $r/${n - 1} = ${p.show}',
  };
}

// ----- Permutations and combinations -----
Map? _counting(int level) {
  if (level == 1) {
    final n = _in(4, 8);
    return {
      'q': '${_l('In how many ways can', 'Sa ilang paraan maaayos ang')} $n ${_l('different books be arranged on a shelf?', 'magkakaibang libro sa isang shelf?')}',
      'answer': '${_fact(n)}',
      'hint': 'n!',
      'why': '$n! = ${[for (var i = n; i >= 1; i--) i].join(' × ')} = ${_fact(n)}',
    };
  }
  if (level == 2) {
    final n = _in(6, 15), r = _in(2, 4), v = _fact(n) ~/ _fact(n - r);
    final roles = [_l('president', 'president'), _l('vice president', 'vice president'), _l('secretary', 'secretary'), _l('treasurer', 'treasurer')]
        .take(r)
        .join(', ');
    return {
      'q': '${_l('A club has', 'Ang club ay may')} $n ${_l('members. In how many ways can they choose a', 'na miyembro. Sa ilang paraan sila makakapili ng')} $roles '
          '(${_l('one person per role', 'isang tao bawat posisyon')})?',
      'answer': '$v',
      'hint': _l('Order matters: nPr = n! / (n − r)!', 'Mahalaga ang ayos: nPr = n! / (n − r)!'),
      'why': '${n}P$r = $n! / ${n - r}! = ${[for (var i = n; i > n - r; i--) i].join(' × ')} = $v',
    };
  }
  final m = _in(4, 9), w = _in(3, 8), size = _in(3, 5), k = _in(1, min(w, size));
  if (size - k > m) return null;
  final v = _choose(w, k) * _choose(m, size - k);
  return {
    'q': '${_l('A committee of', 'Isang komite ng')} $size ${_l('is chosen from', 'ang pipiliin mula sa')} $m ${_l('men and', 'lalaki at')} $w '
        '${_l('women. How many committees have exactly', 'babae. Ilang komite ang may eksaktong')} $k ${_l(k == 1 ? 'woman' : 'women', 'babae')}?',
    'answer': '$v',
    'hint': _l('Choose the women and the men separately (order doesn\'t matter), then multiply.',
        'Piliin nang hiwalay ang mga babae at lalaki (hindi mahalaga ang ayos), tapos i-multiply.'),
    'why': '${w}C$k × ${m}C${size - k} = ${_choose(w, k)} × ${_choose(m, size - k)} = $v',
  };
}

// ----- Expected value -----
Map? _expected(int level) {
  if (level == 1) {
    final n = _in(2, 10), win = _in(2, 20) * 10, cost = _in(1, 10) * 5, e = _r(win, n) - _r(cost);
    return {
      'q': '${_l('A game costs', 'Ang laro ay nagkakahalaga ng')} ₱$cost. ${_l('You win', 'Mananalo ka ng')} ₱$win '
          '${_l('with probability', 'na may probability na')} 1/$n, ${_l('and nothing otherwise. What is the expected gain? (Negative means a loss.)', 'at wala kung hindi. Ano ang expected gain? (Negative ay talo.)')}',
      'answer': '$e',
      'hint': _l('E = (prize × its probability) − cost.', 'E = (premyo × probability nito) − bayad.'),
      'why': 'E = $win × 1/$n − $cost = ${e.show}${e.whole ? '' : ' ≈ ${_dec(e.n / e.d)}'}',
    };
  }
  // A probability table for X = 0, 1, 2, 3 (tenths that add to 1)
  final cuts = ([_in(1, 9), _in(1, 9), _in(1, 9)]..sort());
  final p = [cuts[0], cuts[1] - cuts[0], cuts[2] - cuts[1], 10 - cuts[2]].map((v) => v / 10).toList();
  if (p.any((v) => v == 0)) return null;
  final mu = [for (var x = 0; x < 4; x++) x * p[x]].reduce((a, b) => a + b);
  final table = [for (var x = 0; x < 4; x++) 'P(X = $x) = ${_dec(p[x], 1)}'].join(', ');
  if (level == 2) {
    return {
      'q': '${_l('Find the expected value of X', 'Hanapin ang expected value ng X')}: $table.',
      'answer': _dec(mu),
      'hint': 'E(X) = Σ x · P(x)',
      'why': 'E(X) = ${[for (var x = 0; x < 4; x++) '$x(${_dec(p[x], 1)})'].join(' + ')} = ${_dec(mu)}',
    };
  }
  final ex2 = [for (var x = 0; x < 4; x++) x * x * p[x]].reduce((a, b) => a + b), variance = ex2 - mu * mu;
  return {
    'q': '${_l('Find the variance of X', 'Hanapin ang variance ng X')}: $table ($_twoPlaces).',
    'answer': _dec(variance),
    'hint': 'Var(X) = Σ x² · P(x) − μ²',
    'why': 'μ = ${_dec(mu)}\nΣ x² · P(x) = ${_dec(ex2)}\nVar(X) = ${_dec(ex2)} − ${_dec(mu)}² = ${_dec(variance)}',
  };
}

// ----- Binomial distribution -----
double _bin(int n, int k, double p) => (_choose(n, k) * pow(p, k) * pow(1 - p, n - k)).toDouble();

Map? _binomial(int level) {
  final n = level == 3 ? _in(8, 15) : _in(5, 10), p = _pick(const [.1, .2, .25, .3, .4, .5, .6, .7, .75, .8]);
  final intro = '${_l('A trial succeeds with probability', 'Ang isang trial ay nagtatagumpay na may probability na')} $p. '
      '${_l('It is done', 'Ginagawa ito nang')} $n ${_l('times', 'beses')}.';
  if (level == 1) {
    final k = (n * p).round() + _in(-1, 1);
    if (k < 0 || k > n) return null;
    final v = _bin(n, k, p);
    if (v < .02) return null;
    return {
      'q': '$intro ${_l('Find P(exactly', 'Hanapin ang P(eksaktong')} $k ${_l('successes)', 'tagumpay)')} ($_fourPlaces).',
      'answer': _dec(v, 4),
      'hint': 'P(X = k) = nCk · pᵏ · (1 − p)ⁿ⁻ᵏ',
      'why': 'P(X = $k) = ${n}C$k · $p^$k · ${_dec(1 - p)}^${n - k} = ${_choose(n, k)} × ${_dec(pow(p, k), 6)} × ${_dec(pow(1 - p, n - k), 6)} = ${_dec(v, 4)}',
    };
  }
  final k = _in(1, 3), below = [for (var i = 0; i <= (level == 2 ? k : k - 1); i++) _bin(n, i, p)];
  final sum = below.reduce((a, b) => a + b), v = level == 2 ? sum : 1 - sum;
  if (v < .02 || v > .995) return null;
  final terms = [for (var i = 0; i < below.length; i++) 'P($i) = ${_dec(below[i], 4)}'].join(', ');
  return {
    'q': '$intro ${level == 2 ? _l('Find P(at most', 'Hanapin ang P(hindi hihigit sa') : _l('Find P(at least', 'Hanapin ang P(hindi bababa sa')} '
        '$k ${_l('successes)', 'tagumpay)')} ($_fourPlaces).',
    'answer': _dec(v, 4),
    'hint': level == 2
        ? _l('Add P(0) up to P(k).', 'Pagsamahin ang P(0) hanggang P(k).')
        : _l('Use the complement: 1 − P(fewer than k).', 'Gamitin ang complement: 1 − P(kulang sa k).'),
    'why': '$terms\n${level == 2 ? 'P(X ≤ $k) = ${_dec(sum, 4)}' : 'P(X ≥ $k) = 1 − ${_dec(sum, 4)} = ${_dec(v, 4)}'}',
  };
}

// ----- Poisson distribution -----
double _poi(double lambda, int k) => pow(lambda, k) * exp(-lambda) / _fact(k);

Map? _poisson(int level) {
  var lambda = _pick(const [1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0]);
  var intro = '${_l('Calls arrive at an average of', 'Dumarating ang tawag sa average na')} ${_dec(lambda, 1)} '
      '${_l('per minute', 'bawat minuto')}.';
  var setup = '';
  if (level == 3) {
    final rate = _pick(const [2, 3, 4, 5, 6]), hours = _pick(const [.5, 1.5, 2.0, 3.0]);
    lambda = rate * hours;
    intro = '${_l('A shop gets an average of', 'Ang tindahan ay may average na')} $rate ${_l('customers per hour', 'customer bawat oras')}. '
        '${_l('Look at a', 'Tingnan ang')} ${_dec(hours, 1)}${_l('-hour period', ' oras')}.';
    setup = 'λ = $rate × ${_dec(hours, 1)} = ${_dec(lambda, 1)}\n';
  }
  final k = level == 2 ? _in(1, 3) : _in(0, 6), parts = [for (var i = level == 2 ? 0 : k; i <= k; i++) _poi(lambda, i)];
  final v = parts.reduce((a, b) => a + b);
  if (v < .02 || v > .995) return null;
  return {
    'q': '$intro ${level == 2 ? _l('Find P(at most', 'Hanapin ang P(hindi hihigit sa') : _l('Find P(exactly', 'Hanapin ang P(eksaktong')} '
        '$k) ($_fourPlaces).',
    'answer': _dec(v, 4),
    'hint': 'P(X = k) = λᵏ e^(−λ) / k!',
    'why': '$setup${[for (var i = 0; i < parts.length; i++) 'P(${(level == 2 ? 0 : k) + i}) = ${_dec(parts[i], 4)}'].join(', ')}'
        '${level == 2 ? '\nP(X ≤ $k) = ${_dec(v, 4)}' : ''}',
  };
}

// ----- Normal distribution -----
Map? _normal(int level) {
  if (level == 1) {
    final z = _nz(-250, 250) / 100, less = _rng.nextBool(), v = less ? _table(z) : 1 - _table(z);
    return {
      'q': '${_l('For the standard normal distribution, find', 'Sa standard normal distribution, hanapin ang')} P(Z ${less ? '<' : '>'} ${_dec(z)}) ($_fourPlaces).',
      'answer': _dec(v, 4),
      'hint': _l('The z-table gives the area to the left of z. For "greater than", subtract from 1.',
          'Ang z-table ay nagbibigay ng area sa kaliwa ng z. Para sa "greater than", ibawas sa 1.'),
      'why': less ? 'P(Z < ${_dec(z)}) = ${_dec(v, 4)}' : 'P(Z > ${_dec(z)}) = 1 − ${_dec(_table(z), 4)} = ${_dec(v, 4)}',
    };
  }
  final mu = _in(10, 20) * 5, sigma = _pick(const [4, 5, 8, 10, 12, 15, 20]);
  if (level == 2) {
    final a = mu - _in(1, 2 * sigma), b = mu + _in(1, 2 * sigma), z1 = _z2((a - mu) / sigma), z2 = _z2((b - mu) / sigma);
    final v = _table(z2) - _table(z1);
    return {
      'q': '${_l('Scores are normal with mean', 'Ang mga score ay normal na may mean na')} $mu ${_l('and standard deviation', 'at standard deviation na')} $sigma. '
          '${_l('Find P(', 'Hanapin ang P(')}$a < X < $b) ($_fourPlaces).',
      'answer': _dec(v, 4),
      'hint': _l('Change both values to z-scores, then subtract the table areas.', 'Gawing z-score ang dalawang value, tapos ibawas ang mga area sa table.'),
      'why': 'z₁ = ($a − $mu) / $sigma = ${_dec(z1)}, z₂ = ($b − $mu) / $sigma = ${_dec(z2)}\n'
          'P = ${_dec(_table(z2), 4)} − ${_dec(_table(z1), 4)} = ${_dec(v, 4)}',
    };
  }
  const zFor = {10: 1.28, 5: 1.645, 1: 2.33, 20: .84, 25: .67};
  final pct = _pick(zFor.keys.toList()), top = _rng.nextBool(), z = zFor[pct]!, x = mu + (top ? z : -z) * sigma;
  return {
    'q': '${_l('Scores are normal with mean', 'Ang mga score ay normal na may mean na')} $mu ${_l('and standard deviation', 'at standard deviation na')} $sigma. '
        '${_l('What score marks the', 'Anong score ang hangganan ng')} ${top ? _l('top', 'pinakamataas na') : _l('bottom', 'pinakamababang')} $pct%? ($_twoPlaces)',
    'answer': _dec(x),
    'hint': _l('Find the z with that area in the table, then x = μ + zσ.', 'Hanapin sa table ang z na may ganoong area, tapos x = μ + zσ.'),
    'why': 'z = ${top ? '' : '−'}$z\nx = $mu ${top ? '+' : '−'} $z × $sigma = ${_dec(x)}',
  };
}

// ----- Confidence intervals -----
const _zStar = {90: 1.645, 95: 1.96, 99: 2.576};

Map? _interval(int level) {
  final conf = _pick(_zStar.keys.toList()), z = _zStar[conf]!;
  if (level < 3) {
    final sigma = _in(5, 30), n = _pick(const [25, 36, 49, 64, 81, 100]), mean = _in(40, 90) + _in(0, 9) / 10, e = z * sigma / sqrt(n);
    final intro = '${_l('A sample of', 'Isang sample ng')} $n ${_l('has mean', 'ay may mean na')} ${_dec(mean, 1)}; '
        '${_l('the population standard deviation is', 'ang population standard deviation ay')} $sigma.';
    final margin = 'E = z* · σ/√n = $z × $sigma / √$n = $z × $sigma / ${sqrt(n).round()} = ${_dec(e)}';
    if (level == 1) {
      return {
        'q': '$intro ${_l('Find the margin of error for a', 'Hanapin ang margin of error para sa')} $conf% ${_l('confidence interval', 'confidence interval')} ($_twoPlaces).',
        'answer': _dec(e),
        'hint': 'E = z* · σ/√n ($conf%: z* = $z)',
        'why': margin,
      };
    }
    return {
      'q': '$intro ${_l('Find the', 'Hanapin ang')} $conf% ${_l('confidence interval for the mean', 'confidence interval para sa mean')} ($_twoPlaces). '
          '${_l('Answer as (lower, upper)', 'Isagot bilang (lower, upper)')}.',
      'answer': '(${_dec(mean - e)}, ${_dec(mean + e)})',
      'check': 'pair',
      'hint': 'x̄ ± z* · σ/√n ($conf%: z* = $z)',
      'why': '$margin\n${_dec(mean, 1)} ± ${_dec(e)} = (${_dec(mean - e)}, ${_dec(mean + e)})',
    };
  }
  final n = _in(10, 50) * 10, x = (n * (_in(20, 80) / 100)).round(), p = x / n, e = z * sqrt(p * (1 - p) / n);
  return {
    'q': '${_l('In a survey of', 'Sa survey ng')} $n ${_l('students,', 'estudyante,')} $x ${_l('said yes. Find the', 'ang sumagot ng oo. Hanapin ang')} $conf% '
        '${_l('confidence interval for the proportion', 'confidence interval para sa proportion')} ($_fourPlaces). ${_l('Answer as (lower, upper)', 'Isagot bilang (lower, upper)')}.',
    'answer': '(${_dec(p - e, 4)}, ${_dec(p + e, 4)})',
    'check': 'pair',
    'hint': 'p̂ ± z* · √(p̂(1 − p̂)/n) ($conf%: z* = $z)',
    'why': 'p̂ = $x/$n = ${_dec(p, 4)}\nE = $z × √(${_dec(p, 4)} × ${_dec(1 - p, 4)} / $n) = ${_dec(e, 4)}\n'
        '(${_dec(p - e, 4)}, ${_dec(p + e, 4)})',
  };
}

// ----- Hypothesis tests: the test statistic -----
Map? _hypothesis(int level) {
  final mu0 = _in(40, 90);
  if (level < 3) {
    final n = _pick(const [16, 25, 36, 49, 64]), sd = _in(5, 20), mean = mu0 + _nz(-30, 30) / 10 * sd / sqrt(n) * 1.0;
    final xbar = double.parse(mean.toStringAsFixed(1)), t = (xbar - mu0) / (sd / sqrt(n));
    if (t.abs() < .5) return null;
    final name = level == 1 ? 'z' : 't', sym = level == 1 ? 'σ' : 's';
    return {
      'q': '${_l('Test H₀: μ =', 'I-test ang H₀: μ =')} $mu0. ${_l('A sample of', 'Isang sample ng')} $n ${_l('has mean', 'ay may mean na')} ${_dec(xbar, 1)}'
          '${level == 1 ? _l('; the population standard deviation is', '; ang population standard deviation ay') : _l(' and sample standard deviation', ' at sample standard deviation na')} $sd. '
          '${_l('Find the test statistic', 'Hanapin ang test statistic')} $name ($_twoPlaces).',
      'answer': _dec(t),
      'hint': '$name = (x̄ − μ₀) / ($sym/√n)',
      'why': '$name = (${_dec(xbar, 1)} − $mu0) / ($sd/√$n) = ${_dec(xbar - mu0, 1)} / ${_dec(sd / sqrt(n), 4)} = ${_dec(t)}',
    };
  }
  final v = _data(_in(6, 8), mu0 - 12, mu0 + 12), m = _mean(v), s = sqrt(_squares(v) / (v.length - 1));
  if (s == 0) return null;
  final t = (m - mu0) / (s / sqrt(v.length));
  return {
    'q': '${_l('Test H₀: μ =', 'I-test ang H₀: μ =')} $mu0 ${_l('with this sample', 'gamit ang sample na ito')}: ${_list(v)}. '
        '${_l('Find the t statistic', 'Hanapin ang t statistic')} ($_twoPlaces).',
    'answer': _dec(t),
    'hint': _l('Find x̄ and s first, then t = (x̄ − μ₀) / (s/√n).', 'Hanapin muna ang x̄ at s, tapos t = (x̄ − μ₀) / (s/√n).'),
    'why': 'x̄ = ${_dec(m, 4)}, s = ${_dec(s, 4)}, n = ${v.length}\nt = (${_dec(m, 4)} − $mu0) / (${_dec(s, 4)}/√${v.length}) = ${_dec(t)}',
  };
}

// ----- Chi-square -----
List<int> _shake(List<int> v, int times, int most) {
  final out = [...v];
  for (var i = 0; i < times; i++) {
    final from = _rng.nextInt(out.length), to = _rng.nextInt(out.length), d = min(_in(1, most), out[from] - 1);
    out[from] -= d;
    out[to] += d;
  }
  return out;
}

Map? _chiSquare(int level) {
  if (level < 3) {
    final List<int> expected;
    final String intro;
    if (level == 1) {
      final each = _pick(const [10, 20, 30]);
      expected = List.filled(6, each);
      intro = '${_l('A die is rolled', 'Ang dice ay inihagis nang')} ${6 * each} ${_l('times', 'beses')}.';
    } else {
      final shares = _pick(const [[50, 30, 20], [40, 40, 20], [25, 25, 50], [60, 25, 15]]), n = _pick(const [100, 200]);
      expected = [for (final s in shares) s * n ~/ 100];
      intro = '${_l('A claim says groups A, B and C are', 'Sinasabi na ang grupong A, B at C ay')} ${shares.join('%, ')}% '
          '${_l('of', 'ng')} $n ${_l('people', 'tao')}.';
    }
    final seen = _shake(expected, 4, 8);
    final chi = [for (var i = 0; i < seen.length; i++) (seen[i] - expected[i]) * (seen[i] - expected[i]) / expected[i]].reduce((a, b) => a + b);
    if (chi < 1) return null;
    return {
      'q': '$intro ${_l('Observed counts', 'Observed counts')}: ${seen.join(', ')}. ${_l('Find the chi-square statistic', 'Hanapin ang chi-square statistic')} ($_twoPlaces).',
      'answer': _dec(chi),
      'hint': 'χ² = Σ (O − E)² / E',
      'why': '${_l('Expected', 'Expected')}: ${expected.join(', ')}\n'
          'χ² = ${[for (var i = 0; i < seen.length; i++) '(${seen[i]} − ${expected[i]})²/${expected[i]}'].join(' + ')} = ${_dec(chi)}',
    };
  }
  final o = _data(4, 10, 60), rows = [o[0] + o[1], o[2] + o[3]], cols = [o[0] + o[2], o[1] + o[3]], n = rows[0] + rows[1];
  final e = [for (var i = 0; i < 2; i++) for (var j = 0; j < 2; j++) rows[i] * cols[j] / n];
  final chi = [for (var i = 0; i < 4; i++) (o[i] - e[i]) * (o[i] - e[i]) / e[i]].reduce((a, b) => a + b);
  if (chi < 1) return null;
  return {
    'q': '${_l('A survey asked men and women if they like a product', 'Tinanong sa survey ang mga lalaki at babae kung gusto nila ang isang produkto')}. '
        '${_l('Men: yes', 'Lalaki: oo')} ${o[0]}, ${_l('no', 'hindi')} ${o[1]}. ${_l('Women: yes', 'Babae: oo')} ${o[2]}, ${_l('no', 'hindi')} ${o[3]}. '
        '${_l('Find the chi-square statistic for independence', 'Hanapin ang chi-square statistic para sa independence')} ($_twoPlaces).',
    'answer': _dec(chi),
    'hint': _l('Expected count = row total × column total ÷ grand total.', 'Expected count = row total × column total ÷ grand total.'),
    'why': '${_l('Expected', 'Expected')}: ${e.map((v) => _dec(v)).join(', ')}\n'
        'χ² = ${[for (var i = 0; i < 4; i++) '(${o[i]} − ${_dec(e[i])})²/${_dec(e[i])}'].join(' + ')} = ${_dec(chi)}',
  };
}

// ----- Correlation and regression -----
Map? _correlation(int level) {
  if (level == 1) {
    final a = _in(-50, 50) / 10, b = _nz(-30, 30) / 10, x = _in(1, 20), y = a + b * x;
    return {
      'q': '${_l('The regression line is', 'Ang regression line ay')} ŷ = ${_dec(a, 1)} ${b < 0 ? '−' : '+'} ${_dec(b.abs(), 1)}x. '
          '${_l('Predict y when x =', 'Hulaan ang y kapag x =')} $x.',
      'answer': _dec(y),
      'hint': _l('Put the x value into the line.', 'Ilagay ang x sa linya.'),
      'why': 'ŷ = ${_dec(a, 1)} ${b < 0 ? '−' : '+'} ${_dec(b.abs(), 1)}($x) = ${_dec(y)}',
    };
  }
  final xs = ([..._data(5, 1, 12)]..sort()), slope = _nz(-4, 4), base = _in(10, 30);
  final ys = [for (final x in xs) base + slope * x + _in(-4, 4)];
  final mx = _mean(xs), my = _mean(ys);
  var sxy = 0.0, sxx = 0.0, syy = 0.0;
  for (var i = 0; i < 5; i++) {
    sxy += (xs[i] - mx) * (ys[i] - my);
    sxx += (xs[i] - mx) * (xs[i] - mx);
    syy += (ys[i] - my) * (ys[i] - my);
  }
  if (sxx == 0 || syy == 0) return null;
  final r = sxy / sqrt(sxx * syy), b = sxy / sxx, data = [for (var i = 0; i < 5; i++) '(${xs[i]}, ${ys[i]})'].join(', ');
  final sums = 'x̄ = ${_dec(mx)}, ȳ = ${_dec(my)}, Sxy = ${_dec(sxy)}, Sxx = ${_dec(sxx)}, Syy = ${_dec(syy)}';
  if (level == 2) {
    if (r.abs() < .3) return null;
    return {
      'q': '${_l('Find the Pearson correlation coefficient r for', 'Hanapin ang Pearson correlation coefficient r ng')} $data '
          '(${_l('to 3 decimal places', 'hanggang 3 decimal places')}).',
      'answer': _dec(r, 3),
      'hint': 'r = Sxy / √(Sxx · Syy)',
      'why': '$sums\nr = ${_dec(sxy)} / √(${_dec(sxx)} × ${_dec(syy)}) = ${_dec(r, 3)}',
    };
  }
  final x0 = xs.last + _in(1, 4), y0 = my + b * (x0 - mx);
  return {
    'q': '${_l('Fit the least-squares line to', 'Gumawa ng least-squares line para sa')} $data, '
        '${_l('then predict y when x =', 'tapos hulaan ang y kapag x =')} $x0 ($_twoPlaces).',
    'answer': _dec(y0),
    'hint': 'b = Sxy / Sxx, a = ȳ − b·x̄, ŷ = a + bx',
    'why': '$sums\nb = ${_dec(sxy)} / ${_dec(sxx)} = ${_dec(b, 4)}, a = ${_dec(my)} − ${_dec(b, 4)} × ${_dec(mx)} = ${_dec(my - b * mx, 4)}\n'
        'ŷ = ${_dec(my - b * mx, 4)} + ${_dec(b, 4)} × $x0 = ${_dec(y0)}',
  };
}
