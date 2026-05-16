# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run the app (pick a target)
flutter run -d windows
flutter run -d chrome
flutter run -d android

# Build
flutter build apk
flutter build windows

# Analyze / lint
flutter analyze

# Tests
flutter test
flutter test test/widget_test.dart   # single test file
```

## Product Vision

Ziscord là Discord clone mobile (Flutter). Mục tiêu cuối cùng là app mobile với giao diện và tính năng tương tự Discord.

### Layout tổng thể
- **Sidebar trái:** cột bong bóng icon dọc — bong bóng đầu tiên = DM/bạn bè, tiếp theo là các server đã tham gia
- **Bottom bar:** 3 tab — Home (hiển thị sidebar), Thông báo, Profile
- **DM chat page:** fullscreen, không có sidebar/bottom bar
- **Room trong server:** fullscreen khi mở room, không có sidebar/bottom bar; sidebar/bottom vẫn hiện khi ở màn server chính

### Server
- Tạo server, mỗi server có các kênh (channel)
- **Kênh văn bản — 2 loại room:**
  - **Library room:** hiển thị danh sách bài đăng (topic) từ trên xuống, người dùng thảo luận bên dưới từng topic (kiểu forum/thread)
  - **Chat room:** public chat trực tiếp không có chủ đề, giống channel Discord thường
- **Kênh thoại:** real-time voice call, nhiều người join cùng lúc (như Discord voice channel)
- **Server settings:** thêm/xóa room, phân quyền thành viên (admin, v.v.), duyệt thành viên tham gia
- **Tham gia server:** qua invite code hoặc lời mời từ bạn bè

### DM & Bạn bè
- Kết bạn qua email (đã có)
- Nhắn tin riêng real-time (đã có, Firebase connected)
- Tin nhắn chờ từ người chưa phải bạn bè (pending inbox)
- Popup profile khi nhấn vào avatar user trong room: xem thông tin, kết bạn, nhắn tin riêng

### Quyết định đã chốt
- **Message actions:** sửa, xóa, reply (quote), reaction emoji, pin message
- **Media:** chỉ ảnh (upload Cloudinary), không file
- **Voice channel:** dùng **Agora** (`agora_rtc_engine`). Token server qua Firebase Cloud Functions (chưa làm).
- **Server roles:** chỉ 2 cấp — Admin vs Member. Member có thể được admin cấp riêng quyền `canCreateChannel`.
- **Server nickname:** mỗi user có thể đặt nickname riêng cho từng server (set trong server settings). Hiển thị `serverNickname ?? displayName` trong mọi context của server đó. Lưu trong `servers/{serverId}/members/{userId}.serverNickname`
- **Server visibility:** có cả public (tìm kiếm được) và private (chỉ invite)
- **Duyệt thành viên:** mỗi server có flag `requiresApproval` (default false). Bật lên → mọi yêu cầu tham gia (qua browse hoặc invite code) đều phải admin duyệt.
- **Mention (@user):** detect bằng cách so text với `@effectiveName` của member; lưu mention vào `users/{uid}/mention_inbox` để hiển thị badge ở bottom nav, ở tab Thông báo, và badge đỏ kèm số lần nhắc cạnh tên kênh trong sidebar server.
- **User status online/offline:** không làm

### Đã hoạt động
- Auth (login/register)
- DM real-time qua Firestore + pending inbox (tin nhắn từ người chưa phải bạn bè)
- Friend request & accept
- Upload avatar và ảnh trong tin nhắn (Cloudinary)
- Server: tạo, đổi tên/icon, public/private, invite code, leave/delete
- Channels: tạo/xóa/đổi tên/reorder, hai loại text (chat + library) và voice (chỉ tạo, chưa join được)
- Library: tạo post, comment
- Chat trong channel: gửi text + ảnh, reply, edit, delete, react emoji, pin
- @mention với mention picker, mention inbox + badge per-channel
- Pending member approval (toggle trong server settings)
- Server nickname per user
- Notifications tab: lời mời kết bạn, tin nhắn chưa đọc, mentions

### Chưa làm
- **Voice channel join logic** (Agora integration — kế hoạch sắp tới)
- Token server (Firebase Cloud Function) cho Agora
- Push notification ngoài app (FCM)
- UI polish: badge "có yêu cầu chờ duyệt" cho admin trên server icon

## Architecture

**Stack:** Flutter + Firebase (Firestore, Auth, Storage)

**Entry point flow:**
1. `main.dart` — initializes Firebase, reads `FirebaseAuth.currentUser`
2. `app.dart` — `MyApp` routes to `LoginPage` or `MainScaffold` based on auth state
3. `MainScaffold` — bottom nav with 3 tabs (Home / Notifications / Profile). Home tab shows the server sidebar; tapping a server opens `ServerPage` in the same scaffold; tapping a channel/DM pushes a fullscreen page on top.

**Layer structure:**

```
lib/
├── core/           # App-wide constants, theme, shared widgets
├── data/
│   ├── models/     # Pure Dart data classes with fromMap/toMap
│   └── services/   # All Firebase logic lives here (no business logic in UI)
└── features/       # One folder per screen/flow; pages call services directly
```

**Services (instantiated inline, not injected):**
- `AuthService` — wraps FirebaseAuth; holds `currentUserData` in memory after login
- `UserService` — CRUD on `users/{uid}` in Firestore
- `FriendService` — manages `friends/{uid}/my_friends` subcollection and `friend_requests` collection
- `DMService` — manages `dm_chats/{chatId}/messages`; chat ID is always `sorted(uid1, uid2).join('_')`. On send, also writes mention records via `MentionService`.
- `PendingDMService` — DMs from non-friends queued for approval
- `ServerService` — server/channel/message/member/library CRUD; `joinServerById` & `joinServerByCode` return `JoinResult` and branch on `server.requiresApproval` (instant join vs pending request)
- `MentionService` — `users/{uid}/mention_inbox` records (DM + channel); exposes per-channel unread count stream for the sidebar badge
- `CloudinaryService` — pick + upload images (used for both message images and server icons)

**Firestore schema:**
```
users/{uid}                                              → AppUser fields
users/{uid}/mention_inbox/{id}                           → { context: 'dm'|'channel', fromUserId, fromUserName, messageId, messagePreview, serverId?, channelId?, serverName?, channelName?, timestamp, read }
friends/{uid}/my_friends/{uid}                           → { since: Timestamp }
friend_requests/{id}                                     → { from, to, status, timestamp }
dm_chats/{chatId}                                        → { participants, lastMessage, updatedAt }
dm_chats/{chatId}/messages/{id}                          → { senderId, receiverId, text, imageUrl?, replyTo*, mentions[], reactions{}, isPinned, isEdited, timestamp }
pending_dms/{uid}/inbox/{fromUid}                        → preview of unsolicited DM until accepted
servers/{sid}                                            → { name, ownerId, iconUrl?, isPublic, requiresApproval, inviteCode, createdAt }
servers/{sid}/members/{uid}                              → { role: 'admin'|'member', serverNickname?, canCreateChannel, joinedAt }
servers/{sid}/channels/{cid}                             → { name, type: 'text'|'voice', subtype: 'chat'|'library', position }
servers/{sid}/channels/{cid}/messages/{id}               → same shape as DM messages + senderName, mentions[]
servers/{sid}/channels/{cid}/posts/{pid}                 → { authorId, authorName, title, content, commentCount, timestamp }   (library)
servers/{sid}/channels/{cid}/posts/{pid}/comments/{id}   → { authorId, authorName, text, timestamp }
servers/{sid}/join_requests/{uid}                        → { displayName, photoURL?, requestedAt }   (chỉ khi requiresApproval=true)
user_servers/{uid}/joined/{sid}                          → { serverName, role, joinedAt }   (reverse index for sidebar)
```

**Auth state caveat:** `AuthService` is instantiated ad-hoc (not a singleton) so `currentUserData` is not shared between instances. Pages that need the full `AppUser` call `authService.loadCurrentUser()` in `initState`. Pages that only need the UID use `AuthService().currentUser!.uid` directly.

**Real-time data:** All list views use `StreamBuilder` against Firestore streams. `FriendService.streamFriends` and `ServerService.streamUserServers` use `asyncMap` (one Firestore read per item per stream event) — keep this in mind for performance.

**Navigation:** No named routes. All navigation uses `Navigator.push(MaterialPageRoute(...))` directly from widgets.

**Firestore composite indexes:** Some queries need composite indexes Firestore will auto-prompt for on first run:
- `mention_inbox`: `read + context + serverId` and `read + context + serverId + channelId` (for per-channel mention counts and mark-as-read).
Click the link in the error to create the index, or maintain `firestore.indexes.json`.
