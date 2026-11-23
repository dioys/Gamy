import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:llamadart/llamadart.dart';
import 'package:path_provider/path_provider.dart';

import 'store.dart';

// ----- Gamy's brain: a small AI model that runs on this device (llama.cpp through llamadart) -----
// Downloaded once, then it works offline. No API keys, no server.
// Model: Qwen3 0.6B (Apache 2.0), Q4_K_M quantization, about 480 MB (the best quality for its size).
// To try another .gguf model, change these two lines (and the size shown in strings.dart).
const _url = 'https://huggingface.co/bartowski/Qwen_Qwen3-0.6B-GGUF/resolve/main/Qwen_Qwen3-0.6B-Q4_K_M.gguf';
const _name = 'brain.gguf';
// Smart search (like LlamaIndex, but on the device): EmbeddingGemma 300M (Gemma license), Q4_0, about 280 MB
// (almost the same quality as the 330 MB Q8_0). An optional extra download, so the brain alone stays smaller.
// It turns text into "meaning vectors", so Gamy finds lines by meaning, even across English and Taglish.
const _searchUrl = 'https://huggingface.co/unsloth/embeddinggemma-300m-GGUF/resolve/main/embeddinggemma-300m-Q4_0.gguf'; // lowercase "m": the exact file name on Hugging Face
const _searchName = 'search.gguf';

// Who Gamy is, for every brain request (Chat and Quiz). Kept short: short prompts = fast replies.
// Savage and funny every time, with slang (Taglish in Filipino), but the roast is about the answer,
// never about who the person is.
String gamyIs() => 'You are Gamy, a savage, funny study bear for college students. '
    'Every reply roasts a little: no mercy for wrong answers or lazy questions, '
    'but you still give the right answer. Roast the answer, not the person: no slurs, no insults about '
    'looks, family or identity. Never say that you are joking or roasting.'
    ' Use at most one short joke, never several in a row.'
    '${store.lang == 'fil' ? ' Reply in Taglish like a Filipino barkada, with slang like "boi" or "ang lala".' : ' Use casual slang like "bro" or "big yikes".'}';

// Why a download failed, in words the student can act on (Nov 22: every failure used to say "check your
// internet and free space", even when the real problem was a wrong file name online).
String whyFailed(Object e) {
  if (e is FileSystemException) {
    final code = e.osError?.errorCode;
    // 28 = disk full on Android/Linux, 112 = disk full on Windows
    if (code == 28 || code == 112 || '${e.osError?.message}'.toLowerCase().contains('space')) return 'why_space';
  }
  if (e is SocketException || e is HandshakeException || e is HttpException || e is TimeoutException) return 'why_net';
  if ('$e'.startsWith('HTTP ')) return 'why_missing'; // the server answered, but has no such file (404, 403...)
  return 'why_cut';
}

class Brain extends ChangeNotifier {
  LlamaEngine? _engine, _search; // the chat model and the smart search model
  Future<void> _turn = Future.value(); // requests wait for the one before them to finish
  bool has = false, hasSearch = false; // the brain / smart search files are on this device
  double? progress; // 0..1 while downloading, null otherwise
  bool searching = false; // the download in progress is smart search (not the brain)
  bool loading = false;

  bool get ready => _engine != null;
  bool get searchReady => _search != null;

  Future<File> _fileOf(String name) async => File('${(await getApplicationSupportDirectory()).path}/$name');

  // On app start: load whatever was downloaded before, in the background.
  Future<void> start() async {
    has = await (await _fileOf(_name)).exists();
    hasSearch = await (await _fileOf(_searchName)).exists();
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
    store.indexInBackground(); // smart search starts reading any module it hasn't read yet
  }

  // Downloads the brain, or smart search when [search] is true, with progress. Saves to a .part file first,
  // so a cut download is never used. Returns null when done, or why it failed (a strings.dart key, see whyFailed).
  Future<String?> download({bool search = false}) async {
    if (progress != null) return null; // one download at a time (the button is off meanwhile)
    final client = HttpClient();
    final file = await _fileOf(search ? _searchName : _name), part = File('${file.path}.part');
    try {
      searching = search;
      progress = 0;
      notifyListeners();
      final res = await (await client.getUrl(Uri.parse(search ? _searchUrl : _url))).close();
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
      if (res.contentLength > 0 && got < res.contentLength) throw 'cut'; // the connection ended early
      await part.rename(file.path);
      if (search) {
        hasSearch = true;
      } else {
        has = true;
      }
      progress = null;
      notifyListeners();
      await _load();
      return null;
    } catch (e) {
      debugPrint('Download failed: $e');
      if (await part.exists()) await part.delete();
      progress = null;
      notifyListeners();
      return whyFailed(e);
    } finally {
      client.close();
    }
  }

  // Unloads and deletes the brain, or smart search when [search] is true, to free the space.
  Future<void> remove({bool search = false}) async {
    if (search) {
      await _search?.dispose();
      _search = null;
      hasSearch = false;
    } else {
      await _engine?.dispose();
      _engine = null;
      has = false;
    }
    final file = await _fileOf(search ? _searchName : _name);
    if (await file.exists()) await file.delete();
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
  // The smart search model does one job at a time: a chat question waits for the current small batch of
  // background reading (a second or two), never for a whole module.
  Future<void> _searchTurn = Future.value();
  Future<T> _oneAtATime<T>(Future<T> Function() job) {
    final done = _searchTurn.then((_) => job());
    _searchTurn = done.then((_) {}, onError: (_) {});
    return done;
  }

  Future<List<List<double>>> embedChunks(List<String> chunks) =>
      _oneAtATime(() => _search!.embedBatch([for (final c in chunks) 'title: none | text: $c']));
  Future<List<double>> embedQuestion(String question) =>
      _oneAtATime(() => _search!.embed('task: search result | query: $question'));
}

final brain = Brain();
