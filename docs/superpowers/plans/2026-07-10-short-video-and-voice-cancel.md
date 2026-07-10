# Short Video and Voice Cancel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add cancellable voice recording, chat auto-scroll on keyboard/message changes, 15-second video messages, and 15-second profile media videos.

**Architecture:** Extend backend media/message types with `VIDEO` and add media metadata to existing profile album records. Enforce video duration limits in backend DTO/service paths and client-side before upload/send. Flutter adds video selection/playback with `video_player`, scroll coordination in chat, and a cancellable voice recording UI.

**Tech Stack:** NestJS, Prisma, PostgreSQL migrations, Jest, Flutter, image_picker, video_player, just_audio, record.

---

### Task 1: Backend Video Schema and Validation

**Files:**
- Modify: `apps/api/prisma/schema.prisma`
- Create: `apps/api/prisma/migrations/20260710162000_add_video_media/migration.sql`
- Modify: `apps/api/src/messages/dto/send-message.dto.ts`
- Modify: `apps/api/src/uploads/uploads.controller.ts`
- Modify: `apps/api/src/uploads/uploads.service.ts`
- Modify: `apps/api/src/users/dto/add-album-photo.dto.ts`
- Modify: `apps/api/src/users/users.service.spec.ts`
- Modify: `apps/api/src/uploads/uploads.service.spec.ts`

- [ ] Add `VIDEO` to `MessageType`.
- [ ] Add `type` and `durationMs` to `UserAlbumPhoto`.
- [ ] Allow upload type `VIDEO` and reject videos over 15 seconds when duration metadata is provided.
- [ ] Allow message type `VIDEO` and reject video messages over 15 seconds.
- [ ] Preserve old photo records as `IMAGE`.

### Task 2: Flutter Video Models, Upload, and Playback

**Files:**
- Modify: `apps/mobile/pubspec.yaml`
- Modify: `apps/mobile/android/app/src/main/AndroidManifest.xml`
- Modify: `apps/mobile/ios/Runner/Info.plist`
- Modify: `apps/mobile/lib/src/models/chat_models.dart`
- Modify: `apps/mobile/lib/src/services/api_client.dart`
- Create: `apps/mobile/lib/src/screens/video_player_screen.dart`
- Modify: `apps/mobile/lib/src/services/app_strings.dart`

- [ ] Add `video_player`.
- [ ] Parse album media type and duration.
- [ ] Add upload duration metadata.
- [ ] Add localized labels and errors.
- [ ] Add a reusable full-screen video player screen.

### Task 3: Chat Video and Scroll Behavior

**Files:**
- Modify: `apps/mobile/lib/src/screens/chat_screen.dart`

- [ ] Add `ScrollController`.
- [ ] Scroll to bottom after load, incoming message, local send, and keyboard inset change.
- [ ] Add video button and video message bubble.
- [ ] Validate picked video duration `<= 15s`.
- [ ] Send `VIDEO` message with duration metadata.
- [ ] Add voice cancel button while recording.

### Task 4: Profile Dynamic Video

**Files:**
- Modify: `apps/mobile/lib/src/screens/profile_screen.dart`

- [ ] Add upload video action next to add photo.
- [ ] Validate picked profile video duration `<= 15s`.
- [ ] Upload and save album media as `VIDEO`.
- [ ] Render video tiles with play icon and duration.

### Task 5: Verification and Deployment

- [ ] Run `npm --prefix apps/api run prisma:generate`.
- [ ] Run `npm --prefix apps/api test`.
- [ ] Run `npm --prefix apps/api run build`.
- [ ] Run `flutter pub get`.
- [ ] Run `flutter analyze`.
- [ ] Run `flutter test`.
- [ ] Run `flutter build apk --debug`.
- [ ] Install on Android emulator and check startup logs.
- [ ] Commit and push.
- [ ] Deploy backend to Tencent Cloud, run migrations, rebuild API, and verify routes.
