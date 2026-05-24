# ZISCORD — BÁO CÁO DỰ ÁN

---

## 1. THÔNG TIN DỰ ÁN

| **Mục** | **Nội dung** |
|---------|------------|
| **Tên dự án** | Ziscord |
| **Mô tả ngắn** | Discord-like mobile chat application |
| **Phiên bản** | 1.0.0 |
| **Ngôn ngữ chính** | Dart + Flutter |
| **Nền tảng hỗ trợ** | Android, iOS, Windows, Web (Chrome) |
| **Tác giả/Nhóm** | [Ghi tên nhóm] |
| **Ngày báo cáo** | [dd/mm/yyyy] |

---

## 2. TỔNG QUAN DỰ ÁN

**Ziscord** là một ứng dụng nhắn tin đa nền tảng được phát triển bằng **Flutter**, lấy cảm hứng từ Discord. Dự án cung cấp các tính năng giao tiếp thời gian thực bao gồm tin nhắn trực tiếp (DM), server với nhiều kênh (chat văn bản, thư viện forum, kênh thoại), quản lý bạn bè, và tích hợp thoại/video thông qua **Agora**.

**Stack công nghệ:**
- **Frontend:** Flutter (Dart ^3.11.4)
- **Backend:** Firebase (Authentication, Firestore, Cloud Storage)
- **Voice/Video:** Agora RTC Engine
- **Image Hosting:** Cloudinary (cho ảnh tin nhắn và icon server)
- **Permissions:** permission_handler

---

## 3. MỤC TIÊU CHÍNH VÀ CHỨC NĂNG CORE

### 3.1 Mục tiêu
Xây dựng ứng dụng nhắn tin di động với trải nghiệm tương tự Discord, hỗ trợ:
- Giao tiếp 1-1 (DM) và nhóm (Server/Channel)
- Quản lý bạn bè với hệ thống lời mời
- Thoại/video thực tế trong các kênh thoại
- Đính kèm ảnh, emoji reaction, ghim tin nhắn
- Quản lý vai trò (Admin, Member) và cấp quyền
- Kênh library (forum-style) cho các cuộc thảo luận có chủ đề

### 3.2 Chức năng chính

**A. Xác thực & Tài khoản**
- Đăng ký tài khoản (Firebase Auth)
- Đăng nhập/Đăng xuất
- Quản lý hồ sơ (tên hiển thị, avatar, nickname per-server)
- Banner profile

**B. Tin nhắn trực tiếp (DM)**
- Gửi tin nhắn văn bản và ảnh
- Lịch sử tin nhắn thời gian thực
- Tin nhắn chờ (pending inbox) từ người chưa phải bạn
- Reply/Quote, edit, delete, emoji reaction, pin message

**C. Hệ thống bạn bè**
- Gửi lời mời kết bạn
- Chấp nhận/Từ chối lời mời
- Danh sách bạn bè
- Xóa bạn

**D. Server & Kênh**
- Tạo/Xóa/Đổi tên server
- Tạo/Xóa/Reorder kênh
- Hai loại kênh văn bản:
  - **Chat room:** công khai, không có chủ đề
  - **Library room:** forum-style, các post với comment threads
- Kênh thoại (voice channel) với Agora integration
- Invite code (tham gia qua code)
- Public/Private server
- Duyệt thành viên (approval flow)

**E. Tính năng chat**
- Gửi tin nhắn văn bản + ảnh (via Cloudinary)
- Reply/Quote tin nhắn
- Edit tin nhắn
- Delete tin nhắn
- Emoji reaction
- Pin message
- Hiển thị "Đã edit"

**F. @Mention & Thông báo**
- Detect `@effectiveName` của thành viên
- Mention inbox (lưu tất cả mentions)
- Badge thông báo per-channel
- Notification tab hiển thị lời mời, mentions, tin nhắn chưa đọc

**G. Kênh thoại (Voice)**
- Join/Leave voice channel
- Mute/Unmute microphone
- Toggle camera publish
- Speaking indicators (hiển thị ai đang nói)
- Listen-only fallback (nếu mic permission bị từ chối)
- Remote video view

**H. Cấp quyền & Vai trò**
- Admin: quản lý server, channel, member, duyệt join requests
- Member: chat, tham gia voice, có thể được admin cấp `canCreateChannel`
- Server-specific nickname

---

## 4. CHỨC NĂNG ĐÃ TRIỂN KHAI (MVP)

✅ **Authentication (Hoàn toàn)**
- Firebase Auth (Email/Password)
- Session persistence

✅ **DM & Pending Flow (Hoàn toàn)**
- Tin nhắn realtime via Firestore
- Pending inbox (tin nhắn từ non-friends)
- Accept/Reject workflow

✅ **Friend System (Hoàn toàn)**
- Friend requests (send/accept/decline)
- Friend list with presence tracking
- Delete friend

✅ **Image Upload & Cloudinary (Hoàn toàn)**
- Pick ảnh từ device
- Upload to Cloudinary
- Display image links trong messages và server icon

✅ **Server & Channel Management (Hoàn toàn)**
- Server CRUD (create/rename/delete/change icon)
- Channel CRUD (create/delete/rename/reorder)
- Invite code generation & join
- Public/Private toggle
- Member list & roles

✅ **Chat Features (Hoàn toàn)**
- Send text/image messages
- Reply/Quote
- Edit message
- Delete message
- Emoji reaction (picker)
- Pin message
- Show edited timestamp

✅ **Library Posts & Comments (Hoàn toàn)**
- Create post (title + content)
- Comment on post (thread-like)
- Comment count
- Timestamp

✅ **@Mention & Mention Inbox (Hoàn toàn)**
- Mention detection (by @effectiveName)
- Mention records stored in Firestore
- Per-channel mention badge
- Notification tab integration

✅ **Server Nickname Per User (Hoàn toàn)**
- Set nickname in server settings
- Display `serverNickname ?? displayName` trong server context

✅ **Pending Member Approval (Hoàn toàn)**
- `requiresApproval` flag per server
- Join requests queue
- Admin approval UI

✅ **Voice Channel MVP (Hoàn toàn)**
- Agora engine initialization
- Join channel (with token: null in Testing Mode)
- Mute/Unmute
- Camera publish (lazy)
- Remote video view
- Speaking indicators
- Leave/Disconnect
- Listen-only fallback (mic permission denied)
- Mini voice bar (persistent across navigation)

---

## 5. CHỨC NĂNG CHƯA HOÀN TẤT / LÊN KẾ HOẠCH

❌ **Voice Token Server**
- Agora Secure Mode: cần Cloud Function để mint per-channel tokens
- Hiện tại sử dụng Testing Mode (token: null)
- Cần triển khai: Firebase Cloud Function hoặc backend để sign tokens

❌ **Voice Platform Edge Cases**
- iOS: kiểm tra scene delegate đầy đủ cho voice session
- Web: WebRTC relay stability tuning
- Token lifecycle management

❌ **Push Notifications (FCM)**
- Firebase Cloud Messaging cho external push
- Local notifications còn thiếu

❌ **UI Polish & Accessibility**
- Improve mobile UX (keyboard handling, scrolling performance)
- Dark mode toggle
- Better error messages & retry UI
- Accessibility labels (a11y)

❌ **Voice Quality Tuning**
- Encoder bitrate optimization per network
- Noise suppression levels
- Echo cancellation fine-tuning
- Packet loss recovery

❌ **Advanced Role Permissions**
- Finer-grained per-channel permissions
- Ban member
- Kick member

---

## 6. KIẾN TRÚC KỸ THUẬT

### 6.1 Cấu trúc thư mục

```
lib/
├── core/
│   ├── constants/          # Agora config, app colors
│   ├── theme/              # Material theme
│   └── widgets/            # Shared UI (user avatar, emoji picker, etc.)
├── data/
│   ├── models/             # Pure Dart models (AppUser, Server, Message, etc.)
│   └── services/           # All Firebase + Agora logic
└── features/
    ├── auth/               # Login/Register pages
    ├── chat/               # DM chat UI + pending inbox
    ├── contacts/           # Friend list
    ├── notifications/      # Notifications tab
    ├── profile/            # User profile page
    └── servers/            # Server, channel, chat, library, voice pages
```

### 6.2 Service Layer (No Injection)

Tất cả services được instantiate inline (không dùng dependency injection). Các service chính:

| Service | Trách nhiệm |
|---------|------------|
| **AuthService** | FirebaseAuth wrapper, currentUserData in-memory cache |
| **UserService** | CRUD users/{uid} in Firestore |
| **FriendService** | Friend requests, friend list streams |
| **DMService** | Direct message CRUD, chat ID derivation |
| **PendingDMService** | Non-friend message inbox |
| **ServerService** | Server/Channel/Member CRUD, join logic, library posts |
| **MentionService** | Mention record CRUD, per-channel badge counts |
| **CloudinaryService** | Image pick + upload (for messages & server icons) |
| **VoiceService** | Agora engine singleton, join/leave/mute/camera, Firestore voice_members |

### 6.3 Data Models

Các model chính (pure Dart classes):

- **AppUser:** uid, email, displayName, nickname, photoURL, bannerURL
- **Server:** id, name, ownerId, iconUrl, isPublic, requiresApproval, inviteCode
- **ServerChannel:** id, name, type (text/voice), subtype (chat/library), position
- **ServerMember:** uid, role (admin/member), serverNickname, canCreateChannel, joinedAt
- **DMMessage & ServerMessage:** senderId, text, imageUrl, replyTo, mentions[], reactions{}, isPinned, isEdited, timestamp
- **LibraryPost & Comment:** authorId, authorName, title/text, timestamp
- **VoiceSession:** serverId, channelId, localUserId, joinedAt
- **VoiceMember:** userId, displayName, serverNickname, cameraOn, isMuted, joinedAt
- **MentionRecord:** context, fromUserId, fromUserName, messageId, messagePreview, serverId?, channelId?, read, timestamp

### 6.4 Real-time Data Binding

- Sử dụng **StreamBuilder** với Firestore `.snapshots()` streams
- Một số streams dùng `asyncMap` (1 Firestore read/item) → giữ tâm với performance
- Voice members, mention counts được update real-time

### 6.5 Navigation

- Không dùng named routes
- `Navigator.push(MaterialPageRoute(...))` trực tiếp từ widgets
- Fullscreen pages (DM, Channel, Voice) được push lên top của MainScaffold

---

## 7. CÔNG NGHỆ & DEPENDENCIES

### 7.1 Dependencies chính

| Package | Phiên bản | Mục đích |
|---------|----------|---------|
| **flutter** | SDK | Framework |
| **firebase_core** | ^4.7.0 | Firebase init |
| **firebase_auth** | ^6.4.0 | Authentication |
| **cloud_firestore** | ^6.3.0 | Real-time database |
| **firebase_storage** | ^13.3.0 | File storage |
| **agora_rtc_engine** | ^6.5.0 | Voice/Video RTC |
| **permission_handler** | ^11.3.0 | Request permissions |
| **image_picker** | ^1.1.0 | Pick ảnh từ device |
| **http** | ^1.2.0 | HTTP requests |
| **intl** | ^0.20.2 | Localization & formatting |
| **cupertino_icons** | ^1.0.8 | iOS-style icons |

### 7.2 Firebase Configuration

- **google-services.json** (Android)
- **GoogleService-Info.plist** (iOS)
- **FirebaseOptions** được generate tự động

### 7.3 Agora Configuration

- **App ID:** `7d38b1bef5d643cfa0c3a5035e7a32c4`
- **Channel naming:** `{serverId}_{channelId}` để tránh collision
- **Token mode:** Testing (token: null) hoặc Secure (need server-signed tokens)

---

## 8. CÀI ĐẶT & CHẠY ỨNG DỤNG

### 8.1 Yêu cầu môi trường

- **Dart SDK:** >= 3.11.4
- **Flutter SDK:** Latest (3.24+)
- **Android:** SDK 21+ (or target API 33+ for Agora)
- **iOS:** 11.0+
- **Web:** Chrome/Firefox/Safari with WebRTC support

### 8.2 Bước cài đặt

```bash
# 1. Clone repository
git clone <repo-url>
cd ziscord

# 2. Cài dependencies
flutter pub get

# 3. Kiểm tra project
flutter analyze

# 4. Run tests (nếu có)
flutter test
```

### 8.3 Chạy ứng dụng

```bash
# Android
flutter run -d <device_id>

# iOS
flutter run -d <device_id>

# Windows
flutter run -d windows

# Web (Chrome)
flutter run -d chrome

# Build APK
flutter build apk

# Build Windows EXE
flutter build windows
```

### 8.4 Kiểm tra logs

- **Flutter console:** tìm tag `[voice]` cho voice-related logs
- **Android:** `adb logcat | grep -i agora`
- **Web:** DevTools Console (F12)

---

## 9. SCHEMA FIRESTORE

```
users/{uid}
├── uid (string)
├── email (string)
├── displayName (string)
├── nickname (string)
├── photoURL (string, optional)
└── bannerURL (string, optional)

users/{uid}/mention_inbox/{id}
├── context (string: 'dm' | 'channel')
├── fromUserId (string)
├── fromUserName (string)
├── messageId (string)
├── messagePreview (string)
├── serverId (string, optional)
├── channelId (string, optional)
├── serverName (string, optional)
├── channelName (string, optional)
├── read (boolean)
└── timestamp (timestamp)

friends/{uid}/my_friends/{friendUid}
└── since (timestamp)

friend_requests/{id}
├── from (string: uid)
├── to (string: uid)
├── status (string: 'pending' | 'accepted' | 'declined')
└── timestamp (timestamp)

dm_chats/{chatId}
├── participants (array: [uid1, uid2])
├── lastMessage (string)
└── updatedAt (timestamp)

dm_chats/{chatId}/messages/{id}
├── senderId (string)
├── receiverId (string)
├── text (string)
├── imageUrl (string, optional)
├── replyTo (string, optional: messageId)
├── mentions (array: [userId, ...])
├── reactions (map: {emoji: [userId, ...]})
├── isPinned (boolean)
├── isEdited (boolean)
└── timestamp (timestamp)

pending_dms/{uid}/inbox/{fromUid}
└── preview (string: short message preview)

servers/{sid}
├── id (string)
├── name (string)
├── ownerId (string)
├── iconUrl (string, optional)
├── isPublic (boolean)
├── requiresApproval (boolean)
├── inviteCode (string, unique)
└── createdAt (timestamp)

servers/{sid}/members/{uid}
├── role (string: 'admin' | 'member')
├── serverNickname (string, optional)
├── canCreateChannel (boolean)
└── joinedAt (timestamp)

servers/{sid}/channels/{cid}
├── id (string)
├── name (string)
├── type (string: 'text' | 'voice')
├── subtype (string: 'chat' | 'library', for text channels)
└── position (number)

servers/{sid}/channels/{cid}/messages/{id}
├── senderId (string)
├── senderName (string)
├── text (string)
├── imageUrl (string, optional)
├── replyTo (string, optional)
├── mentions (array: [userId, ...])
├── reactions (map: {emoji: [userId, ...]})
├── isPinned (boolean)
├── isEdited (boolean)
└── timestamp (timestamp)

servers/{sid}/channels/{cid}/posts/{pid}
├── id (string)
├── authorId (string)
├── authorName (string)
├── title (string)
├── content (string)
├── commentCount (number)
└── timestamp (timestamp)

servers/{sid}/channels/{cid}/posts/{pid}/comments/{id}
├── authorId (string)
├── authorName (string)
├── text (string)
└── timestamp (timestamp)

servers/{sid}/channels/{cid}/voice_members/{uid}
├── userId (string)
├── displayName (string)
├── serverNickname (string, optional)
├── cameraOn (boolean)
├── isMuted (boolean)
└── joinedAt (timestamp)

servers/{sid}/join_requests/{uid}
├── uid (string)
├── displayName (string)
├── photoURL (string, optional)
└── requestedAt (timestamp)

user_servers/{uid}/joined/{sid}
├── serverName (string)
├── role (string)
└── joinedAt (timestamp)
```

### 9.1 Composite Indexes (Firestore)

Các index cần khởi tạo:
- `mention_inbox`: `read + context + serverId`
- `mention_inbox`: `read + context + serverId + channelId` (per-channel counts)
- Firestore tự động prompt khi chạy app lần đầu; click link để khởi tạo.

---

## 10. HƯỚNG DẪN KIỂM THỬ CHỨC NĂNG

### 10.1 Kiểm thử xác thực

**Bước:**
1. Chạy app lần đầu → landing page
2. Nhấn "Sign Up" → nhập email + mật khẩu → tạo tài khoản
3. Confirm email (nếu cần)
4. Đăng nhập với tài khoản vừa tạo
5. Nhấn profile tab → "Logout"
6. Đăng nhập lại → xác nhận session persistence

**Kỳ vọng:**
- Tài khoản được tạo trong Firebase Auth
- User document lưu trong Firestore `users/{uid}`
- Login/logout hoạt động mượt mà

---

### 10.2 Kiểm thử DM & Pending Flow

**Chuẩn bị:** 2 tài khoản (A và B)

**Bước:**
1. **A gửi tin nhắn cho B (chưa phải bạn):**
   - A → Contacts → search "B email"
   - Nhập tin nhắn → gửi
   - Tin nhắn đi vào pending_dms (chưa hiện lên chat của A)

2. **B nhận pending DM:**
   - B → Notifications tab
   - Thấy pending message từ A
   - Nhấn Accept → tin nhắn hiển thị, 2 người trở thành bạn

3. **Verify DM lịch sử:**
   - A/B cùng thấy chat history
   - Gửi tin nhắn mới → realtime sync

**Kỳ vọng:**
- Pending flow hoạt động
- DM realtime thông qua Firestore
- Friend relationship được tạo

---

### 10.3 Kiểm thử Friend System

**Bước:**
1. **A gửi friend request tới B:**
   - A → Contacts → search B email → "Add Friend"
   - Friend request lưu vào `friend_requests` collection

2. **B nhận & chấp nhận:**
   - B → Notifications tab → thấy friend request
   - Nhấn "Accept" → B và A trở thành bạn

3. **Verify:**
   - Cả A/B thấy nhau trong Contacts list
   - Có thể DM trực tiếp (không cần pending)

---

### 10.4 Kiểm thử Server & Channel

**Bước:**
1. **A tạo server:**
   - A → Home tab → "New Server"
   - Nhập tên + chọn icon → "Create"
   - Server hiển thị trong sidebar

2. **A tạo kênh:**
   - Nhấn server → "Add Channel"
   - Tạo 2 kênh: 1 Chat (loại chat), 1 Library (loại library)

3. **A tạo invite code:**
   - Server settings → "Invite Link"
   - Copy invite code

4. **B tham gia server:**
   - B → "Browse Servers" (hoặc nhận invite từ A)
   - Paste invite code → "Join"
   - B thấy server trong sidebar

5. **Verify channel reorder:**
   - Server settings → drag channels để reorder

**Kỳ vọng:**
- Server/channel CRUD hoạt động
- Invite code tạo & join
- Role là member (A là admin)

---

### 10.5 Kiểm thử Chat Features

**Bước:**
1. **Gửi tin nhắn:**
   - A/B mở kênh chat cùng nhau
   - Gửi tin nhắn text → realtime sync

2. **Reply/Quote:**
   - A long-press tin nhắn của B → "Reply"
   - Viết trả lời → gửi
   - Verify quoted message hiển thị

3. **Edit:**
   - A long-press tin nhắn của A → "Edit"
   - Thay đổi text → "Save"
   - Verify timestamp hiển thị "Edited"

4. **Delete:**
   - Long-press → "Delete"
   - Verify tin nhắn disappear

5. **Emoji Reaction:**
   - Double-tap tin nhắn → emoji picker
   - Chọn emoji → verify hiển thị dưới tin nhắn

6. **Pin Message:**
   - Long-press → "Pin"
   - Pin list hiển thị (nếu có UI)

7. **Upload ảnh:**
   - Nhấn attachment icon → chọn ảnh
   - Verify ảnh upload lên Cloudinary & hiển thị

**Kỳ vọng:**
- Tất cả tính năng chat hoạt động
- Cloudinary upload thành công
- Real-time update

---

### 10.6 Kiểm thử Library (Posts & Comments)

**Bước:**
1. **A tạo post:**
   - A mở Library channel → "New Post"
   - Nhập title + content → "Post"
   - Post hiển thị trong danh sách

2. **B comment:**
   - B tap post → mở thread
   - Viết comment → gửi
   - Comment hiển thị, count update

3. **Verify:**
   - Post count chính xác
   - Comment timestamp hiển thị

**Kỳ vọng:**
- Library forum-style hoạt động

---

### 10.7 Kiểm thử @Mention

**Bước:**
1. **A mention B trong kênh:**
   - A gõ "@" → mention picker hiển thị
   - Chọn B từ list
   - Gửi tin nhắn

2. **B nhận mention:**
   - B → Notifications tab
   - Thấy mention từ A
   - Nhấn → jump tới message

3. **Verify sidebar badge:**
   - Channel name trong server sidebar có badge (số mentions)
   - Badge disappear khi B mark as read

**Kỳ vọng:**
- Mention detection & notification hoạt động
- Badge count chính xác

---

### 10.8 Kiểm thử Voice Channel

**Chuẩn bị:** 2 thiết bị (A & B) hoặc 2 browser tabs (Web)

**Bước:**
1. **A join voice channel:**
   - A mở voice channel → "Join Call"
   - Agora engine khởi tạo
   - Kiểm tra logs: `[voice] joinChannel OK`
   - Verify mic permission request
   - Voice member của A xuất hiện trong `servers/{sid}/channels/{cid}/voice_members`

2. **B join cùng channel:**
   - B mở same channel → "Join Call"
   - B thấy A trong member list
   - A thấy B (realtime)

3. **Kiểm tra voice:**
   - A nói → B nghe
   - B nói → A nghe
   - Verify speaking indicators (highlight ai đang nói)

4. **Kiểm tra mute:**
   - A nhấn mute button
   - A voice được mute (B không nghe được)
   - A nhấn unmute → normal lại

5. **Kiểm tra camera:**
   - A nhấn camera toggle
   - A camera bật → `voice_members/{aUid}.cameraOn = true`
   - B thấy A camera on
   - B see A's video feed (nếu A permit)
   - A nhấn camera toggle lại → off

6. **Kiểm tra disconnect:**
   - A nhấn "Leave Call"
   - A disconnect từ Agora
   - B thấy A disappear từ member list
   - Verify logs không có error

7. **Mini bar:**
   - A join voice → mini bar hiển thị ở bottom
   - A navigate away (go to chat) → mini bar still visible
   - A tap mini bar → return về voice page
   - A tap "Leave" từ mini bar → disconnect properly

**Edge Cases (Kiểm thử):**
- **Mic permission denied:** App fallback to listen-only (B nghe được, A không broadcast)
- **Camera unavailable:** Camera toggle fail với message
- **Network latency:** Voice delay tăng nhưng không crash

**Kỳ vọng:**
- Voice channel hoạt động
- Real-time audio/video
- Speaking indicators
- Mute/camera controls

---

### 10.9 Kiểm thử Notifications

**Bước:**
1. **Friend request:** B gửi request → A → Notifications tab
2. **Mention:** A mention B → B → Notifications tab
3. **Badge count:** Verify badge count increase/decrease
4. **Mark as read:** Tap notification → badge decrease

**Kỳ vọng:**
- Notifications display chính xác

---

## 11. KNOWN ISSUES & CHÚNG TÔI QUAN TÂM

### 11.1 Voice Token

- **Hiện tại:** App dùng `token: null` (Testing Mode)
- **Nếu Agora project ở Secure Mode:** Cần Cloud Function để mint token
- **Triển khai:** Tạo Firebase Cloud Function `/agora-token` endpoint → call từ `voice_service.dart` trước khi join

### 11.2 Microphone Permission Fallback

- **Behavior:** Nếu user từ chối mic permission → app enter listen-only
- **Trình bày:** Voice member có flag `micDisabled: true` → show different UI
- **Limitation:** User chỉ có thể nghe, không broadcast âm thanh

### 11.3 Camera Not Available

- **Cause:** Ứng dụng khác (Zoom, OBS) đang sử dụng camera
- **Behavior:** `setCamera(true)` return false với `CameraFailReason.inUseByOtherApp`
- **Fix:** User cần đóng app khác & retry

### 11.4 Network Issues & Latency

- **Voice delay:** Nếu network chậm, audio delay tăng
- **Packet loss:** Agora tự động handle, nhưng quality giảm
- **Fix:** Kiểm tra network quality before joining (future enhancement)

### 11.5 iOS Scene Delegate

- **Note:** iOS voice session cần proper scene delegate handling
- **Status:** Đã implement cơ bản, nhưng edge cases với backgrounding chưa test kỹ

### 11.6 Web WebRTC Relay

- **Browser support:** Chrome/Firefox/Safari with WebRTC
- **Issue:** Nếu dùng proxy/VPN, relay có thể unstable
- **Fix:** Test trực tiếp với ISP network

---

## 12. TÍNH NĂNG CHƯA TEST HOẶC INCOMPLETE

| Tính năng | Trạng thái | Ghi chú |
|-----------|-----------|--------|
| Voice quality tuning | Incomplete | Bitrate, noise suppression cần optimize |
| Push notifications (FCM) | Not implemented | Chỉ có in-app notifications |
| Ban/Kick member | Not implemented | Chưa code role check |
| Finer permissions | Not implemented | Hiện chỉ có admin/member |
| Dark mode | Not implemented | UI dùng Material default |
| A11y (accessibility) | Partial | Cần thêm semantic labels |
| iOS full test | Partial | Android + Web được test tốt |

---

## 13. TÀI LIỆU THAM KHẢO

### 13.1 Key Files trong Codebase

| File | Mục đích |
|------|---------|
| `lib/main.dart` | App entry point, Firebase init |
| `lib/app.dart` | MyApp router & auth state |
| `lib/features/main/main_scaffold.dart` | Bottom nav + 3 tabs (Home/Notifications/Profile) |
| `lib/data/services/voice_service.dart` | Agora engine + voice session management |
| `lib/data/services/server_service.dart` | Server/channel/member CRUD |
| `lib/data/services/dm_service.dart` | DM message CRUD |
| `lib/data/services/mention_service.dart` | Mention records & per-channel badges |
| `lib/core/constants/agora_config.dart` | Agora App ID & channel name strategy |
| `lib/features/servers/voice_channel_page.dart` | Voice UI (AgoraVideoView, controls) |
| `pubspec.yaml` | Dependencies & version |
| `CLAUDE.md` | Product vision & architecture docs |

### 13.2 External Documentation

- **Firebase:** https://firebase.google.com/docs
- **Firestore:** https://firebase.google.com/docs/firestore
- **Agora:** https://docs.agora.io/en/Interactive%20Broadcast/landing-page
- **Flutter:** https://flutter.dev/docs
- **Cloudinary:** https://cloudinary.com/documentation

### 13.3 Ảnh màn hình cần chụp cho báo cáo

1. **Login page** (nhập email/password)
2. **Register page** (tạo tài khoản)
3. **Main scaffold** (home tab + sidebar)
4. **Server list** (sidebar với bubble icons)
5. **Channel chat** (messages + input)
6. **Library post** (threads + comments)
7. **Voice channel** (join view + member list + controls)
8. **Voice with camera** (local + remote video)
9. **Notifications tab** (friend requests + mentions)
10. **Profile page** (user info + avatar + logout)

### 13.4 Log Snippets

**Successful voice join:**
```
[voice] joinChannel OK: channelName=server123_voice001, uid=1234
[voice] setAudioProfile: mono/48kHz
```

**Camera toggle:**
```
[voice] setCamera(true) DONE: cameraOn=true
[voice] setCamera(false) DONE: cameraOn=false
```

**Error example:**
```
[voice] setCamera(true) FAILED: reason=inUseByOtherApp
```

---

## 14. KẾT LUẬN

**Ziscord** là một ứng dụng nhắn tin di động hoàn thiện với các tính năng cơ bản đã triển khai:
- ✅ Xác thực & quản lý tài khoản
- ✅ DM realtime & pending flow
- ✅ Hệ thống bạn bè
- ✅ Server & channel management
- ✅ Chat features (reply, edit, delete, reactions, pin)
- ✅ Library forum-style
- ✅ @mention & notifications
- ✅ Voice channel (Agora) với mute, camera, speaking indicators
- ⏳ Voice token server (chưa làm)
- ⏳ Push notifications (chưa làm)
- ⏳ UI polish & accessibility

**Tiếp theo:** Triển khai voice token server, push notifications, và optimize UX/performance.

---

**Ngày cập nhật:** [dd/mm/yyyy]
**Phiên bản báo cáo:** 1.0.0
