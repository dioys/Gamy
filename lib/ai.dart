import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:url_launcher/url_launcher.dart';

import 'store.dart';

const openRouterUrl = 'https://openrouter.ai/api/v1';

// Sends one request. Throws a short error key that the screens turn into a message:
// 'limit' (too many requests), 'bad_key' (key rejected), 'not_found' (wrong address or model),
// 'offline' (can't reach it), 'slow' (no answer in 90 s) or 'ai_error' (anything else).
Future<String> _send(String method, String url, [Map? body, String? key]) async {
  final c = HttpClient();
  try {
    final r = await c.openUrl(method, Uri.parse(url));
    if (key != null) r.headers.set('Authorization', 'Bearer $key');
    if (body != null) {
      r.headers.contentType = ContentType.json;
      r.add(utf8.encode(jsonEncode(body)));
    }
    const wait = Duration(seconds: 90);
    final res = await r.close().timeout(wait);
    final text = await res.transform(utf8.decoder).join().timeout(wait);
    final s = res.statusCode;
    if (s == 429) throw 'limit';
    if (s == 401 || s == 403) throw 'bad_key';
    if (s == 404 || (s == 400 && text.contains('model'))) throw 'not_found';
    if (s >= 300) throw 'ai_error';
    return text;
  } on TimeoutException {
    throw 'slow';
  } on SocketException {
    throw 'offline';
  } on HandshakeException {
    throw 'offline';
  } on FormatException {
    throw 'not_found'; // a badly typed address
  } finally {
    c.close();
  }
}

// Works with any service that offers the common "OpenAI-compatible" chat API.
// url == null means the student's OpenRouter account (login or an OpenRouter key).
Future<String> ask(List<Map<String, String>> messages) async {
  final j = jsonDecode(await _send('POST', '${store.url ?? openRouterUrl}/chat/completions',
      {'model': store.model ?? 'openrouter/free', 'messages': messages}, store.key));
  return j['choices'][0]['message']['content'] as String;
}

String get langRule => store.lang == 'fil'
    ? 'Write in Filipino (Tagalog), keeping technical terms in English.'
    : 'Write in English.';

// ----- Pasting a key: Gamy recognizes popular services from how their keys start,
// so students only paste the key. (Order matters: 'sk-or-' must come before 'sk-'.)
const _known = {
  'sk-or-': openRouterUrl,
  'gsk_': 'https://api.groq.com/openai/v1',
  'AIza': 'https://generativelanguage.googleapis.com/v1beta/openai',
  'sk-': 'https://api.openai.com/v1',
};

String? knownUrl(String key) {
  for (final e in _known.entries) {
    if (key.startsWith(e.key)) return e.value;
  }
  return null;
}

// Asks the service which models it has and picks a good, cheap one.
const _preferred = ['llama-3.3-70b', 'gpt-4o-mini', 'gemini-2.5-flash', 'flash', 'mini'];

Future<String> pickModel(String url, String key) async {
  final data = jsonDecode(await _send('GET', '$url/models', null, key))['data'] as List;
  final ids = [for (final m in data) '${m['id']}'.replaceFirst('models/', '')];
  if (ids.isEmpty) throw 'not_found';
  for (final p in _preferred) {
    for (final id in ids) {
      if (id.contains(p)) return id;
    }
  }
  return ids.first;
}

// One tiny test message, so a wrong key, address or model is caught before saving.
Future<void> testAi(String url, String model, String key) => _send('POST', '$url/chat/completions', {
      'model': model,
      'messages': [
        {'role': 'user', 'content': 'Reply with just: OK'}
      ],
    }, key);

// ----- Log in with OpenRouter (PKCE: a secret "verifier" proves the login code is really ours).
String _b64(List<int> b) => base64Url.encode(b).replaceAll('=', '');
String newVerifier() => _b64(List.generate(32, (_) => Random.secure().nextInt(256)));

Uri _authUrl(String verifier, [String? callback]) => Uri.parse('https://openrouter.ai/auth?'
    '${callback == null ? '' : 'callback_url=${Uri.encodeComponent(callback)}&'}'
    'code_challenge=${_b64(sha256.convert(ascii.encode(verifier)).bytes)}&code_challenge_method=S256');

Future<String?> exchangeCode(String code, String verifier) async {
  final j = jsonDecode(await _send('POST', '$openRouterUrl/auth/keys',
      {'code': code.trim(), 'code_verifier': verifier, 'code_challenge_method': 'S256'}));
  return j['key'] as String?;
}

// Phones: open the login page without a callback; OpenRouter then shows a code to paste into Gamy.
Future<void> openRouterPhoneLogin(String verifier) =>
    launchUrl(_authUrl(verifier), mode: LaunchMode.externalApplication);

// Windows: OpenRouter sends the login code straight back to Gamy on localhost.
Future<String?> openRouterLogin() async {
  final verifier = newVerifier();
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  try {
    await launchUrl(_authUrl(verifier, 'http://localhost:${server.port}/callback'));
    final req = await server
        .firstWhere((r) => r.uri.path == '/callback')
        .timeout(const Duration(minutes: 5));
    final code = req.uri.queryParameters['code'];
    req.response
      ..headers.contentType = ContentType.html
      ..write('<h2>Gamy is connected! You can close this tab.</h2>');
    await req.response.close();
    return code == null ? null : await exchangeCode(code, verifier); // wait here, before 'finally' runs
  } finally {
    await server.close(force: true);
  }
}
