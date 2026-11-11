import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import 'strings.dart';
import 'terms.dart';

final store = Store();
const _maxBytes = 20 * 1024 * 1024;
const _vault = FlutterSecureStorage(); // the device's locked storage (Windows Credential Manager / Android Keystore)

// Everything is saved only on this device: the AI key in locked storage, the rest in one small JSON file.
class Store extends ChangeNotifier {
  String lang = 'en';
  bool dark = false; // night mode
  String? agreedTo; // terms version the student accepted (18+ and terms)
  bool pro = true; // Limits are OFF for now (personal use). Set to false when billing is added.
  int uploads = 0; // modules ever uploaded; deleting doesn't give uploads back
  int weekItems = 0; // quiz items made this week
  String? weekStart; // when this week's count started
  String? key, url, model; // the student's own AI account; url == null means OpenRouter login (key lives in _vault)
  bool get agreed => agreedTo == termsVersion;
  List<String> moods = ['idle', 'idle']; // Gamy's sprite in Chat, Quiz
  List<Map<String, dynamic>> subjects = [];
  late File _file;

  String t(String k) => strings[lang]![k]!;

  Future<void> load() async {
    _file = File('${(await getApplicationSupportDirectory()).path}/gamy.json');
    if (_file.existsSync()) {
      Map j = {};
      try {
        j = jsonDecode(_file.readAsStringSync());
      } catch (_) {} // damaged save file: start fresh instead of crashing
      lang = j['lang'] ?? 'en';
      agreedTo = j['agreedTo'];
      dark = j['dark'] ?? false;
      uploads = j['uploads'] ?? 0;
      weekItems = j['weekItems'] ?? 0;
      weekStart = j['weekStart'];
      url = j['url'];
      model = j['model'];
      subjects = List<Map<String, dynamic>>.from(j['subjects'] ?? []);
      if (j['key'] != null) connect(j['key'], url, model); // move an old plain-file key into locked storage
    }
    key ??= await _vault.read(key: 'ai_key');
  }

  void _save() {
    _file.writeAsStringSync(jsonEncode({'lang': lang, 'agreedTo': agreedTo, 'dark': dark, 'uploads': uploads, 'weekItems': weekItems, 'weekStart': weekStart, 'url': url, 'model': model, 'subjects': subjects}));
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

  void connect(String? k, [String? u, String? m]) {
    key = k;
    k == null ? _vault.delete(key: 'ai_key') : _vault.write(key: 'ai_key', value: k);
    url = u;
    model = m;
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

  // "Delete all my data": removes subjects, modules, scores and the AI key, and asks for the terms again.
  // The free-plan counters stay, so deleting doesn't reset the free limits.
  void reset() {
    subjects = [];
    agreedTo = null;
    connect(null); // also deletes the key from locked storage and saves
  }

  void setMood(int tab, String m) {
    moods[tab] = m;
    notifyListeners();
  }

  void addSubject(String name) {
    subjects.add({'name': name, 'modules': [], 'scores': []});
    _save();
  }

  void remove(List list, Object item) {
    list.remove(item);
    _save();
  }

  void addScore(Map subject, Map score) {
    (subject['scores'] as List).add(score);
    _save();
  }

  // Returns an error key, or null when the module was added (or picking was cancelled).
  Future<String?> addModule(Map subject) async {
    // Photos can only be read on phones (Google's offline text reader doesn't run on Windows).
    final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'txt', if (Platform.isAndroid) ...['jpg', 'jpeg', 'png']]);
    if (files.isEmpty) return null;
    final f = files.first;
    if ((await f.length() ?? 0) > _maxBytes) return 'too_big';
    var text = '';
    try {
      final bytes = await f.readAsBytes();
      final ext = f.name.toLowerCase().split('.').last;
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
    text = text.trim();
    if (text.isEmpty) return 'no_text';
    (subject['modules'] as List).add({'name': f.name, 'text': text});
    uploads++;
    _save();
    return null;
  }
}
