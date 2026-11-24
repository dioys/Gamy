part of 'algebra.dart';

// ----- College algebra, the rest (Nov 24): inequalities, absolute value, polynomials, factoring, rational
// expressions, radicals, quadratics, functions, exponents and logarithms. Every answer is worked out exactly.

const _flips = {'<': '>', '>': '<', '≤': '≥', '≥': '≤'};
String _x2(Rat a, Rat b, Rat c) => _sum([(a, 'x²'), (b, 'x'), (c, '')]);
String _bracket(Rat a, Rat b) => '(${_sum([(a, 'x'), (b, '')])})';
String _divideBy(Rat a) => '${_l('Divide by', 'I-divide sa')} ${a.show}'
    '${a.n < 0 ? _l(' (negative, so the sign flips)', ' (negative, kaya babaliktad ang sign)') : ''}';

// ----- Inequalities -----
Map? _inequality(int level) {
  final op = _pick(const ['<', '>', '≤', '≥']), strict = op == '<' || op == '>';
  if (level == 1) {
    // ax + b < c
    final a = _r(_nz(-9, 9)), b = _r(_in(-15, 15)), x = _r(_in(-9, 9));
    if (a.n.abs() == 1) return null;
    final c = a * x + b, op2 = a.n < 0 ? _flips[op]! : op;
    return {
      'q': '${_l('Solve the inequality', 'Lutasin ang inequality')}: ${_sum([(a, 'x'), (b, '')])} $op ${c.show}',
      'answer': 'x $op2 ${x.show}',
      'check': 'ineq',
      'hint': _l('Solve it like an equation, but flip the sign if you divide by a negative number.',
          'Lutasin na parang equation, pero baliktarin ang sign kapag nag-divide sa negative.'),
      'why': [
        if (!b.isZero) '${_l('Move', 'Ilipat ang')} ${b.show}: ${_term(a, 'x')} $op ${(c - b).show}',
        '${_divideBy(a)}: x $op2 ${x.show}',
      ].join('\n'),
    };
  }
  if (level == 2) {
    // lo < ax + b < hi
    final a = _r(_nz(-6, 6)), b = _r(_in(-10, 10)), x1 = _in(-8, 4), x2 = x1 + _in(2, 8), o = strict ? '<' : '≤';
    if (a.n.abs() == 1) return null;
    final e1 = a * _r(x1) + b, e2 = a * _r(x2) + b, lo = a.n > 0 ? e1 : e2, hi = a.n > 0 ? e2 : e1;
    return {
      'q': '${_l('Solve the inequality', 'Lutasin ang inequality')}: ${lo.show} $o ${_sum([(a, 'x'), (b, '')])} $o ${hi.show}',
      'answer': '${_r(x1).show} $o x $o ${_r(x2).show}',
      'check': 'ineq',
      'hint': _l('Do the same step to all three parts. Dividing by a negative flips both signs.',
          'Gawin ang parehong hakbang sa tatlong bahagi. Kapag nag-divide sa negative, babaliktad ang dalawang sign.'),
      'why': [
        if (!b.isZero)
          '${_l('Subtract', 'Ibawas ang')} ${b.show} ${_l('from all three parts', 'sa tatlong bahagi')}: '
              '${(lo - b).show} $o ${_term(a, 'x')} $o ${(hi - b).show}',
        '${_divideBy(a)}: ${_r(x1).show} $o x $o ${_r(x2).show}',
      ].join('\n'),
    };
  }
  // (x − p)(x − q) > 0, written out
  final p = _in(-7, 5), q = p + _in(1, 7), lt = strict ? '<' : '≤', gt = strict ? '>' : '≥';
  final outside = op == '>' || op == '≥';
  final answer = outside ? 'x $lt ${_r(p).show} or x $gt ${_r(q).show}' : '${_r(p).show} $lt x $lt ${_r(q).show}';
  return {
    'q': '${_l('Solve the inequality', 'Lutasin ang inequality')}: ${_x2(_r(1), _r(-(p + q)), _r(p * q))} $op 0',
    'answer': answer,
    'check': 'ineq',
    'hint': _l('Factor it, mark where each factor is zero, then test a number in each part of the number line.',
        'I-factor, markahan kung saan zero ang bawat factor, tapos sumubok ng numero sa bawat bahagi ng number line.'),
    'why': [
      '${_l('Factor', 'I-factor')}: ${_bracket(_r(1), _r(-p))}${_bracket(_r(1), _r(-q))} $op 0',
      '${_l('It is zero at', 'Zero ito sa')} x = ${_r(p).show} ${_l('and', 'at')} x = ${_r(q).show}.',
      outside
          ? _l('The product is positive outside these two numbers.', 'Positive ang product sa labas ng dalawang numerong ito.')
          : _l('The product is negative between these two numbers.', 'Negative ang product sa pagitan ng dalawang numerong ito.'),
      '${_l('Answer', 'Sagot')}: $answer',
    ].join('\n'),
  };
}

// ----- Absolute value -----
Map? _absolute(int level) {
  final a = level == 1 ? _r(1) : _r(_in(2, 6)), b = _r(_nz(-9, 9)), c = _r(_in(1, 12));
  final inner = _sum([(a, 'x'), (b, '')]), x1 = (-c - b) / a, x2 = (c - b) / a;
  if (level < 3) {
    return {
      'q': '${_l('Solve', 'Lutasin')}: |$inner| = ${c.show}. ${_l('Give both answers', 'Ibigay ang dalawang sagot')}.',
      'answer': '${x1.show}, ${x2.show}',
      'check': 'set',
      'hint': _l('The inside is either the number or its negative. Solve both.',
          'Ang nasa loob ay ang numero o ang negative nito. Lutasin pareho.'),
      'why': [
        '$inner = ${c.show}  ${_l('or', 'o')}  $inner = ${(-c).show}',
        'x = ${x2.show}  ${_l('or', 'o')}  x = ${x1.show}',
      ].join('\n'),
    };
  }
  final op = _pick(const ['<', '>', '≤', '≥']), strict = op == '<' || op == '>';
  final lt = strict ? '<' : '≤', gt = strict ? '>' : '≥', outside = op == '>' || op == '≥';
  final answer = outside ? 'x $lt ${x1.show} or x $gt ${x2.show}' : '${x1.show} $lt x $lt ${x2.show}';
  return {
    'q': '${_l('Solve the inequality', 'Lutasin ang inequality')}: |$inner| $op ${c.show}',
    'answer': answer,
    'check': 'ineq',
    'hint': _l('|A| < c means −c < A < c. |A| > c means A < −c or A > c.',
        '|A| < c ay −c < A < c. |A| > c ay A < −c o A > c.'),
    'why': [
      outside
          ? '$inner $lt ${(-c).show}  ${_l('or', 'o')}  $inner $gt ${c.show}'
          : '${(-c).show} $lt $inner $lt ${c.show}',
      '${_l('Subtract', 'Ibawas ang')} ${b.show}, ${_l('then divide by', 'tapos i-divide sa')} ${a.show}.',
      '${_l('Answer', 'Sagot')}: $answer',
    ].join('\n'),
  };
}

// ----- Polynomials -----
Map? _polynomial(int level) {
  if (level == 1) {
    final p = [for (var i = 0; i < 3; i++) _r(_in(-9, 9))], q = [for (var i = 0; i < 3; i++) _r(_in(-9, 9))];
    if (p[0].isZero || q[0].isZero) return null;
    final minus = _rng.nextBool(), r = [for (var i = 0; i < 3; i++) minus ? p[i] - q[i] : p[i] + q[i]];
    final answer = _x2(r[0], r[1], r[2]);
    return {
      'q': '${_l('Simplify', 'Pasimplehin')}: (${_x2(p[0], p[1], p[2])}) ${minus ? '−' : '+'} (${_x2(q[0], q[1], q[2])})',
      'answer': answer,
      'check': 'expanded',
      'hint': minus
          ? _l('Change every sign in the second bracket, then add like terms.',
              'Baliktarin ang bawat sign sa pangalawang bracket, tapos pagsamahin ang magkaparehong term.')
          : _l('Add the x² terms, the x terms and the numbers separately.',
              'Pagsamahin nang hiwalay ang x², ang x at ang mga numero.'),
      'why': [
        if (minus) '${_l('Change the signs', 'Baliktarin ang sign')}: ${_x2(p[0], p[1], p[2])} + ${_x2(-q[0], -q[1], -q[2])}',
        '${_l('Like terms', 'Magkaparehong term')}: $answer',
      ].join('\n'),
    };
  }
  if (level == 2) {
    final a = _r(_nz(-5, 5)), b = _r(_nz(-9, 9)), c = _r(_nz(-5, 5)), d = _r(_nz(-9, 9));
    final answer = _x2(a * c, a * d + b * c, b * d);
    return {
      'q': '${_l('Multiply and simplify', 'I-multiply at pasimplehin')}: ${_bracket(a, b)}${_bracket(c, d)}',
      'answer': answer,
      'check': 'expanded',
      'hint': _l('FOIL: first, outer, inner, last. Then add the two x terms.',
          'FOIL: first, outer, inner, last. Tapos pagsamahin ang dalawang x term.'),
      'why': [
        'F: ${_term(a, 'x')} · ${_term(c, 'x')} = ${_term(a * c, 'x²')}',
        'O + I: ${_term(a * d, 'x')} ${(b * c).n < 0 ? '−' : '+'} ${_term((b * c).n < 0 ? -(b * c) : b * c, 'x')} = ${_term(a * d + b * c, 'x')}',
        'L: ${_times(b)} · ${_times(d)} = ${(b * d).show}',
        answer,
      ].join('\n'),
    };
  }
  // Remainder theorem with synthetic division.
  final k = [_r(_nz(-3, 3)), _r(_in(-6, 6)), _r(_in(-9, 9)), _r(_in(-9, 9))], r = _r(_nz(-3, 3));
  final row = <Rat>[k[0]];
  for (var i = 1; i < 4; i++) {
    row.add(k[i] + row.last * r);
  }
  final p = _sum([(k[0], 'x³'), (k[1], 'x²'), (k[2], 'x'), (k[3], '')]);
  return {
    'q': '${_l('Find the remainder when', 'Hanapin ang remainder kapag ang')} P(x) = $p '
        '${_l('is divided by', 'ay hinati sa')} ${_bracket(_r(1), -r)}.',
    'answer': '${row.last}',
    'hint': _l('Remainder theorem: the remainder is P(r) when you divide by (x − r).',
        'Remainder theorem: ang remainder ay P(r) kapag hinati sa (x − r).'),
    'why': [
      '${_l('Synthetic division with', 'Synthetic division gamit ang')} r = ${r.show}:',
      '   ${k.map((v) => v.show).join('   ')}',
      '   ${row.map((v) => v.show).join('   ')}',
      '${_l('The last number is the remainder (the same as P(r))', 'Ang huling numero ang remainder (kapareho ng P(r))')}: '
          'P(${r.show}) = ${row.last.show}',
    ].join('\n'),
  };
}

// ----- Factoring -----
Map? _factoring(int level) {
  if (level < 3 || _rng.nextBool()) {
    // k(px + q)(rx + s); easy: x² + bx + c, medium: a leading number, hard: a common factor too
    final k = level == 3 ? _in(2, 5) : 1, p = level == 1 ? 1 : _in(1, 5), r = level == 1 ? 1 : _in(1, 5);
    final q = _nz(-9, 9), s = _nz(-9, 9);
    if (level == 2 && p * r == 1 || _gcd(p, q) > 1 || _gcd(r, s) > 1) return null;
    final f1 = _bracket(_r(p), _r(q)), f2 = _bracket(_r(r), _r(s));
    final answer = '${k == 1 ? '' : k}${f1 == f2 ? '$f1²' : '$f1$f2'}';
    final a = _r(k * p * r), b = _r(k * (p * s + q * r)), c = _r(k * q * s);
    return {
      'q': '${_l('Factor completely', 'I-factor nang buo')}: ${_x2(a, b, c)}',
      'answer': answer,
      'check': 'factor',
      'hint': level == 1
          ? _l('Find two numbers that multiply to the last number and add to the middle number.',
              'Maghanap ng dalawang numerong ang product ay ang huling numero at ang sum ay ang nasa gitna.')
          : _l('Take out any common factor first, then use the ac method (split the middle term).',
              'Ilabas muna ang common factor, tapos gamitin ang ac method (hatiin ang gitnang term).'),
      'why': [
        if (k > 1) '${_l('Common factor', 'Common factor')}: $k(${_x2(_r(p * r), _r(p * s + q * r), _r(q * s))})',
        if (p * r > 1)
          'a·c = ${p * r}·${_r(q * s).show} = ${_r(p * r * q * s).show}; '
              '${_l('the two numbers are', 'ang dalawang numero ay')} ${_r(p * s).show} ${_l('and', 'at')} ${_r(q * r).show}'
        else
          '${_l('The two numbers are', 'Ang dalawang numero ay')} ${_r(q).show} ${_l('and', 'at')} ${_r(s).show} '
              '(${_l('product', 'product')} ${_r(q * s).show}, ${_l('sum', 'sum')} ${_r(q + s).show})',
        answer,
      ].join('\n'),
    };
  }
  // Sum or difference of cubes: x³ ± a³ = (x ± a)(x² ∓ ax + a²)
  final a = _in(1, 5), plus = _rng.nextBool(), sa = plus ? a : -a;
  final answer = '${_bracket(_r(1), _r(sa))}(${_x2(_r(1), _r(-sa), _r(a * a))})';
  return {
    'q': '${_l('Factor completely', 'I-factor nang buo')}: x³ ${plus ? '+' : '−'} ${a * a * a}',
    'answer': answer,
    'check': 'factor',
    'hint': _l('Sum or difference of two cubes: a³ ± b³ = (a ± b)(a² ∓ ab + b²).',
        'Sum o difference ng dalawang cube: a³ ± b³ = (a ± b)(a² ∓ ab + b²).'),
    'why': [
      '${a * a * a} = $a³, ${_l('so this is', 'kaya ito ay')} x³ ${plus ? '+' : '−'} $a³',
      answer,
    ].join('\n'),
  };
}

// ----- Rational expressions -----
Map? _rational(int level) {
  if (level < 3) {
    final m = _nz(-9, 9), n = _nz(-9, 9), p = _nz(-9, 9);
    if (m == n || m == p || n == p) return null;
    final top = _x2(_r(1), _r(m + n), _r(m * n)), common = _bracket(_r(1), _r(m)), keep = _bracket(_r(1), _r(n));
    if (level == 1) {
      return {
        'q': '${_l('Simplify', 'Pasimplehin')}: ($top) / $common',
        'answer': _sum([(_r(1), 'x'), (_r(n), '')]),
        'check': 'simple',
        'hint': _l('Factor the top, then cancel the factor that is also at the bottom.',
            'I-factor ang itaas, tapos i-cancel ang factor na nasa ibaba rin.'),
        'why': '${_l('Factor', 'I-factor')}: $common$keep / $common\n'
            '${_l('Cancel', 'I-cancel ang')} $common: ${_sum([(_r(1), 'x'), (_r(n), '')])}',
      };
    }
    final bottom = _x2(_r(1), _r(m + p), _r(m * p)), other = _bracket(_r(1), _r(p));
    return {
      'q': '${_l('Simplify', 'Pasimplehin')}: ($top) / ($bottom)',
      'answer': '$keep/$other',
      'check': 'simple',
      'hint': _l('Factor the top and the bottom, then cancel the same factor.',
          'I-factor ang itaas at ibaba, tapos i-cancel ang magkaparehong factor.'),
      'why': '${_l('Factor', 'I-factor')}: $common$keep / $common$other\n'
          '${_l('Cancel', 'I-cancel ang')} $common: $keep/$other',
    };
  }
  // a/(x + b) = c/(x + d)
  final a = _in(1, 9), c = _in(1, 9), b = _nz(-9, 9), d = _nz(-9, 9);
  if (a == c || b == d) return null;
  final x = _r(c * b - a * d, a - c);
  if (x == _r(-b) || x == _r(-d)) return null;
  return {
    'q': '${_l('Solve', 'Lutasin')}: $a/${_bracket(_r(1), _r(b))} = $c/${_bracket(_r(1), _r(d))}',
    'answer': '$x',
    'hint': _l('Cross-multiply, then solve the linear equation. Check that no bottom becomes 0.',
        'I-cross-multiply, tapos lutasin ang linear equation. Siguraduhing walang ibaba na magiging 0.'),
    'why': [
      '${_l('Cross-multiply', 'I-cross-multiply')}: $a${_bracket(_r(1), _r(d))} = $c${_bracket(_r(1), _r(b))}',
      '${_sum([(_r(a), 'x'), (_r(a * d), '')])} = ${_sum([(_r(c), 'x'), (_r(c * b), '')])}',
      '${_term(_r(a - c), 'x')} = ${_r(c * b - a * d).show}  →  x = ${x.show}',
    ].join('\n'),
  };
}

// ----- Radicals -----
String _root(int coef, int m) => coef == 1 ? '√$m' : '$coef√$m';

Map? _radical(int level) {
  final m = _pick(const [2, 3, 5, 6, 7, 10, 11]), k = _in(2, level == 1 ? 9 : 5);
  if (level == 1) {
    return {
      'q': '${_l('Simplify', 'Pasimplehin')}: √${k * k * m}',
      'answer': _root(k, m),
      'check': 'radical',
      'hint': _l('Find the biggest perfect square that divides the number.',
          'Hanapin ang pinakamalaking perfect square na naghahati sa numero.'),
      'why': '√${k * k * m} = √(${k * k} · $m) = ${_root(k, m)}',
    };
  }
  if (level == 2) {
    final a = _in(1, 9), b = _in(1, 5);
    return {
      'q': '${_l('Simplify', 'Pasimplehin')}: ${_root(a, m)} + ${b == 1 ? '' : b}√${k * k * m}',
      'answer': _root(a + b * k, m),
      'check': 'radical',
      'hint': _l('Simplify the second radical first; then add the numbers in front of the same root.',
          'Pasimplehin muna ang pangalawang radical; tapos pagsamahin ang mga numero sa harap ng parehong root.'),
      'why': '${b == 1 ? '' : b}√${k * k * m} = ${b == 1 ? '' : '$b · '}$k√$m = ${_root(b * k, m)}\n'
          '${_root(a, m)} + ${_root(b * k, m)} = ${_root(a + b * k, m)}',
    };
  }
  // a/√m: rationalize the denominator
  final a = _in(1, 12), g = _gcd(a, m), top = a ~/ g, bottom = m ~/ g;
  final answer = bottom == 1 ? _root(top, m) : '${_root(top, m)}/$bottom';
  return {
    'q': '${_l('Rationalize the denominator', 'I-rationalize ang denominator')}: $a/√$m',
    'answer': answer,
    'check': 'radical',
    'hint': _l('Multiply the top and the bottom by the root at the bottom.',
        'I-multiply ang itaas at ibaba sa root na nasa ibaba.'),
    'why': '$a/√$m · √$m/√$m = ${_root(a, m)}/$m${g > 1 ? ' = $answer' : ''}',
  };
}

// ----- Quadratic equations -----
Map? _quadratic(int level) {
  if (level < 3) {
    // (px − q)(rx − s) = 0
    final p = level == 1 ? 1 : _in(1, 4), r = level == 1 ? 1 : _in(1, 4), q = _nz(-9, 9), s = _nz(-9, 9);
    final x1 = _r(q, p), x2 = _r(s, r);
    if (x1 == x2 || level == 2 && p * r == 1) return null;
    final a = _r(p * r), b = _r(-(p * s + q * r)), c = _r(q * s);
    final roots = [x1, x2]..sort((u, v) => (u.n * v.d).compareTo(v.n * u.d));
    return {
      'q': '${_l('Solve', 'Lutasin')}: ${_x2(a, b, c)} = 0. ${_l('Give both answers', 'Ibigay ang dalawang sagot')}.',
      'answer': '${roots[0].show}, ${roots[1].show}',
      'check': 'set',
      'hint': _l('Factor it, then set each factor to 0.', 'I-factor, tapos gawing 0 ang bawat factor.'),
      'why': [
        '${_l('Factor', 'I-factor')}: ${_bracket(_r(p), _r(-q))}${_bracket(_r(r), _r(-s))} = 0',
        'x = ${x1.show}  ${_l('or', 'o')}  x = ${x2.show}',
      ].join('\n'),
    };
  }
  final a = _in(1, 5), b = _in(-9, 9), c = _in(-9, 9), d = b * b - 4 * a * c;
  if (d <= 0 || sqrt(d) == sqrt(d).roundToDouble()) return null;
  final x1 = (-b - sqrt(d)) / (2 * a), x2 = (-b + sqrt(d)) / (2 * a);
  if (x1.abs() < .1 || x2.abs() < .1) return null;
  return {
    'q': '${_l('Solve with the quadratic formula, to 2 decimal places', 'Lutasin gamit ang quadratic formula, hanggang 2 decimal places')}: '
        '${_x2(_r(a), _r(b), _r(c))} = 0',
    'answer': '${_dec(x1)}, ${_dec(x2)}',
    'check': 'set',
    'hint': 'x = (−b ± √(b² − 4ac)) / 2a',
    'why': [
      'a = $a, b = ${_r(b).show}, c = ${_r(c).show}',
      'b² − 4ac = ${b * b} − ${4 * a * c} = $d'.replaceAll('− -', '+ '),
      'x = (${_r(-b).show} ± √$d) / ${2 * a}',
      'x = ${_dec(x1)}  ${_l('or', 'o')}  x = ${_dec(x2)}',
    ].join('\n'),
  };
}

// ----- Functions -----
Map? _functions(int level) {
  if (level == 1) {
    final a = _r(_nz(-4, 4)), b = _r(_in(-9, 9)), c = _r(_in(-9, 9)), k = _r(_in(-5, 5));
    final v = a * k * k + b * k + c;
    return {
      'q': '${_l('If', 'Kung')} f(x) = ${_x2(a, b, c)}, ${_l('find', 'hanapin ang')} f(${k.show}).',
      'answer': '$v',
      'hint': _l('Put the number in place of every x.', 'Ilagay ang numero kapalit ng bawat x.'),
      'why': 'f(${k.show}) = ${_times(a)}(${k.show})² + ${_times(b)}(${k.show}) + ${_times(c)} = ${v.show}',
    };
  }
  if (level == 2) {
    final a = _r(_nz(-5, 5)), b = _r(_in(-9, 9)), c = _r(_nz(-4, 4)), d = _r(_in(-9, 9));
    final f = _sum([(a, 'x'), (b, '')]), g = _sum([(c, 'x²'), (d, '')]), fg = _rng.nextBool();
    // f(g(x)) = a(cx² + d) + b;  g(f(x)) = c(ax + b)² + d
    final answer = fg ? _x2(a * c, _r(0), a * d + b) : _x2(c * a * a, _r(2) * c * a * b, c * b * b + d);
    return {
      'q': '${_l('If', 'Kung')} f(x) = $f ${_l('and', 'at')} g(x) = $g, ${_l('find', 'hanapin ang')} ${fg ? 'f(g(x))' : 'g(f(x))'}.',
      'answer': answer,
      'check': 'expr',
      'hint': fg
          ? _l('Put all of g(x) in place of x in f.', 'Ilagay ang buong g(x) kapalit ng x sa f.')
          : _l('Put all of f(x) in place of x in g.', 'Ilagay ang buong f(x) kapalit ng x sa g.'),
      'why': fg ? 'f(g(x)) = ${_times(a)}($g) + ${_times(b)} = $answer' : 'g(f(x)) = ${_times(c)}($f)² + ${_times(d)} = $answer',
    };
  }
  // f(x) = (ax + b)/(x + d)  ->  f⁻¹(x) = (b − dx)/(x − a)
  final a = _nz(-6, 6), b = _nz(-9, 9), d = _nz(-6, 6);
  if (a * d == b) return null;
  final answer = '(${_sum([(_r(-d), 'x'), (_r(b), '')])})/(${_sum([(_r(1), 'x'), (_r(-a), '')])})';
  return {
    'q': '${_l('Find the inverse of', 'Hanapin ang inverse ng')} f(x) = (${_sum([(_r(a), 'x'), (_r(b), '')])})/${_bracket(_r(1), _r(d))}.',
    'answer': answer,
    'check': 'expr',
    'hint': _l('Write y = f(x), swap x and y, then solve for y.', 'Isulat ang y = f(x), pagpalitin ang x at y, tapos lutasin ang y.'),
    'why': [
      '${_l('Swap', 'Pagpalitin')}: x = (${_sum([(_r(a), 'y'), (_r(b), '')])})/(${_sum([(_r(1), 'y'), (_r(d), '')])})',
      '${_l('Multiply out', 'I-multiply')}: ${_sum([(_r(1), 'xy'), (_r(d), 'x')])} = ${_sum([(_r(a), 'y'), (_r(b), '')])}',
      '${_l('y terms on one side', 'Ang y sa isang side')}: ${_sum([(_r(1), 'xy'), (_r(-a), 'y')])} = ${_sum([(_r(-d), 'x'), (_r(b), '')])}',
      'f⁻¹(x) = $answer',
    ].join('\n'),
  };
}

// ----- Exponents and logarithms -----
const _subs = ['₀', '₁', '₂', '₃', '₄', '₅', '₆', '₇', '₈', '₉'];
String _log(int base) => 'log${'$base'.split('').map((c) => _subs[int.parse(c)]).join()}';

Map? _explog(int level) {
  if (level == 1) {
    // B^(x + b) = B^n
    final base = _pick(const [2, 3, 5]), n = _in(2, base == 2 ? 6 : base == 3 ? 4 : 3), b = _nz(-3, 3);
    final value = pow(base, n).toInt();
    return {
      'q': '${_l('Solve', 'Lutasin')}: $base^(${_sum([(_r(1), 'x'), (_r(b), '')])}) = $value',
      'answer': '${n - b}',
      'hint': _l('Write the right side as a power of the same base, then make the exponents equal.',
          'Isulat ang kanan bilang power ng parehong base, tapos gawing magkapareho ang exponents.'),
      'why': '$value = $base^$n, ${_l('so', 'kaya')} ${_sum([(_r(1), 'x'), (_r(b), '')])} = $n  →  x = ${_r(n - b).show}',
    };
  }
  if (level == 2) {
    // log_B(ax + c) = n
    final base = _pick(const [2, 3, 4, 5]), n = _in(1, 3), a = _in(1, 5), c = _in(-9, 9);
    final x = _r(pow(base, n).toInt() - c, a);
    return {
      'q': '${_l('Solve', 'Lutasin')}: ${_log(base)}(${_sum([(_r(a), 'x'), (_r(c), '')])}) = $n',
      'answer': '$x',
      'hint': _l('log_b(A) = n means A = bⁿ.', 'Ang log_b(A) = n ay A = bⁿ.'),
      'why': [
        '${_sum([(_r(a), 'x'), (_r(c), '')])} = $base^$n = ${pow(base, n)}',
        '${_term(_r(a), 'x')} = ${_r(pow(base, n).toInt() - c).show}  →  x = ${x.show}',
      ].join('\n'),
    };
  }
  // B^x = N, N not a power of B
  final base = _in(2, 9), n = _in(5, 200);
  final x = log(n) / log(base);
  if ((x - x.round()).abs() < 1e-9) return null;
  return {
    'q': '${_l('Solve, to 3 decimal places', 'Lutasin, hanggang 3 decimal places')}: $base^x = $n',
    'answer': _dec(x, 3),
    'hint': _l('Take the log of both sides: x = log(N) / log(B).', 'Kunin ang log ng magkabilang side: x = log(N) / log(B).'),
    'why': 'x = ln $n / ln $base = ${_dec(log(n), 4)} / ${_dec(log(base), 4)} = ${_dec(x, 3)}',
  };
}
