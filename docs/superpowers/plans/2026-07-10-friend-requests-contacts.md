# Friend Requests And Contacts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace direct add-and-chat search flow with WeChat-style friend requests and a usable contacts list.

**Architecture:** The backend keeps a single `Contact` row per requester/addressee pair with `PENDING`, `ACCEPTED`, or removed/rejected state. Flutter gains a contacts entry point from the conversation list, a requests screen, and search buttons that send requests instead of immediately opening chat.

**Tech Stack:** NestJS, Prisma, PostgreSQL, Jest, Flutter/Dart, Material widgets.

---

### Task 1: Backend Contact Request API

**Files:**
- Modify: `apps/api/src/contacts/contacts.service.ts`
- Modify: `apps/api/src/contacts/contacts.controller.ts`
- Create: `apps/api/src/contacts/contacts.service.spec.ts`

- [ ] Write failing Jest tests for: creating `PENDING` requests, listing accepted contacts, listing incoming requests, accepting a request, rejecting a request, and preventing self-add.
- [ ] Run `cd apps/api && npm test -- contacts.service.spec.ts` and confirm failures come from missing behavior.
- [ ] Implement minimal service/controller methods: `create`, `list`, `incomingRequests`, `outgoingRequests`, `accept`, `reject`.
- [ ] Run `cd apps/api && npm test -- contacts.service.spec.ts` and then `npm test`.

### Task 2: Direct Conversation Requires Friendship

**Files:**
- Modify: `apps/api/src/conversations/conversations.service.ts`
- Test: `apps/api/src/conversations/conversations.service.spec.ts`

- [ ] Write failing tests proving non-friends cannot create a direct conversation and accepted friends can.
- [ ] Run targeted test and confirm failure.
- [ ] Add an accepted-contact check in `createDirect`.
- [ ] Run targeted test and full backend tests.

### Task 3: Flutter Models And API Client

**Files:**
- Modify: `apps/mobile/lib/src/models/chat_models.dart`
- Modify: `apps/mobile/lib/src/services/api_client.dart`

- [ ] Add `ContactRelation` model that exposes `id`, `status`, `requester`, `addressee`, and `friendFor(currentUserId)`.
- [ ] Add API methods for contacts, incoming requests, outgoing requests, send request, accept request, reject request.
- [ ] Run `cd apps/mobile && flutter analyze`.

### Task 4: Flutter Contacts And Requests UI

**Files:**
- Create: `apps/mobile/lib/src/screens/contacts_screen.dart`
- Create: `apps/mobile/lib/src/screens/friend_requests_screen.dart`
- Modify: `apps/mobile/lib/src/screens/conversation_list_screen.dart`
- Modify: `apps/mobile/lib/src/screens/user_search_screen.dart`

- [ ] Add contacts screen with accepted friends and tap-to-chat.
- [ ] Add friend requests screen with incoming accept/reject and outgoing pending display.
- [ ] Add conversation list action to open contacts and refresh on return.
- [ ] Change search result action to send friend request, not immediately chat.
- [ ] Run Flutter analyze and build debug APK.

### Task 5: Verification

**Files:**
- Backend and mobile touched above.

- [ ] Run backend tests: `cd apps/api && npm test`.
- [ ] Run Flutter checks: `cd apps/mobile && flutter analyze && flutter test && flutter build apk --debug`.
- [ ] Report APK path and any deployment/manual test notes.
