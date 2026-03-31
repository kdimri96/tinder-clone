# Tinder Clone

A full-stack dating app clone built with Flutter (frontend) and Node.js + Express (backend).

## Features

- **Swipe cards** — swipe right to like, left to dislike, up to super like
- **Real-time matching** — instant match notification when two users like each other
- **Live chat** — Socket.io powered messaging with typing indicators and read receipts
- **Profile builder** — photo grid (up to 6 photos), bio, job, school, interests
- **Discovery** — geo-based user discovery filtered by age/gender preferences
- **JWT auth** — access tokens + refresh token rotation

## Project Structure

```
tinder-clone/
├── backend/          Node.js + Express + MongoDB + Socket.io
└── frontend/         Flutter app (iOS + Android)
```

## Backend Setup

### Requirements
- Node.js 18+
- MongoDB 6+

### Install & Run

```bash
cd backend
npm install
cp .env.example .env   # edit with your values
npm run dev
```

The API runs at `http://localhost:3000`.

### API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | /api/auth/register | Register |
| POST | /api/auth/login | Login |
| POST | /api/auth/refresh-token | Refresh JWT |
| GET  | /api/auth/me | Get current user |
| GET  | /api/profile | Get own profile |
| PUT/PATCH | /api/profile | Update profile |
| POST | /api/profile/photo | Upload photo |
| DELETE | /api/profile/photo | Delete photo |
| GET  | /api/discovery/nearby | Get nearby users |
| POST | /api/swipe | Record a swipe |
| GET  | /api/matches | Get all matches |
| GET  | /api/matches/:id | Get single match |
| DELETE | /api/matches/:id | Unmatch |
| GET  | /api/messages/:matchId | Get chat history |
| POST | /api/messages/:matchId | Send message |

### Socket.io Events

**Client → Server:**
- `chat:send` `{ matchId, text }` — send message
- `chat:read` `{ matchId }` — mark messages as read
- `typing:start` `{ matchId }` — typing started
- `typing:stop` `{ matchId }` — typing stopped
- `match:join` `{ matchId }` — join a new match room

**Server → Client:**
- `match` `{ match }` — new match created
- `chat:message` `{ message }` — new message
- `chat:read` `{ matchId, readBy }` — message read
- `typing:start` / `typing:stop` `{ userId, matchId }`
- `presence:online` / `presence:offline` `{ userId }`

## Flutter Setup

### Requirements
- Flutter 3.x
- Dart 3.x
- Android Studio / Xcode

### Install & Run

```bash
cd frontend
flutter pub get
flutter run
```

### Configuration

Update the base URL in:
- `lib/services/api_service.dart` → `_baseUrl`
- `lib/services/socket_service.dart` → `_baseUrl`
- `lib/widgets/network_image_widget.dart` → `_baseUrl`

| Platform | URL |
|----------|-----|
| Android emulator | `http://10.0.2.2:3000` |
| iOS simulator | `http://localhost:3000` |
| Physical device | `http://YOUR_IP:3000` |

## Data Models

### User
- name, email, password (hashed)
- age, gender, bio, photos[]
- location (GeoJSON Point)
- preferences (genderPreference, minAge, maxAge, maxDistance)
- interests[], job, school

### Match
- users[2] — the two matched users
- lastMessage, lastMessageAt
- unmatchedBy — soft delete

### Message
- matchId, senderId, text, mediaUrl
- readBy[] — read receipts

### Swipe
- swiperId, targetId
- direction: like | dislike | superlike
