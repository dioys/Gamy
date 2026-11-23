import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:sqlite3/sqlite3.dart';

import 'account.dart';
import 'brain.dart';
import 'rules.dart';
import 'strings.dart';
import 'terms.dart';

final store = Store();
const _maxBytes = 20 * 1024 * 1024;

// Everything is saved on this device (a copy of subjects and modules also goes online when signed in,
// see account.dart), in a SQLite database (gamy.db) with four tables:
//   settings (key, value) · subjects (id, name) · modules (id, subject_id, name, text)
//   scores (id, subject_id, module, type, correct, total, date)
//   chunks (id, module_id, text, vec): pieces of each module with their meaning vectors, for smart search
// Each change writes only its own row. Older versions saved one JSON file (gamy.json): it is moved into
// the database once, then deleted.
const _dataVersion = 2; // raise this when the tables change, and upgrade older saves in _upgrade()

class Store extends ChangeNotifier {
  String lang = 'en';
  bool dark = false; // night mode
  String? agreedTo; // terms version the student accepted (18+ and terms)
  bool pro = true; // Limits are OFF for now (personal use). Set to false when billing is added.
  int uploads = 0; // modules ever uploaded; deleting doesn't give uploads back
  int weekItems = 0; // quiz items made this week
  String? weekStart; // when this week's count started
  bool get agreed => agreedTo == termsVersion;
  List<String> moods = ['idle', 'idle']; // Gamy's sprite in Chat, Quiz
  // In memory the same shape as before, so the screens don't change:
  // [{id, name, modules: [{id, name, text}], scores: [{module, type, right, total, date}]}]
  List<Map<String, dynamic>> subjects = [];
  Database? _db;

  String t(String k) => strings[lang]![k]!;

  Future<void> load() async {
    final dir = (await getApplicationSupportDirectory()).path;
    _db?.close();
    final db = _db = sqlite3.open('$dir/gamy.db');
    _upgrade(db, File('$dir/gamy.json'));
    final s = {for (final r in db.select('SELECT key, value FROM settings')) r['key'] as String: r['value'] as String?};
    lang = s['lang'] ?? 'en';
    dark = s['dark'] == 'true';
    agreedTo = s['agreedTo'];
    uploads = int.tryParse(s['uploads'] ?? '') ?? 0;
    weekItems = int.tryParse(s['weekItems'] ?? '') ?? 0;
    weekStart = s['weekStart'];
    subjects = [
      for (final r in db.select('SELECT id, name FROM subjects ORDER BY id'))
        {
          'id': r['id'],
          'name': r['name'],
          // <Map>: lets new modules and scores (plain maps from the screens) be added to these lists later
          'modules': <Map>[
            for (final m in db.select('SELECT id, name, text FROM modules WHERE subject_id = ? ORDER BY id', [r['id']]))
              {'id': m['id'], 'name': m['name'], 'text': cleanPrivate(m['text'] as String)}
          ],
          'scores': <Map>[
            for (final x in db.select(
                'SELECT module, type, correct, total, date FROM scores WHERE subject_id = ? ORDER BY id', [r['id']]))
              {'module': x['module'], 'type': x['type'], 'right': x['correct'], 'total': x['total'], 'date': x['date']}
          ],
        }
    ];
  }

  // Closes the database (tests use this; the app keeps it open while running).
  void close() {
    _db?.close();
    _db = null;
  }

  // First launch: creates the tables, and moves an old gamy.json save into them (once), all in one go.
  void _upgrade(Database db, File old) {
    if ((db.select('PRAGMA user_version').first['user_version'] as int) >= _dataVersion) return;
    db.execute('BEGIN');
    for (final sql in [
      'CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)',
      'CREATE TABLE IF NOT EXISTS subjects (id INTEGER PRIMARY KEY, name TEXT NOT NULL)',
      'CREATE TABLE IF NOT EXISTS modules (id INTEGER PRIMARY KEY, subject_id INTEGER, name TEXT NOT NULL, text TEXT NOT NULL)',
      'CREATE TABLE IF NOT EXISTS scores (id INTEGER PRIMARY KEY, subject_id INTEGER, module TEXT, type TEXT, '
          'correct INTEGER, total INTEGER, date TEXT)',
      'CREATE TABLE IF NOT EXISTS chunks (id INTEGER PRIMARY KEY, module_id INTEGER, text TEXT NOT NULL, vec BLOB NOT NULL)',
    ]) {
      db.execute(sql);
    }
    if (old.existsSync()) {
      try {
        final j = jsonDecode(old.readAsStringSync()) as Map;
        for (final k in ['lang', 'agreedTo', 'dark', 'uploads', 'weekItems', 'weekStart']) {
          if (j[k] != null) db.execute('INSERT OR REPLACE INTO settings VALUES (?, ?)', [k, '${j[k]}']);
        }
        for (final s in j['subjects'] ?? []) {
          db.execute('INSERT INTO subjects (name) VALUES (?)', [s['name']]);
          _insertAll(db, db.lastInsertRowId, s['modules'] ?? [], s['scores'] ?? []);
        }
      } catch (_) {} // damaged old save file: start fresh instead of crashing
    }
    db.execute('PRAGMA user_version = $_dataVersion');
    db.execute('COMMIT');
    if (old.existsSync()) old.deleteSync(); // it's in the database now
  }

  static void _insertAll(Database db, Object? subjectId, List modules, List scores) {
    for (final m in modules) {
      db.execute('INSERT INTO modules (subject_id, name, text) VALUES (?, ?, ?)', [subjectId, m['name'], m['text']]);
    }
    for (final x in scores) {
      db.execute('INSERT INTO scores (subject_id, module, type, correct, total, date) VALUES (?, ?, ?, ?, ?, ?)',
          [subjectId, x['module'], x['type'], x['right'], x['total'], x['date']]);
    }
  }

  // Saves the settings (a few small rows) and redraws the app.
  void _save() {
    for (final (k, v) in [
      ('lang', lang),
      ('agreedTo', agreedTo),
      ('dark', '$dark'),
      ('uploads', '$uploads'),
      ('weekItems', '$weekItems'),
      ('weekStart', weekStart),
    ]) {
      _db!.execute('INSERT OR REPLACE INTO settings VALUES (?, ?)', [k, v]);
    }
    notifyListeners();
  }

  void setLang() {
    lang = lang == 'en' ? 'fil' : 'en';
    _save();
  }

  void agree() {
    agreedTo = termsVersion;
    _save();
  }

  // ----- Free plan limits -----
  static const freeUploads = 3, freeItems = 70;
  bool get canUpload => pro || uploads < freeUploads;

  // Free students get 70 quiz items per week. The week starts with their first quiz and lasts 7 days.
  bool get _newWeek => weekStart == null || DateTime.now().isAfter(refreshDate);
  DateTime get refreshDate => DateTime.parse(weekStart!).add(const Duration(days: 7));
  int get itemsLeft => pro ? 100 : (_newWeek ? freeItems : freeItems - weekItems);
  String get refreshText => _newWeek ? '' : refreshDate.toIso8601String().substring(0, 10);

  void useItems(int n) {
    if (pro) return;
    if (_newWeek) {
      weekStart = DateTime.now().toIso8601String();
      weekItems = 0;
    }
    weekItems += n;
    _save();
  }

  void toggleDark() {
    dark = !dark;
    _save();
  }

  // "Delete all my data": removes subjects, modules and scores, and asks for the terms again.
  // The free-plan counters stay, so deleting doesn't reset the free limits.
  void reset() {
    for (final table in ['subjects', 'modules', 'scores', 'chunks']) {
      _db!.execute('DELETE FROM $table');
    }
    subjects = [];
    agreedTo = null;
    _save();
  }

  // Changing account: the old account's lessons leave this device (they're safe online), so two people's
  // lessons never mix. Nothing is deleted online. Settings and the free-plan counters stay.
  int fresh = 0; // goes up when the lessons are cleared, so Chat and Quiz start over (see main.dart)
  void clearLessons() {
    for (final table in ['subjects', 'modules', 'scores', 'chunks']) {
      _db!.execute('DELETE FROM $table');
    }
    subjects = [];
    fresh++;
    notifyListeners();
  }

  void setMood(int tab, String m) {
    moods[tab] = m;
    notifyListeners();
  }

  void addSubject(String name) {
    _db!.execute('INSERT INTO subjects (name) VALUES (?)', [name]);
    subjects.add({'id': _db!.lastInsertRowId, 'name': name, 'modules': [], 'scores': []});
    notifyListeners();
    account.saveSubject(name);
  }

  // ----- Restoring from the online copy (account.dart). These don't send anything back online. -----
  Map subjectNamed(String name) {
    for (final s in subjects) {
      if (s['name'] == name) return s;
    }
    _db!.execute('INSERT INTO subjects (name) VALUES (?)', [name]);
    final s = {'id': _db!.lastInsertRowId, 'name': name, 'modules': [], 'scores': []};
    subjects.add(s);
    notifyListeners();
    return s;
  }

  // A restored module doesn't count as an upload (the free plan counted it the first time).
  void restoreModule(Map subject, String name, String text) {
    _put(subject, name, cleanPrivate(text));
    notifyListeners();
  }

  int _put(Map subject, String name, String text) {
    _insertAll(_db!, subject['id'], [
      {'name': name, 'text': text}
    ], const []);
    final id = _db!.lastInsertRowId;
    (subject['modules'] as List).add({'id': id, 'name': name, 'text': text});
    return id;
  }

  // Deletes a subject (with its modules and scores) or one module.
  // [online]: false when the module is being replaced by one with the same name (the upload overwrites it online).
  void remove(List list, Map item, {bool online = true}) {
    if (online && item.containsKey('modules')) {
      account.deleteSubject(item['name']);
    } else if (online && account.user != null) {
      account.deleteModule(subjects.firstWhere((s) => identical(s['modules'], list))['name'], item['name']);
    }
    list.remove(item);
    if (item.containsKey('modules')) {
      _db!.execute('DELETE FROM chunks WHERE module_id IN (SELECT id FROM modules WHERE subject_id = ?)', [item['id']]);
      for (final table in ['modules', 'scores']) {
        _db!.execute('DELETE FROM $table WHERE subject_id = ?', [item['id']]);
      }
      _db!.execute('DELETE FROM subjects WHERE id = ?', [item['id']]);
    } else {
      _db!.execute('DELETE FROM chunks WHERE module_id = ?', [item['id']]);
      _db!.execute('DELETE FROM modules WHERE id = ?', [item['id']]);
    }
    notifyListeners();
  }

  void addScore(Map subject, Map score) {
    _insertAll(_db!, subject['id'], const [], [score]);
    (subject['scores'] as List).add(score);
    notifyListeners();
  }

  // Picks one or more files at once; each becomes its own module. Returns one line per file that failed
  // ("name: reason"), plus 'pro_uploads' at the end if the free plan ran out of uploads halfway.
  // [ask] is called when a file is already in this subject (same name or same text) and answers
  // 'both', 'replace' or 'cancel'.
  Future<List<String>> addModules(Map subject, {Future<String> Function(String name)? ask}) async {
    // Photos can only be read on phones (Google's offline text reader doesn't run on Windows).
    final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'txt', if (Platform.isAndroid) ...['jpg', 'jpeg', 'png']]);
    final failed = <String>[];
    for (final f in files) {
      if (!canUpload) return [...failed, 'pro_uploads'];
      final err = await _addFile(subject, f, ask);
      if (err != null) failed.add('${f.name}: ${t(err)}');
    }
    indexInBackground(); // smart search starts reading the new modules now
    return failed;
  }

  // Reads one picked file into a module. Returns an error key, or null when it was added.
  Future<String?> _addFile(Map subject, PlatformFile f, Future<String> Function(String name)? ask) async {
    final ext = f.name.toLowerCase().split('.').last;
    if (!pro && ['jpg', 'jpeg', 'png'].contains(ext)) return 'pro_photo'; // photo modules are a Pro feature
    if ((await f.length() ?? 0) > _maxBytes) return 'too_big';
    var text = '';
    try {
      final bytes = await f.readAsBytes();
      if (ext == 'pdf') {
        final doc = await PdfDocument.openData(bytes);
        for (final p in doc.pages) {
          text += '${(await p.loadText())?.fullText ?? ''}\n';
        }
        await doc.dispose();
      } else if (ext == 'docx') {
        // A .docx is a zip; the text is in word/document.xml, inside <w:t> tags, one <w:p> per paragraph.
        final xml = utf8.decode(ZipDecoder().decodeBytes(bytes).firstWhere((e) => e.name == 'word/document.xml').content);
        text = xml
            .split('</w:p>')
            .map((p) => RegExp(r'<w:t[^>]*>([^<]*)</w:t>').allMatches(p).map((m) => m[1]).join())
            .join('\n')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&quot;', '"')
            .replaceAll('&apos;', "'")
            .replaceAll('&amp;', '&');
      } else if (ext != 'txt') {
        // Photo: ML Kit reads from a file, so write a temporary copy, read it, then delete it.
        final tmp = File('${(await getTemporaryDirectory()).path}/scan.$ext');
        await tmp.writeAsBytes(bytes);
        final reader = TextRecognizer(script: TextRecognitionScript.latin);
        try {
          text = (await reader.processImage(InputImage.fromFilePath(tmp.path))).text;
        } finally {
          reader.close();
          tmp.delete();
        }
      } else {
        text = utf8.decode(bytes, allowMalformed: true);
      }
    } catch (_) {
      return 'bad_file';
    }
    text = cleanPrivate(text).trim(); // emails, phone numbers, school names... are never saved
    if (text.isEmpty) return 'no_text';
    // Already uploaded? Keep both (as "name (2)"), replace the old one, or skip this file.
    final mods = subject['modules'] as List;
    var name = f.name;
    Map? same;
    for (final m in mods) {
      if (m['name'] == name || m['text'] == text) same = m;
    }
    if (same != null) {
      final choice = ask == null ? 'both' : await ask(name);
      if (choice == 'cancel') return null;
      if (choice == 'replace') {
        remove(mods, same, online: same['name'] != name);
      } else {
        for (var n = 2; mods.any((m) => m['name'] == name); n++) {
          name = '${f.name} ($n)';
        }
      }
    }
    _put(subject, name, text);
    uploads++;
    _save();
    account.saveModule(subject['name'], name, text);
    return null; // smart search reads it in the background (indexInBackground, after the upload)
  }

  // ----- Smart search (needs brain.searchReady) -----
  // The [n] module pieces closest in meaning to the question. Modules uploaded before smart search was
  // downloaded get their pieces made on their first search.
  Future<List<Line>> search(String question, List<Map> modules, int n) async {
    final q = await brain.embedQuestion(question), found = <Line>[];
    for (final m in modules) {
      if (m['id'] == null) continue;
      // Only what smart search has read so far; the keyword search covers the rest meanwhile.
      final rows = _db!.select('SELECT text, vec FROM chunks WHERE module_id = ?', [m['id']]);
      for (final r in rows) {
        found.add((score: (closeness(q, r['vec'] as List<int>) * 1000).round(), text: r['text'] as String, module: '${m['name']}'));
      }
    }
    found.sort((a, b) => b.score.compareTo(a.score));
    indexInBackground();
    return found.take(n).toList();
  }

  // Smart search reads each module once, in the background, 16 pieces at a time, saving as it goes (so
  // closing Gamy halfway loses nothing). Chat never waits for it.
  // Nov 23: it used to read a whole module before answering; a 700-page book took minutes and Gamy looked stuck.
  bool _indexing = false;
  final _read = Set<Map>.identity(); // modules smart search has fully read (so they aren't split up again)
  Future<void> indexInBackground() async {
    if (_indexing || _db == null || !brain.searchReady) return;
    _indexing = true;
    try {
      for (final s in [...subjects]) {
        for (final m in [...s['modules'] as List]) {
          if (m['id'] == null || _read.contains(m)) continue;
          final parts = chunks(m['text'] as String);
          var done = _db!.select('SELECT COUNT(*) AS n FROM chunks WHERE module_id = ?', [m['id']]).first['n'] as int;
          while (done < parts.length) {
            final batch = parts.sublist(done, done + 16 > parts.length ? parts.length : done + 16);
            final vectors = await brain.embedChunks(batch);
            // Deleted meanwhile (or Gamy closed): stop reading it.
            if (_db == null || !subjects.contains(s) || !(s['modules'] as List).contains(m)) break;
            for (var i = 0; i < batch.length; i++) {
              _db!.execute('INSERT INTO chunks (module_id, text, vec) VALUES (?, ?, ?)',
                  [m['id'], batch[i], vectorBytes(vectors[i])]);
            }
            done += batch.length;
          }
          if (done >= parts.length) _read.add(m);
        }
      }
    } catch (e) {
      debugPrint('Smart search reading stopped: $e'); // tried again next time Gamy searches
    } finally {
      _indexing = false;
    }
  }
}

// A meaning vector is stored as raw float32 bytes (768 numbers = 3 KB per piece).
Uint8List vectorBytes(List<double> v) => Float32List.fromList(v).buffer.asUint8List();

// How close a stored piece is to the question in meaning: 1 = same meaning, 0 = unrelated.
double closeness(List<double> question, List<int> stored) {
  final v = Float32List.view(Uint8List.fromList(stored).buffer);
  var dot = 0.0;
  for (var i = 0; i < v.length && i < question.length; i++) {
    dot += v[i] * question[i];
  }
  return dot;
}
