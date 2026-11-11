# Gamy 🐻

A blunt, roasting talking-bear study buddy. Students upload their school modules, and Gamy turns them into quizzes and chats with them about the lesson.

Built with **Flutter** (Dart) for **Android** and **Windows**.

## Features
- **Chat** with Gamy about a chosen module. He's blunt, roasts wrong answers (never the person) and fixes spelling ✏️
- **Quizzes from your own modules:** multiple choice, true or false, fill in the blank, identification, matching, mixed (1–100 questions)
- **Review:** right answers in green, wrong in red, with explanations of both the correct answer and yours
- **Modules:** PDF, Word (.docx), text, and photos (Android, read offline)
- **Subjects** you create yourself, and score history
- Animated Gamy (thinking, talking, napping, reactions) and quotes during quizzes
- English and Filipino, night mode

## Privacy
- No accounts, and nothing is collected. Everything is saved **on the device only**.
- Students connect **their own AI account** (Log in with OpenRouter, or paste an API key). Module text goes straight from the device to that AI service.
- The AI key is kept in the device's locked storage.

## Project layout
| File | What it does |
|---|---|
| `lib/main.dart` | App start, layout, light/night themes |
| `lib/store.dart` | Saves data on the device, reads modules, free-plan limits |
| `lib/ai.dart` | Talks to the AI, recognizes keys, OpenRouter login |
| `lib/setup.dart` | Age check, terms, connect AI |
| `lib/chat.dart` | Chat screen and Gamy's personality |
| `lib/quiz.dart` | Making, answering and reviewing quizzes |
| `lib/upload.dart` | Subjects and modules |
| `lib/settings.dart` | Settings screen |
| `lib/paywall.dart` | Gamy Pro and AI-limit pop-ups |
| `lib/gamy.dart` | Gamy's animation, speech bubble, quotes |
| `lib/strings.dart` | All English and Filipino text |
| `lib/terms.dart` | Terms of Use and Privacy Policy |
| `assets/gamy/` | Gamy's drawings (original art) |

## Run and build
```
flutter pub get
flutter run -d windows                 # on PC
flutter run -d <phone id>              # on an Android phone (see: flutter devices)
flutter build apk --release --split-per-abi
```

## Status
Personal use for now. Free-plan limits are off (`pro = true` in `lib/store.dart`).
Before publishing: billing, error monitoring, a redesign and debug pass, and the legal checklist.

© 2026 BuddyBear. All rights reserved. Gamy's character and artwork are original and not licensed for reuse.
