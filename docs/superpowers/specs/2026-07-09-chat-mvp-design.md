# Chat MVP Design

## Goal

Build a first-version mobile chat app for Android and iOS with a NestJS backend, PostgreSQL, Redis, Socket.IO realtime messaging, and Tencent Cloud COS-backed media storage.

## Assumptions

- The first version supports one-to-one chats only.
- Authentication uses email or phone plus password. SMS verification is out of scope for the first version.
- Images and voice files are stored in Tencent Cloud COS. Local disk storage is only for development fallback.
- The app can be tested by IP address during development. A production release should use a domain name and HTTPS.
- Push notifications, group chat, calls, message recall, and end-to-end encryption are deferred.

## Architecture

- `apps/api` is a NestJS API and Socket.IO server.
- `apps/mobile` is a Flutter client.
- PostgreSQL stores users, contacts, conversations, members, messages, receipts, and attachments.
- Redis stores realtime online presence and supports future horizontal scaling.
- Nginx terminates HTTP traffic and proxies API and Socket.IO requests.
- Docker Compose runs the API, PostgreSQL, Redis, and Nginx on Ubuntu.

## Core Features

- Register and login with email or phone and password.
- Maintain basic user profiles with nickname and avatar URL.
- Search users by email, phone, or nickname.
- Create accepted contacts and start one-to-one conversations.
- Send and receive text, image, and voice messages.
- Store offline messages in PostgreSQL.
- Return a conversation list with latest message and unread count.
- Track basic message status: sent and delivered.
- Provide upload records and COS configuration placeholders.

## API Shape

- `POST /auth/register`
- `POST /auth/login`
- `GET /users/me`
- `PATCH /users/me`
- `GET /users/search?q=...`
- `POST /contacts`
- `GET /contacts`
- `POST /conversations/direct`
- `GET /conversations`
- `GET /messages/:conversationId`
- `POST /uploads`

## Socket Events

- Client emits `message:send`.
- Server emits `message:new` to online conversation participants.
- Client emits `message:delivered`.
- Server emits `message:status` when a delivered receipt is recorded.

## Delivery Strategy

Build the backend first with tests around authentication, conversations, and messages. Then add Docker deployment files. Finally add the Flutter app shell with login, conversation list, chat screen, and upload hooks.

