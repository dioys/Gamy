import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';

import 'firebase_options.dart';
import 'store.dart';

// ----- Optional Google account: keeps a copy of the lessons online (Firebase, free Spark plan) -----
// Only subject names and module text go online, into the student's own folder (see firestore/firestore.rules):
//   users/{uid}/subjects/{id}/modules/{id}/parts/{0,1,...}
// Scores, settings, chats and Gamy's brain stay on the device. Without signing in, everything is device-only.

// Android asks Google for a token meant for Firebase's web client (it's in google-services.json; not a secret).
const _webClient = '366280076823-f2vppqneofh850nhedkjioluo86lqbj7.apps.googleusercontent.com';
// Windows uses Google's "Desktop app" client, read from desktop_client.json when building, never kept in the code:
//   flutter run -d windows --dart-define-from-file=desktop_client.json
const _desktopId = String.fromEnvironment('GOOGLE_DESKTOP_ID');
const _desktopSecret = String.fromEnvironment('GOOGLE_DESKTOP_SECRET');

const partChars = 250000; // Firestore allows 1 MB per document: 250k characters fits even for emoji-heavy text
const _maxParts = 25; // the same limits as firestore.rules; anything bigger stays on this device only

// Online document id for a name: the name in base64url (no "/", so any name works). Same name = same document.
String cloudId(String name) => base64Url.encode(utf8.encode(name)).replaceAll('=', '');

// Cuts module text into parts that each fit in one online document, never splitting an emoji in half.
List<String> textParts(String text) {
  final parts = <String>[];
  for (var i = 0; i < text.length;) {
    var end = min(i + partChars, text.length);
    if (end < text.length && (text.codeUnitAt(end - 1) & 0xFC00) == 0xD800) end--;
    parts.add(text.substring(i, end));
    i = end;
  }
  return parts;
}

// Firestore's answer when the free plan's daily limit is used up.
bool backupFull(Object e) => e is FirebaseException && e.code == 'resource-exhausted';

class Account extends ChangeNotifier {
  bool _on = false; // Firebase started (it doesn't in tests, or when it fails)
  bool _google = false; // GoogleSignIn.initialize was called (allowed only once)
  bool busy = false;

  User? get user => _on ? FirebaseAuth.instance.currentUser : null;

  Future<void> start() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      _on = true;
      FirebaseAuth.instance.authStateChanges().listen((u) {
        notifyListeners();
        // Changes that hit the daily limit last time go online now (a full sync only when something is behind).
        if (u != null && store.backupBehind) _quietly(sync);
      });
    } catch (e) {
      debugPrint('Firebase did not start: $e'); // Gamy still works, just without an account
    }
  }

  DocumentReference<Map<String, dynamic>> get _me => FirebaseFirestore.instance.doc('users/${user!.uid}');
  DocumentReference<Map<String, dynamic>> _subject(String name) => _me.collection('subjects').doc(cloudId(name));

  // Returns an error key, or null when signed in (or when the student closed the sign-in).
  // [leaving]: the account being changed away from (see changeAccount).
  Future<String?> signIn({String? leaving}) async {
    if (!_on) return 'sign_in_failed';
    busy = true;
    notifyListeners();
    try {
      final token = await _token();
      if (token == null) return 'sign_in_cancelled'; // closed, or Google stopped it (the reason is in the log)
      await FirebaseAuth.instance.signInWithCredential(GoogleAuthProvider.credential(idToken: token));
      if (leaving != null && user!.uid != leaving) store.clearLessons(); // before sync, so nothing mixes
      if (!(await _me.get()).exists) await _me.set({'created': FieldValue.serverTimestamp()});
      await sync();
      return null;
    } catch (e) {
      debugPrint('Sign-in failed: $e');
      return e == 'no_desktop_key' ? 'no_desktop_key' : 'sign_in_failed';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  // A Google ID token: the phone's account picker on Android, the browser on Windows. Null = cancelled.
  Future<String?> _token() async {
    if (Platform.isWindows) return _desktopToken();
    final g = GoogleSignIn.instance;
    if (!_google) await g.initialize(serverClientId: _webClient);
    _google = true;
    try {
      return (await g.authenticate()).authentication.idToken;
    } on GoogleSignInException catch (e) {
      // Android reports setup problems (fingerprint, client ID) as "canceled" too: print the real reason.
      debugPrint('Google sign-in stopped: ${e.code} ${e.description} ${e.details}');
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  // Windows: opens Google's sign-in page in the browser, which sends the student back to a tiny local page
  // run by Gamy (127.0.0.1). PKCE + state make sure only this Gamy can use the answer.
  Future<String?> _desktopToken() async {
    if (_desktopId.isEmpty || _desktopId.contains('paste')) throw 'no_desktop_key';
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = HttpClient();
    try {
      final redirect = 'http://127.0.0.1:${server.port}', rnd = Random.secure();
      String random() => base64Url.encode(List.generate(32, (_) => rnd.nextInt(256))).replaceAll('=', '');
      final verifier = random(), state = random();
      await launchUrl(
        Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
          'client_id': _desktopId,
          'redirect_uri': redirect,
          'response_type': 'code',
          'scope': 'openid email',
          'code_challenge': base64Url.encode(sha256.convert(ascii.encode(verifier)).bytes).replaceAll('=', ''),
          'code_challenge_method': 'S256',
          'state': state,
          'prompt': 'select_account',
        }),
        mode: LaunchMode.externalApplication,
      );
      // Wait (up to 5 minutes) for the browser to come back with our state; other requests (favicon) are skipped.
      Map<String, String>? back;
      await for (final req in server.timeout(const Duration(minutes: 5))) {
        req.response
          ..headers.contentType = ContentType.html
          ..write('<meta charset="utf-8"><p style="font:20px sans-serif">${store.t('signed_in_tab')}</p>');
        await req.response.close();
        if (req.uri.queryParameters['state'] == state) {
          back = req.uri.queryParameters;
          break;
        }
      }
      final code = back?['code'];
      if (code == null) return null; // the student pressed Cancel on Google's page
      final post = await client.postUrl(Uri.parse('https://oauth2.googleapis.com/token'));
      post.headers.contentType = ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
      post.write(Uri(queryParameters: {
        'code': code,
        'client_id': _desktopId,
        'client_secret': _desktopSecret,
        'redirect_uri': redirect,
        'grant_type': 'authorization_code',
        'code_verifier': verifier,
      }).query);
      final res = await post.close();
      final body = jsonDecode(await res.transform(utf8.decoder).join()) as Map;
      if (res.statusCode != 200) throw 'token ${res.statusCode}: ${body['error']}';
      return body['id_token'] as String;
    } finally {
      client.close();
      await server.close(force: true);
    }
  }

  // Switches Google accounts. Only after every change reached the old account's online copy (so nothing is
  // lost), and the old lessons leave this device once the new account is in. Cancelled = nothing changes.
  Future<String?> changeAccount() async {
    final old = user!.uid;
    try {
      await FirebaseFirestore.instance.waitForPendingWrites().timeout(const Duration(seconds: 15));
    } catch (_) {
      return 'change_offline';
    }
    if (_google) await GoogleSignIn.instance.signOut(); // so Android shows the account picker again
    return signIn(leaving: old);
  }

  // Lessons on this device stay; only the online link ends.
  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    if (_google) await GoogleSignIn.instance.signOut();
  }

  // Deletes the online copy and the account itself. Lessons on this device stay. Returns an error key or null.
  Future<String?> deleteAccount() async {
    busy = true;
    notifyListeners();
    try {
      for (final s in (await _me.collection('subjects').get()).docs) {
        await _deleteSubject(s.reference);
      }
      await _me.delete();
      try {
        await user!.delete();
      } on FirebaseAuthException catch (e) {
        if (e.code != 'requires-recent-login') rethrow;
        // Google wants a fresh sign-in before deleting an account: ask once more, then delete.
        final token = await _token();
        if (token == null) return 'sign_in_failed';
        await user!.reauthenticateWithCredential(GoogleAuthProvider.credential(idToken: token));
        await user!.delete();
      }
      if (_google) await GoogleSignIn.instance.signOut();
      return null;
    } catch (e) {
      debugPrint('Delete account failed: $e');
      return 'sign_in_failed';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _deleteSubject(DocumentReference s) async {
    for (final m in (await s.collection('modules').get()).docs) {
      for (final p in (await m.reference.collection('parts').get()).docs) {
        await p.reference.delete();
      }
      await m.reference.delete();
    }
    await s.delete();
  }

  // After signing in: lessons that are online but not on this device come down, and the ones only on this
  // device go up. Matched by name.
  Future<void> sync() async {
    final online = <String>{};
    for (final s in (await _me.collection('subjects').get()).docs) {
      final name = s['name'] as String, local = store.subjectNamed(name);
      online.add(name);
      final here = {for (final m in local['modules']) m['name']}, there = <String>{};
      for (final m in (await s.reference.collection('modules').get()).docs) {
        there.add(m['name']);
        if (here.contains(m['name'])) continue;
        final parts = await Future.wait(
            [for (var i = 0; i < (m['parts'] as int); i++) m.reference.collection('parts').doc('$i').get()]);
        store.restoreModule(local, m['name'], parts.map((p) => p['text'] as String).join());
      }
      for (final m in local['modules']) {
        if (!there.contains(m['name'])) await _saveModule(name, m['name'], m['text']);
      }
    }
    for (final s in store.subjects.where((s) => !online.contains(s['name']))) {
      await _saveSubject(s['name']);
      for (final m in s['modules']) {
        await _saveModule(s['name'], m['name'], m['text']);
      }
    }
  }

  // Called by the store on every change. They do nothing when signed out, and never stop the app on errors
  // (offline: Firebase keeps the change and sends it when the internet is back).
  void saveSubject(String name) => _quietly(() => _saveSubject(name));
  void saveModule(String subject, String name, String text) => _quietly(() => _saveModule(subject, name, text));
  void deleteSubject(String name) => _quietly(() => _deleteSubject(_subject(name)));
  void deleteModule(String subject, String name) => _quietly(() async {
        final m = _subject(subject).collection('modules').doc(cloudId(name));
        final n = (await m.get()).data()?['parts'] as int? ?? 0;
        await m.delete(); // the module first, so a half-deleted one is never restored
        for (var i = 0; i < n; i++) {
          await m.collection('parts').doc('$i').delete();
        }
      });

  void _quietly(Future<void> Function() job) {
    if (user == null) return;
    job().then((_) {
      if (job == sync) store.setBackupBehind(false);
    }).catchError((Object e) {
      debugPrint('Online copy not updated: $e');
      // The free plan's daily limit: the student is told, and it's synced at the next start.
      if (backupFull(e)) store.setBackupBehind(true);
    });
  }

  Future<void> _saveSubject(String name) async {
    if (name.length > 100) return;
    await _subject(name).set({'name': name, 'updated': FieldValue.serverTimestamp()});
  }

  Future<void> _saveModule(String subject, String name, String text) async {
    final parts = textParts(text);
    if (subject.length > 100 || name.length > 200 || parts.length > _maxParts) return; // too big to copy online
    await _saveSubject(subject);
    final m = _subject(subject).collection('modules').doc(cloudId(name));
    for (var i = 0; i < parts.length; i++) {
      await m.collection('parts').doc('$i').set({'text': parts[i]});
    }
    // The module itself last, so it only shows up online once all of its text is there.
    await m.set({'name': name, 'parts': parts.length, 'updated': FieldValue.serverTimestamp()});
  }
}

final account = Account();
