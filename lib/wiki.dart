import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

// ----- Wikipedia lookups: free, no key, online only -----
// Used only when the student's modules don't have the answer (the module always comes first).
// Only the search words are sent, never the modules or anything about the student.
// Wikipedia asks every app to say who it is, with a contact, so they can reach the developer instead of
// blocking the app. Put your email or website here before publishing.
const _agent = 'Gamy/1.0 (study app; contact: CONTACT_EMAIL_HERE)';

typedef WikiPage = ({String title, String text});

final _cache = <String, WikiPage?>{};

// The first few sentences of the Wikipedia page that best matches [words], or null when there's no match,
// no internet, or Wikipedia is slow (6 seconds).
Future<WikiPage?> wiki(String words, {int sentences = 3}) async {
  final key = '$sentences|${words.toLowerCase().trim()}';
  if (_cache.containsKey(key)) return _cache[key];
  HttpClient? client;
  try {
    client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    final req = await client.getUrl(Uri.https('en.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'format': 'json',
      'generator': 'search',
      'gsrsearch': words,
      'gsrlimit': '1',
      'prop': 'extracts',
      'exintro': '1',
      'explaintext': '1',
      'exsentences': '$sentences',
      'redirects': '1',
    }));
    req.headers.set(HttpHeaders.userAgentHeader, _agent);
    final res = await req.close().timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) return null;
    final body = jsonDecode(await res.transform(utf8.decoder).join()) as Map;
    final pages = (body['query']?['pages'] as Map?)?.values;
    if (pages == null || pages.isEmpty) return _cache[key] = null;
    final page = pages.first as Map, text = '${page['extract'] ?? ''}'.trim();
    return _cache[key] = text.isEmpty ? null : (title: '${page['title']}', text: text);
  } catch (e) {
    debugPrint('Wikipedia lookup failed: $e'); // offline, or Wikipedia didn't answer: not cached, try again later
    return null;
  } finally {
    client?.close();
  }
}
