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
- **Media:** chỉ ảnh (upload Firebase Storage), không file
- **Voice channel:** để sau, chưa chọn công nghệ
- **Server roles:** chỉ 2 cấp — Admin vs Member
- **Server nickname:** mỗi user có thể đặt nickname riêng cho từng server (set trong server settings). Hiển thị `serverNickname ?? displayName` trong mọi context của server đó. Lưu trong `servers/{serverId}/members/{userId}.serverNickname`
- **Server visibility:** có cả public (tìm kiếm được) và private (chỉ invite)
- **User status online/offline:** không làm

### Đã hoạt động
- Auth (login/register)
- DM real-time qua Firestore
- Friend request & accept
- Upload avatar (Firebase Storage)

### Chưa làm / cần làm lại
- Toàn bộ UI redesign theo phong cách Discord
- Server system (tạo, join, settings, roles)
- Channel & room (Library room = forum/thread, Chat room = public chat)
- Voice channel (để sau)
- Notification (tin nhắn chưa đọc, kết bạn)
- Pending DM inbox (tin nhắn từ người chưa phải bạn bè)
- Invite code / join server (public + private)
- Message actions (edit, delete, reply, react, pin)

## Architecture

**Stack:** Flutter + Firebase (Firestore, Auth, Storage)

**Entry point flow:**
1. `main.dart` — initializes Firebase, reads `FirebaseAuth.currentUser`
2. `app.dart` — `MyApp` routes to `LoginPage` or `HomePage` based on auth state
3. `HomePage` — bottom nav with 3 tabs: `ChatPage`, `ContactListPage`, `ProfilePage`

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
- `DMService` — manages `dm_chats/{chatId}/messages` subcollection; chat ID is always `sorted(uid1, uid2).join('_')`

**Firestore schema:**
```
users/{uid}                        → AppUser fields
friends/{uid}/my_friends/{uid}     → { since: Timestamp }
friend_requests/{id}               → { from, to, status, timestamp }
dm_chats/{chatId}                  → { participants, lastMessage, updatedAt }
dm_chats/{chatId}/messages/{id}    → { senderId, receiverId, text, timestamp }
```

**Auth state caveat:** `AuthService` is instantiated ad-hoc (not a singleton) so `currentUserData` is not shared between instances. Pages that need the full `AppUser` call `authService.loadCurrentUser()` in `initState`. Pages that only need the UID use `AuthService().currentUser!.uid` directly.

**Real-time data:** All list views use `StreamBuilder` against Firestore streams. `FriendService.streamFriends` uses `asyncMap` (one Firestore read per friend per stream event) — keep this in mind for performance if friend lists grow.

**Navigation:** No named routes. All navigation uses `Navigator.push(MaterialPageRoute(...))` directly from widgets.
