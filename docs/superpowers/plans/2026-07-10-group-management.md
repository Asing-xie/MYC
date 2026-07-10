# Group Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add v1 group chat management: owner role, group settings, rename, add/remove members, leave group, dissolve group, and GM override.

**Architecture:** Store group permissions on `ConversationMember.role`, enforce all management permissions in NestJS, and expose focused REST endpoints under `/conversations/:id`. Flutter adds a group settings screen launched from the chat app bar and refreshes conversation state after successful management actions.

**Tech Stack:** NestJS, Prisma, PostgreSQL migrations, Jest, Flutter/Dart.

---

### Task 1: Backend Permission Model

**Files:**
- Modify: `apps/api/prisma/schema.prisma`
- Create: `apps/api/prisma/migrations/20260710143000_add_group_member_roles/migration.sql`
- Modify: `apps/api/src/conversations/conversations.service.spec.ts`
- Modify: `apps/api/src/conversations/conversations.service.ts`
- Modify: `apps/api/src/conversations/conversations.controller.ts`

- [ ] Add `ConversationMemberRole` enum and `ConversationMember.role`.
- [ ] Write failing Jest tests for group owner creation and management permissions.
- [ ] Implement service helpers that load group membership and check owner/GM permission.
- [ ] Add endpoints for detail, rename, add member, remove member, leave, and dissolve.
- [ ] Run `npm --prefix apps/api test -- conversations.service.spec.ts`.

### Task 2: Flutter Group Settings

**Files:**
- Modify: `apps/mobile/lib/src/models/chat_models.dart`
- Modify: `apps/mobile/lib/src/services/api_client.dart`
- Modify: `apps/mobile/lib/src/services/app_strings.dart`
- Create: `apps/mobile/lib/src/screens/group_settings_screen.dart`
- Modify: `apps/mobile/lib/src/screens/chat_screen.dart`
- Modify: `apps/mobile/lib/src/screens/conversation_list_screen.dart`

- [ ] Parse member role from conversation JSON while preserving current `members` call sites.
- [ ] Add API methods matching backend management endpoints.
- [ ] Add localized UI strings for group settings actions.
- [ ] Build group settings page with group name, member list, add member, remove member, leave, dissolve.
- [ ] Add chat app bar settings button for group conversations and refresh list after changes.

### Task 3: Verification

- [ ] Run `npm --prefix apps/api test`.
- [ ] Run `npm --prefix apps/api run build`.
- [ ] Run `flutter analyze` in `apps/mobile`.
- [ ] Run `flutter test` in `apps/mobile`.
- [ ] Run `flutter build apk --debug` in `apps/mobile`.
- [ ] Install and launch on `emulator-5554` if available.
