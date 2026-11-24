part of 'algebra.dart';

// ----- Trigonometry and analytic geometry (Nov 24). Angles are in degrees unless the problem says radians.

double _rad(num degrees) => degrees * pi / 180;
double _deg(num radians) => radians * 180 / pi;

// "π/3", "5π/6", "−π/4", "2π"
String _piText(Rat r) {
  if (r.isZero) return '0';
  final top = r.n.abs() == 1 ? 'π' : '${r.n.abs()}π';
  return '${r.n < 0 ? '−' : ''}$top${r.d == 1 ? '' : '/${r.d}'}';
}

// The exact values students learn for 0°, 30°, 45°, 60°, 90° and their family.
final _exactValues = [
  (0.0, '0'), (.5, '1/2'), (sqrt1_2, '√2/2'), (sqrt(3) / 2, '√3/2'), (1.0, '1'), (sqrt(3) / 3, '√3/3'), (sqrt(3), '√3'),
];
String? _exact(double v) {
  for (final (x, s) in _exactValues) {
    if ((v.abs() - x).abs() < 1e-9) return v < -1e-9 ? '−$s' : s;
  }
  return null;
}

double _trig(String fn, double radians) => switch (fn) { 'sin' => sin(radians), 'cos' => cos(radians), _ => tan(radians) };

// ----- Angles and radians -----
Map? _radians(int level) {
  if (level < 3) {
    final degrees = 15 * _nz(level == 1 ? 1 : -24, 24), r = _r(degrees, 180);
    if (level == 1) {
      return {
        'q': '${_l('Change to radians (in terms of π)', 'Gawing radians (gamit ang π)')}: $degrees°',
        'answer': _piText(r),
        'hint': _l('Multiply by π/180 and simplify the fraction.', 'I-multiply sa π/180 at pasimplehin ang fraction.'),
        'why': '$degrees° × π/180 = ${_piText(r)}',
      };
    }
    return {
      'q': '${_l('Change to degrees', 'Gawing degrees')}: ${_piText(r)}',
      'answer': '$degrees',
      'hint': _l('Multiply by 180/π.', 'I-multiply sa 180/π.'),
      'why': '${_piText(r)} × 180/π = ${_r(degrees).show}°',
    };
  }
  final radius = _in(2, 20), degrees = _pick(const [30, 40, 45, 60, 72, 90, 120, 135, 150, 210, 240]);
  final arc = _rng.nextBool(), v = arc ? radius * _rad(degrees) : radius * radius * _rad(degrees) / 2;
  return {
    'q': arc
        ? '${_l('A circle has radius', 'Ang bilog ay may radius na')} $radius cm. '
            '${_l('Find the length of the arc cut by a central angle of', 'Hanapin ang haba ng arc ng central angle na')} $degrees° '
            '(${_l('to 2 decimal places', 'hanggang 2 decimal places')}).'
        : '${_l('A circle has radius', 'Ang bilog ay may radius na')} $radius cm. '
            '${_l('Find the area of the sector with central angle', 'Hanapin ang area ng sector na may central angle na')} $degrees° '
            '(${_l('to 2 decimal places', 'hanggang 2 decimal places')}).',
    'answer': _dec(v),
    'hint': arc
        ? _l('s = rθ, with θ in radians.', 's = rθ, kung saan ang θ ay nasa radians.')
        : _l('A = ½r²θ, with θ in radians.', 'A = ½r²θ, kung saan ang θ ay nasa radians.'),
    'why': 'θ = $degrees° × π/180 = ${_piText(_r(degrees, 180))} = ${_dec(_rad(degrees), 4)}\n'
        '${arc ? 's = rθ = $radius × ${_dec(_rad(degrees), 4)}' : 'A = ½r²θ = ½ × ${radius * radius} × ${_dec(_rad(degrees), 4)}'} = ${_dec(v)}',
  };
}

// ----- Right triangles -----
Map? _rightTriangle(int level) {
  if (level == 1) {
    final c = _in(5, 30), a = _in(15, 75), opposite = _rng.nextBool();
    final v = c * (opposite ? sin(_rad(a)) : cos(_rad(a)));
    return {
      'q': '${_l('A right triangle has hypotenuse', 'Ang right triangle ay may hypotenuse na')} $c '
          '${_l('and an angle of', 'at anggulong')} $a°. ${_l('Find the side', 'Hanapin ang side na')} '
          '${opposite ? _l('opposite', 'kaharap ng') : _l('next to (adjacent)', 'katabi (adjacent) ng')} '
          '${_l('that angle, to 2 decimal places', 'anggulong iyon, hanggang 2 decimal places')}.',
      'answer': _dec(v),
      'hint': opposite ? 'sin θ = opposite / hypotenuse' : 'cos θ = adjacent / hypotenuse',
      'why': opposite ? 'opposite = $c × sin $a° = $c × ${_dec(sin(_rad(a)), 4)} = ${_dec(v)}'
          : 'adjacent = $c × cos $a° = $c × ${_dec(cos(_rad(a)), 4)} = ${_dec(v)}',
    };
  }
  if (level == 2) {
    final opp = _in(3, 20), adj = _in(3, 20), a = _deg(atan(opp / adj));
    return {
      'q': '${_l('The two legs of a right triangle are', 'Ang dalawang leg ng right triangle ay')} $opp ${_l('and', 'at')} $adj. '
          '${_l('Find the angle opposite the leg', 'Hanapin ang anggulong kaharap ng leg na')} $opp, '
          '${_l('in degrees to 2 decimal places', 'sa degrees hanggang 2 decimal places')}.',
      'answer': _dec(a),
      'hint': 'tan θ = opposite / adjacent, ${_l('so', 'kaya')} θ = tan⁻¹(opposite / adjacent)',
      'why': 'θ = tan⁻¹($opp / $adj) = tan⁻¹(${_dec(opp / adj, 4)}) = ${_dec(a)}°',
    };
  }
  final d = _in(10, 80), a = _in(20, 70), eye = _pick(const [0.0, 1.5, 1.6, 1.7]), h = d * tan(_rad(a)) + eye;
  return {
    'q': '${_l('From a point', 'Mula sa puntong')} $d m ${_l('from the foot of a tower, the angle of elevation of its top is', 'mula sa paanan ng tore, ang angle of elevation ng tuktok nito ay')} $a°'
        '${eye == 0 ? '' : _l(' (measured from eye level, ${_dec(eye, 1)} m above the ground)', ' (sinukat mula sa mata, ${_dec(eye, 1)} m mula sa lupa)')}. '
        '${_l('How tall is the tower, to 2 decimal places?', 'Gaano kataas ang tore, hanggang 2 decimal places?')}',
    'answer': _dec(h),
    'hint': _l('Draw the right triangle: tan θ = height / distance.', 'Iguhit ang right triangle: tan θ = taas / layo.'),
    'why': [
      '${_l('Height above the eye', 'Taas mula sa mata')} = $d × tan $a° = $d × ${_dec(tan(_rad(a)), 4)} = ${_dec(h - eye)}',
      if (eye > 0) '${_l('Add the eye level', 'Idagdag ang taas ng mata')}: ${_dec(h - eye)} + ${_dec(eye, 1)} = ${_dec(h)}',
    ].join('\n'),
  };
}

// ----- Unit circle (exact values) -----
Map? _unitCircle(int level) {
  final fn = _pick(const ['sin', 'cos', 'tan']);
  final Rat turn; // the angle as a fraction of π
  if (level == 1) {
    turn = _r(_pick(const [0, 30, 45, 60, 90]), 180);
  } else if (level == 2) {
    turn = _r(_rng.nextBool() ? 30 * _in(4, 11) : 45 * _in(3, 7), 180);
  } else {
    turn = _rng.nextBool() ? _r(_in(-12, 23), 6) : _r(_in(-8, 15), 4);
  }
  final degrees = (turn.n * 180 / turn.d).round(), x = turn.n * pi / turn.d;
  if (fn == 'tan' && cos(x).abs() < 1e-9) return null; // undefined
  final value = _exact(_trig(fn, x));
  if (value == null) return null;
  final shown = level == 3 ? _piText(turn) : '$degrees°', inTurn = ((degrees % 360) + 360) % 360;
  final ref = switch (inTurn) { < 90 => inTurn, < 180 => 180 - inTurn, < 270 => inTurn - 180, _ => 360 - inTurn };
  final quadrant = inTurn % 90 == 0 ? null : inTurn ~/ 90 + 1;
  return {
    'q': '${_l('Give the exact value', 'Ibigay ang eksaktong value')}: $fn $shown',
    'answer': value,
    'hint': _l('Find the reference angle, then use the sign of the quadrant (All Students Take Calculus).',
        'Hanapin ang reference angle, tapos gamitin ang sign ng quadrant (All Students Take Calculus).'),
    'why': [
      if (level == 3) '$shown = $degrees°${inTurn != degrees ? ', ${_l('the same place as', 'kapareho ng')} $inTurn°' : ''}',
      quadrant == null
          ? '$inTurn° ${_l('is on an axis', 'ay nasa axis')}.'
          : '${_l('Quadrant', 'Quadrant')} ${['I', 'II', 'III', 'IV'][quadrant - 1]}, ${_l('reference angle', 'reference angle')} $ref°.',
      '$fn $shown = $value',
    ].join('\n'),
  };
}

// ----- Identities: one ratio and the quadrant give all the others -----
const _triples = [(3, 4, 5), (4, 3, 5), (5, 12, 13), (12, 5, 13), (8, 15, 17), (15, 8, 17), (7, 24, 25), (20, 21, 29)];

Map? _identities(int level) {
  final (a, b, c) = _pick(_triples);
  final quadrant = level == 1 ? 1 : _in(2, 4);
  final x = _r(quadrant == 1 || quadrant == 4 ? b : -b), y = _r(quadrant <= 2 ? a : -a), r = _r(c);
  final givenSin = _rng.nextBool(), given = givenSin ? 'sin θ = ${(y / r).show}' : 'cos θ = ${(x / r).show}';
  final (String ask, Rat answer) = switch (level) {
    1 => givenSin ? ('cos θ', x / r) : ('sin θ', y / r),
    2 => ('tan θ', y / x),
    _ => _rng.nextBool() ? ('sin 2θ', _r(2) * x * y / (r * r)) : ('cos 2θ', (x * x - y * y) / (r * r)),
  };
  final q = ['I', 'II', 'III', 'IV'][quadrant - 1];
  return {
    'q': '${_l('If', 'Kung')} $given ${_l('and θ is in Quadrant', 'at ang θ ay nasa Quadrant')} $q, ${_l('find', 'hanapin ang')} $ask.',
    'answer': '$answer',
    'hint': level == 3
        ? 'sin 2θ = 2 sin θ cos θ;  cos 2θ = cos²θ − sin²θ'
        : _l('Use sin²θ + cos²θ = 1, then the sign of the quadrant.', 'Gamitin ang sin²θ + cos²θ = 1, tapos ang sign ng quadrant.'),
    'why': [
      'sin²θ + cos²θ = 1  →  ${givenSin ? 'cos θ = ±√(1 − (${(y / r).show})²)' : 'sin θ = ±√(1 − (${(x / r).show})²)'}',
      '${_l('In Quadrant', 'Sa Quadrant')} $q: sin θ = ${(y / r).show}, cos θ = ${(x / r).show}',
      '$ask = ${answer.show}',
    ].join('\n'),
  };
}

// ----- Sine law and cosine law -----
Map? _triangleLaws(int level) {
  if (level == 1) {
    final a = _in(20, 100), b = _in(20, 100), side = _in(5, 30);
    if (a + b > 150) return null;
    final v = side * sin(_rad(b)) / sin(_rad(a));
    return {
      'q': '${_l('In triangle ABC', 'Sa triangle ABC')}, A = $a°, B = $b° ${_l('and', 'at')} a = $side. '
          '${_l('Find b, to 2 decimal places', 'Hanapin ang b, hanggang 2 decimal places')}.',
      'answer': _dec(v),
      'hint': _l('Sine law: a / sin A = b / sin B.', 'Sine law: a / sin A = b / sin B.'),
      'why': 'b = a · sin B / sin A = $side × ${_dec(sin(_rad(b)), 4)} / ${_dec(sin(_rad(a)), 4)} = ${_dec(v)}',
    };
  }
  if (level == 2) {
    final b = _in(4, 20), c = _in(4, 20), a = _in(20, 140), v = sqrt(b * b + c * c - 2 * b * c * cos(_rad(a)));
    return {
      'q': '${_l('In triangle ABC', 'Sa triangle ABC')}, b = $b, c = $c ${_l('and', 'at')} A = $a°. '
          '${_l('Find a, to 2 decimal places', 'Hanapin ang a, hanggang 2 decimal places')}.',
      'answer': _dec(v),
      'hint': _l('Cosine law: a² = b² + c² − 2bc cos A.', 'Cosine law: a² = b² + c² − 2bc cos A.'),
      'why': 'a² = ${b * b} + ${c * c} − 2($b)($c) cos $a° = ${_dec(v * v, 4)}\na = ${_dec(v)}',
    };
  }
  final a = _in(3, 20), b = _in(3, 20), c = _in(3, 20);
  if (a + b <= c || a + c <= b || b + c <= a) return null;
  final k = (a * a + b * b - c * c) / (2 * a * b), v = _deg(acos(k));
  return {
    'q': '${_l('A triangle has sides', 'Ang triangle ay may sides na')} a = $a, b = $b ${_l('and', 'at')} c = $c. '
        '${_l('Find angle C, in degrees to 2 decimal places', 'Hanapin ang angle C, sa degrees hanggang 2 decimal places')}.',
    'answer': _dec(v),
    'hint': _l('Cosine law for an angle: cos C = (a² + b² − c²) / 2ab.', 'Cosine law para sa anggulo: cos C = (a² + b² − c²) / 2ab.'),
    'why': 'cos C = (${a * a} + ${b * b} − ${c * c}) / (2 · $a · $b) = ${_dec(k, 4)}\nC = cos⁻¹(${_dec(k, 4)}) = ${_dec(v)}°',
  };
}

// ----- Trigonometric equations, 0° ≤ x < 360° -----
// The equation as written, and the value of the function it leads to.
const _sinForms = [
  ('2 {f} x − 1 = 0', .5), ('2 {f} x + 1 = 0', -.5), ('√2 {f} x − 1 = 0', sqrt1_2), ('√2 {f} x + 1 = 0', -sqrt1_2),
];

List<int> _anglesWhere(String fn, double value) =>
    [for (var d = 0; d < 360; d += 15) if (fn != 'tan' || cos(_rad(d)).abs() > 1e-9) if ((_trig(fn, _rad(d)) - value).abs() < 1e-9) d];

Map? _trigEquation(int level) {
  final fn = _rng.nextBool() ? 'sin' : 'cos';
  final String equation, step;
  final List<int> angles;
  if (level == 1) {
    final forms = [..._sinForms, ('2 {f} x − √3 = 0', sqrt(3) / 2), ('2 {f} x + √3 = 0', -sqrt(3) / 2)];
    final (text, value) = _pick(forms);
    equation = text.replaceAll('{f}', fn);
    angles = _anglesWhere(fn, value);
    step = '$fn x = ${_exact(value)}';
  } else if (level == 2) {
    final (text, value) = _pick([
      ('tan x − 1 = 0', 1.0), ('tan x + 1 = 0', -1.0), ('tan x − √3 = 0', sqrt(3)), ('tan x + √3 = 0', -sqrt(3)),
      ('3 tan x − √3 = 0', sqrt(3) / 3), ('3 tan x + √3 = 0', -sqrt(3) / 3),
    ]);
    equation = text;
    angles = _anglesWhere('tan', value);
    step = 'tan x = ${_exact(value)}';
  } else {
    // 4s² − 4(u + v)s + 4uv = 0 has s = u or s = v
    const values = [-1.0, -.5, 0.0, .5, 1.0];
    final u = _pick(values), v = _pick(values);
    if (u == v) return null;
    final k = [4, (-4 * (u + v)).round(), (4 * u * v).round()], g = _gcd(_gcd(k[0], k[1]), k[2]);
    equation = '${_sum([(_r(k[0] ~/ g), '$fn² x'), (_r(k[1] ~/ g), '$fn x'), (_r(k[2] ~/ g), '')])} = 0';
    angles = {..._anglesWhere(fn, u), ..._anglesWhere(fn, v)}.toList()..sort();
    step = '${_l('It factors like a quadratic', 'Nafa-factor ito tulad ng quadratic')}: $fn x = ${_exact(u)} ${_l('or', 'o')} $fn x = ${_exact(v)}';
  }
  if (angles.isEmpty) return null;
  final answer = angles.join(', ');
  return {
    'q': '${_l('Solve for 0° ≤ x < 360°. Give every answer in degrees', 'Lutasin para sa 0° ≤ x < 360°. Ibigay ang lahat ng sagot sa degrees')}: $equation',
    'answer': answer,
    'check': 'set',
    'hint': _l('Get the trig function alone, then find every angle in one turn with that value.',
        'Ihiwalay ang trig function, tapos hanapin ang lahat ng anggulo sa isang ikot na may ganoong value.'),
    'why': '$step\nx = ${angles.map((a) => '$a°').join(', ')}',
  };
}

// ----- Distance and midpoint -----
Map? _distance(int level) {
  final x1 = _in(-9, 9), y1 = _in(-9, 9), x2 = _in(-9, 9), y2 = _in(-9, 9);
  if (x1 == x2 && y1 == y2) return null;
  final p = '(${_r(x1).show}, ${_r(y1).show}) ${_l('and', 'at')} (${_r(x2).show}, ${_r(y2).show})';
  if (level == 1) {
    final s = (x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1), d = sqrt(s), whole = d == d.roundToDouble();
    return {
      'q': '${_l('Find the distance between', 'Hanapin ang layo ng')} $p${whole ? '' : _l(', to 2 decimal places', ', hanggang 2 decimal places')}.',
      'answer': whole ? '${d.round()}' : _dec(d),
      'hint': 'd = √((x₂ − x₁)² + (y₂ − y₁)²)',
      'why': 'd = √((${_r(x2 - x1).show})² + (${_r(y2 - y1).show})²) = √$s${whole ? ' = ${d.round()}' : ' ≈ ${_dec(d)}'}',
    };
  }
  if (level == 2) {
    final mx = _r(x1 + x2, 2), my = _r(y1 + y2, 2);
    return {
      'q': '${_l('Find the midpoint of', 'Hanapin ang midpoint ng')} $p. ${_l('Answer as (x, y)', 'Isagot bilang (x, y)')}.',
      'answer': '(${mx.show}, ${my.show})',
      'check': 'pair',
      'hint': _l('Average the x values and the y values.', 'Kunin ang average ng mga x at ng mga y.'),
      'why': 'M = ((${_r(x1).show} + ${_times(_r(x2))}) / 2, (${_r(y1).show} + ${_times(_r(y2))}) / 2) = (${mx.show}, ${my.show})',
    };
  }
  final a = _in(-6, 6), b = _in(-6, 6), c = _in(-10, 10);
  if (a == 0 && b == 0) return null;
  final top = (a * x1 + b * y1 + c).abs(), d = top / sqrt(a * a + b * b);
  if (top == 0) return null;
  return {
    'q': '${_l('Find the distance from the point', 'Hanapin ang layo ng point na')} (${_r(x1).show}, ${_r(y1).show}) '
        '${_l('to the line', 'sa linyang')} ${_sum([(_r(a), 'x'), (_r(b), 'y'), (_r(c), '')])} = 0, ${_l('to 2 decimal places', 'hanggang 2 decimal places')}.',
    'answer': _dec(d),
    'hint': 'd = |Ax₀ + By₀ + C| / √(A² + B²)',
    'why': 'd = |${_r(a).show}(${_r(x1).show}) + ${_times(_r(b))}(${_r(y1).show}) + ${_times(_r(c))}| / √(${a * a} + ${b * b}) = $top / √${a * a + b * b} = ${_dec(d)}',
  };
}

// ----- Conic sections -----
// "(x − 3)²", "(y + 2)²", "x²"
String _shift(String v, int h) => h == 0 ? '$v²' : '($v ${h > 0 ? '−' : '+'} ${h.abs()})²';

Map? _circle(int level) {
  final h = _in(-9, 9), k = _in(-9, 9);
  if (level == 3) {
    final a = _in(-6, 6), b = _in(-6, 6), r2 = a * a + b * b;
    if (r2 == 0) return null;
    final d = -2 * h, e = -2 * k, f = h * h + k * k - r2;
    return {
      'q': '${_l('A circle has center', 'Ang bilog ay may center na')} (${_r(h).show}, ${_r(k).show}) '
          '${_l('and passes through', 'at dumadaan sa')} (${_r(h + a).show}, ${_r(k + b).show}). '
          '${_l('Write it as', 'Isulat ito bilang')} x² + y² + Dx + Ey + F = 0. ${_l('Answer as (D, E, F)', 'Isagot bilang (D, E, F)')}.',
      'answer': '(${_r(d).show}, ${_r(e).show}, ${_r(f).show})',
      'check': 'pair',
      'hint': _l('r² is the squared distance from the center to the point. Then expand (x − h)² + (y − k)² = r².',
          'Ang r² ay ang squared na layo ng center sa point. Tapos i-expand ang (x − h)² + (y − k)² = r².'),
      'why': [
        'r² = (${_r(a).show})² + (${_r(b).show})² = $r2',
        '${_shift('x', h)} + ${_shift('y', k)} = $r2',
        '${_sum([(_r(1), 'x²'), (_r(1), 'y²'), (_r(d), 'x'), (_r(e), 'y'), (_r(f), '')])} = 0',
      ].join('\n'),
    };
  }
  final r = _in(1, 10), answer = '(${_r(h).show}, ${_r(k).show}, $r)';
  if (level == 1) {
    return {
      'q': '${_l('Find the center and radius of', 'Hanapin ang center at radius ng')} ${_shift('x', h)} + ${_shift('y', k)} = ${r * r}. '
          '${_l('Answer as (h, k, r)', 'Isagot bilang (h, k, r)')}.',
      'answer': answer,
      'check': 'pair',
      'hint': '(x − h)² + (y − k)² = r²',
      'why': 'h = ${_r(h).show}, k = ${_r(k).show}, r = √${r * r} = $r',
    };
  }
  final d = -2 * h, e = -2 * k, f = h * h + k * k - r * r;
  return {
    'q': '${_l('Find the center and radius of', 'Hanapin ang center at radius ng')} '
        '${_sum([(_r(1), 'x²'), (_r(1), 'y²'), (_r(d), 'x'), (_r(e), 'y'), (_r(f), '')])} = 0. '
        '${_l('Answer as (h, k, r)', 'Isagot bilang (h, k, r)')}.',
    'answer': answer,
    'check': 'pair',
    'hint': _l('Complete the square for x and for y.', 'I-complete the square ang x at ang y.'),
    'why': '${_l('Complete the square', 'I-complete the square')}: ${_shift('x', h)} + ${_shift('y', k)} = ${_r(-f).show} + ${h * h} + ${k * k} = ${r * r}\n'
        'h = ${_r(h).show}, k = ${_r(k).show}, r = $r',
  };
}

Map? _parabola(int level) {
  if (level == 1) {
    final a = _nz(-3, 3), h = _in(-6, 6), k = _in(-6, 6);
    return {
      'q': '${_l('Find the vertex of', 'Hanapin ang vertex ng')} y = ${_x2(_r(a), _r(-2 * a * h), _r(a * h * h + k))}. '
          '${_l('Answer as (x, y)', 'Isagot bilang (x, y)')}.',
      'answer': '(${_r(h).show}, ${_r(k).show})',
      'check': 'pair',
      'hint': 'x = −b / 2a, ${_l('then put it in to get y', 'tapos ilagay para makuha ang y')}.',
      'why': 'x = −(${_r(-2 * a * h).show}) / (2 · ${_r(a).show}) = ${_r(h).show}\ny = ${_r(k).show}',
    };
  }
  final p = _nz(-5, 5);
  if (level == 2) {
    final up = _rng.nextBool();
    return {
      'q': '${_l('Find the focus of', 'Hanapin ang focus ng')} ${up ? 'x² = ${_term(_r(4 * p), 'y')}' : 'y² = ${_term(_r(4 * p), 'x')}'}. '
          '${_l('Answer as (x, y)', 'Isagot bilang (x, y)')}.',
      'answer': up ? '(0, ${_r(p).show})' : '(${_r(p).show}, 0)',
      'check': 'pair',
      'hint': up ? 'x² = 4py ${_l('has its focus at', 'ay may focus sa')} (0, p).' : 'y² = 4px ${_l('has its focus at', 'ay may focus sa')} (p, 0).',
      'why': '4p = ${_r(4 * p).show}  →  p = ${_r(p).show}',
    };
  }
  final h = _in(-6, 6), k = _in(-6, 6);
  return {
    'q': '${_l('Find the focus of', 'Hanapin ang focus ng')} ${_sum([(_r(1), 'y²'), (_r(-2 * k), 'y'), (_r(-4 * p), 'x'), (_r(k * k + 4 * p * h), '')])} = 0. '
        '${_l('Answer as (x, y)', 'Isagot bilang (x, y)')}.',
    'answer': '(${_r(h + p).show}, ${_r(k).show})',
    'check': 'pair',
    'hint': _l('Complete the square in y to get (y − k)² = 4p(x − h). The focus is (h + p, k).',
        'I-complete the square sa y para makuha ang (y − k)² = 4p(x − h). Ang focus ay (h + p, k).'),
    'why': '${_shift('y', k)} = ${_term(_r(4 * p), '')}${_shift('x', h).replaceAll('²', '')}\n'
        'vertex (${_r(h).show}, ${_r(k).show}), p = ${_r(p).show}  →  focus (${_r(h + p).show}, ${_r(k).show})',
  };
}

// a² = b² + c² for an ellipse; c² = a² + b² for a hyperbola.
const _ellipses = [(5, 4, 3), (5, 3, 4), (10, 8, 6), (10, 6, 8), (13, 12, 5), (13, 5, 12), (17, 15, 8), (17, 8, 15)];

Map? _ellipse(int level) {
  final (a, b, c) = _pick(_ellipses);
  final wide = _rng.nextBool(), h = level == 3 ? _in(-6, 6) : 0, k = level == 3 ? _in(-6, 6) : 0;
  final x = '${_shift('x', h)}/${(wide ? a : b) * (wide ? a : b)}', y = '${_shift('y', k)}/${(wide ? b : a) * (wide ? b : a)}';
  final eq = '$x + $y = 1';
  final base = 'c² = a² − b² = ${a * a} − ${b * b} = ${c * c}  →  c = $c';
  if (level == 1) {
    return {
      'q': '${_l('Find the distance from the center to each focus (c) of', 'Hanapin ang layo ng center sa bawat focus (c) ng')} $eq.',
      'answer': '$c',
      'hint': _l('For an ellipse, c² = a² − b² (a² is the bigger number).', 'Sa ellipse, c² = a² − b² (ang a² ang mas malaking numero).'),
      'why': base,
    };
  }
  if (level == 2) {
    return {
      'q': '${_l('Find the eccentricity of', 'Hanapin ang eccentricity ng')} $eq.',
      'answer': '${_r(c, a)}',
      'hint': 'e = c / a, ${_l('with', 'kung saan')} c² = a² − b².',
      'why': '$base\ne = c / a = $c/$a${_gcd(c, a) > 1 ? ' = ${_r(c, a).show}' : ''}',
    };
  }
  return {
    'q': '${_l('Find the', 'Hanapin ang')} ${wide ? _l('right focus', 'kanang focus') : _l('upper focus', 'itaas na focus')} '
        '${_l('of', 'ng')} $eq. ${_l('Answer as (x, y)', 'Isagot bilang (x, y)')}.',
    'answer': wide ? '(${_r(h + c).show}, ${_r(k).show})' : '(${_r(h).show}, ${_r(k + c).show})',
    'check': 'pair',
    'hint': _l('Find the center (h, k) and c; the foci are c away along the longer axis.',
        'Hanapin ang center (h, k) at c; ang foci ay c ang layo sa mas mahabang axis.'),
    'why': '${_l('Center', 'Center')} (${_r(h).show}, ${_r(k).show}); $base\n'
        '${wide ? '(${_r(h).show} + $c, ${_r(k).show}) = (${_r(h + c).show}, ${_r(k).show})' : '(${_r(h).show}, ${_r(k).show} + $c) = (${_r(h).show}, ${_r(k + c).show})'}',
  };
}

const _hyperbolas = [(3, 4, 5), (4, 3, 5), (5, 12, 13), (12, 5, 13), (6, 8, 10), (8, 6, 10), (8, 15, 17), (15, 8, 17)];

Map? _hyperbola(int level) {
  final (a, b, c) = _pick(_hyperbolas);
  final wide = _rng.nextBool(), h = level == 3 ? _in(-6, 6) : 0, k = level == 3 ? _in(-6, 6) : 0;
  final first = wide ? '${_shift('x', h)}/${a * a}' : '${_shift('y', k)}/${a * a}';
  final second = wide ? '${_shift('y', k)}/${b * b}' : '${_shift('x', h)}/${b * b}';
  final eq = '$first − $second = 1', base = 'c² = a² + b² = ${a * a} + ${b * b} = ${c * c}  →  c = $c';
  if (level == 1) {
    return {
      'q': '${_l('Find the distance from the center to each focus (c) of', 'Hanapin ang layo ng center sa bawat focus (c) ng')} $eq.',
      'answer': '$c',
      'hint': _l('For a hyperbola, c² = a² + b².', 'Sa hyperbola, c² = a² + b².'),
      'why': base,
    };
  }
  if (level == 2) {
    final m = wide ? _r(b, a) : _r(a, b);
    return {
      'q': '${_l('Find the positive slope of the asymptotes of', 'Hanapin ang positive na slope ng asymptotes ng')} $eq.',
      'answer': '$m',
      'hint': wide ? 'x²/a² − y²/b² = 1: y = ±(b/a)x' : 'y²/a² − x²/b² = 1: y = ±(a/b)x',
      'why': wide ? 'b / a = $b/$a = ${m.show}' : 'a / b = $a/$b = ${m.show}',
    };
  }
  return {
    'q': '${_l('Find the', 'Hanapin ang')} ${wide ? _l('right focus', 'kanang focus') : _l('upper focus', 'itaas na focus')} '
        '${_l('of', 'ng')} $eq. ${_l('Answer as (x, y)', 'Isagot bilang (x, y)')}.',
    'answer': wide ? '(${_r(h + c).show}, ${_r(k).show})' : '(${_r(h).show}, ${_r(k + c).show})',
    'check': 'pair',
    'hint': _l('Find the center (h, k) and c; the foci are c away along the axis of the positive term.',
        'Hanapin ang center (h, k) at c; ang foci ay c ang layo sa axis ng positive na term.'),
    'why': '${_l('Center', 'Center')} (${_r(h).show}, ${_r(k).show}); $base',
  };
}
