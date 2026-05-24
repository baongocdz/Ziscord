# Ziscord

Discord clone mobile (Flutter + Firebase). Tính năng chính: server/channel, DM, voice channel (Agora), library forum, mentions, AI assistant.

## Chạy app

```bash
flutter pub get
flutter run -d windows    # hoặc chrome / android
```

## Cấu hình AI Assistant (Groq)

Tính năng AI Assistant trong tab Messages dùng Groq API. Để bật:

1. Tạo API key miễn phí tại https://console.groq.com/keys
2. Chạy app với key qua `--dart-define`:

```bash
flutter run -d windows --dart-define=GROQ_API_KEY=gsk_xxxxxxxxxxxx
```

Khi build release:

```bash
flutter build apk --dart-define=GROQ_API_KEY=gsk_xxxxxxxxxxxx
flutter build windows --dart-define=GROQ_API_KEY=gsk_xxxxxxxxxxxx
```

Nếu không truyền key, các tính năng khác (DM, server, voice...) vẫn hoạt động bình thường — chỉ AI chat báo lỗi thiếu key.

## Tài liệu

Xem `CLAUDE.md` cho chi tiết về kiến trúc, schema Firestore, và roadmap.
