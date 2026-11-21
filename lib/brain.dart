import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:llamadart/llamadart.dart';
import 'package:path_provider/path_provider.dart';

import 'store.dart';

// ----- Gamy's brain: a small AI model that runs on this device (llama.cpp through llamadart) -----
// Downloaded once, then it works offline. No API keys, no server.
// Model: Qwen3 0.6B (Apache 2.0), Q4_K_M quantization, about 480 MB.
// To try another .gguf model, change these two lines (and the size shown in strings.dart).
const _url = 'https://huggingface.co/bartowski/Qwen_Qwen3-0.6B-GGUF/resolve/main/Qwen_Qwen3-0.6B-Q4_K_M.gguf';
const _name = 'brain.gguf';
// Smart search (like LlamaIndex, but on the device): EmbeddingGemma 300M (Gemma license), Q8_0, about 330 MB.
// It turns text into "meaning vectors", so Gamy finds lines by meaning, even across English and Taglish.
const _searchUrl = 'https://huggingface.co/unsloth/embeddinggemma-300m-GGUF/resolve/main/embeddinggemma-300M-Q8_0.gguf';
const _searchName = 'search.gguf';
const _files = [(_url, _name), (_searchUrl, _searchName)];

// Who Gamy is, for every brain request (Chat and Quiz). Kept short: short prompts = fast replies.
// Savage and funny every time, with slang (Taglish in Filipino), but the roast is about the answer,
// never about who the person is.
String gamyIs() => 'You are Gamy, a savage, funny study bear for college students. '
    'Every reply is short and roasts a little: no mercy for wrong answers or lazy questions, '
    'but you still give the right answer. Roast the answer, not the person: no slurs, no insults about '
    'looks, family or identity. Never say that you are joking or roasting.'
    ' Use at most one short joke, never several in a row.'
    '${store.lang == 'fil' ? ' Reply in Taglish like a Filipino barkada, with slang like "boi" or "ang lala".' : ' Use casual slang like "bro" or "big yikes".'}';

class Brain extends ChangeNotifier {
  LlamaEngine? _engine, _search; // the chat model and the smart search model
  Future<void> _turn = Future.value(); // requests wait for the one before them to finish
  bool has = false; // both model files are on this device
  double? progress; // 0..1 while downloading, null otherwise
  int step = 0, steps = 0; // which file is downloading ("1/2")
  bool loading = false;

  bool get ready => _engine != null;
  bool get searchReady => _search != null;

  Future<File> _fileOf(String name) async => File('${(await getApplicationSupportDirectory()).path}/$name');

  // On app start: load whatever was downloaded before, in the background.
  Future<void> start() async {
    has = await (await _fileOf(_name)).exists() && await (await _fileOf(_searchName)).exists();
    notifyListeners();
    await _load();
  }

  // Loads each downloaded model into memory once; they stay loaded while the app is open.
  Future<void> _load() async {
    loading = true;
    notifyListeners();
    for (final name in [_name, _searchName]) {
      final file = await _fileOf(name), search = name == _searchName;
      if (!await file.exists() || (search ? _search : _engine) != null) continue;
      try {
        final e = await LlamaEngine.load(
          LlamaModel(ModelSource.path(file.path)),
          params: const LlamaCppModelParams(contextSize: 2048), // short prompts only, so a small context is enough
        );
        if (search) {
          _search = e;
        } else {
          _engine = e;
        }
      } catch (e) {
        debugPrint('Brain failed to load $name: $e');
      }
    }
    loading = false;
    notifyListeners();
  }

  // Downloads the model with progress. Saves to a .part file first, so a cut download is never used.
  // Returns false if it failed (no internet, not enough space...).
  // Downloads only the files that are missing (someone who has the brain gets just smart search).
  Future<bool> download() async {
    final client = HttpClient();
    File? part;
    try {
      final missing = [
        for (final (url, name) in _files)
          if (!await (await _fileOf(name)).exists()) (url, name)
      ];
      steps = missing.length;
      for (final (url, name) in missing) {
        step++;
        final file = await _fileOf(name);
        part = File('${file.path}.part');
        progress = 0;
        notifyListeners();
        final res = await (await client.getUrl(Uri.parse(url))).close();
        if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';
        final sink = part.openWrite();
        var got = 0;
        await for (final chunk in res) {
          sink.add(chunk);
          got += chunk.length;
          if (res.contentLength > 0) {
            progress = got / res.contentLength;
            notifyListeners();
          }
        }
        await sink.close();
        await part.rename(file.path);
      }
      has = true;
      progress = null;
      step = steps = 0;
      notifyListeners();
      await _load();
      return true;
    } catch (e) {
      debugPrint('Brain download failed: $e');
      if (part != null && await part.exists()) await part.delete();
      progress = null;
      step = steps = 0;
      notifyListeners();
      return false;
    } finally {
      client.close();
    }
  }

  // Unloads and deletes the model to free the space.
  Future<void> remove() async {
    await _engine?.dispose();
    await _search?.dispose();
    _engine = _search = null;
    for (final (_, name) in _files) {
      final file = await _fileOf(name);
      if (await file.exists()) await file.delete();
    }
    has = false;
    notifyListeners();
  }

  // Streams the reply word by word. [system] = who Gamy is and what he knows, [user] = the question.
  // One request at a time: if Chat and Quiz both ask, the second one waits its turn.
  Stream<String> say(String system, String user, {int maxTokens = 160}) async* {
    final before = _turn, mine = Completer<void>();
    _turn = mine.future;
    await before;
    try {
      yield* _engine!
          .create(
            [
              LlamaChatMessage.fromText(role: LlamaChatRole.system, text: system),
              LlamaChatMessage.fromText(role: LlamaChatRole.user, text: user),
            ],
            params: GenerationParams(maxTokens: maxTokens, temp: 0.7),
            enableThinking: false, // Qwen3 would otherwise "think" out loud first, which is slow
          )
          .textDeltas();
    } finally {
      mine.complete(); // also runs if the screen stops listening halfway
    }
  }

  // Smart search. Vectors come back normalized, so closeness in meaning = the dot product of two vectors.
  // The text formats are the ones the model was trained with ("document" vs "query").
  Future<List<List<double>>> embedChunks(List<String> chunks) =>
      _search!.embedBatch([for (final c in chunks) 'title: none | text: $c']);
  Future<List<double>> embedQuestion(String question) => _search!.embed('task: search result | query: $question');
}

final brain = Brain();
