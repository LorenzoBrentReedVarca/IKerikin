# IKeriKin

> **I Care for Your Kin**

IKeriKin is an accessible, AI-assisted learning app for Filipino families with
children who have special educational needs. It creates personalized stories,
flashcards, quizzes, memory games, matching activities, and parent guidance
from each learner's profile and goals.

**Repository:** [github.com/LorenzoBrentReedVarca/IKeriKin](https://github.com/LorenzoBrentReedVarca/IKeriKin)

## Features

- Parent registration, login, recovery, and offline preview mode
- Multiple child profiles with needs, interests, challenges, and learning styles
- Personalized AI lesson generation in English and Filipino
- Stories, text-to-speech, flashcards, quizzes, memory, and matching activities
- Daily goals, XP, coins, streaks, badges, and lesson recommendations
- Weekly, monthly, and all-time progress views
- Large text, dyslexia-friendly font, high contrast, and reduced motion settings
- Optional Supabase authentication, persistence, storage, and Edge Functions

## Project Structure

```text
lib/
	application/   Riverpod providers and controllers
	core/          Configuration, routing, theme, localization, accessibility
	data/          Local/Supabase repositories and AI providers
	domain/        Application models
	presentation/  Screens and reusable widgets
supabase/
	functions/     AI lesson and video Edge Functions
	migrations/    Database schema and progress tracking
docs/            Proposal, PDF, and required screenshots
```

## Run Locally

Requirements: Flutter SDK compatible with Dart `^3.11.5`.

```powershell
flutter pub get
flutter run
```

Without Supabase defines, IKeriKin runs in offline preview mode using local
storage and its built-in educational content provider.

To enable Supabase:

```powershell
flutter run `
	--dart-define=SUPABASE_URL=https://your-project.supabase.co `
	--dart-define=SUPABASE_ANON_KEY=your_publishable_key
```

Keep provider secrets in Supabase, never in Flutter source or Dart defines.

## AI Edge Functions

```powershell
supabase secrets set AI_API_KEY=your_provider_key
supabase functions deploy generate-lesson
supabase functions deploy generate-video
```

The video provider is isolated behind the `generate-video` function so it can
be replaced without changing Flutter playback. OpenAI's Sora 2 Videos API is
currently scheduled for shutdown on September 24, 2026.

## Validation

```powershell
flutter analyze
flutter test
```

## Documentation

- [Revised project proposal](docs/PROJECT_PROPOSAL.md)
- [PDF project proposal](docs/IKeriKin_Project_Proposal.pdf)
- [Required screenshots](docs/screenshots)
