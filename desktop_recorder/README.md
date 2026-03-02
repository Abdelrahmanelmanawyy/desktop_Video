# Masaüstü Kayıt (Desktop Recorder)

A Flutter-based desktop video recording application designed for kiosk environments. Doctors or users sign in, record video messages using a Canon camera (EOS Webcam Utility), and upload recordings to Firebase Storage.

---

## Features

### Authentication
- **Username/Password sign-in** via Firebase Authentication REST API
- **Sign-up** for new users (username stored as `username@desktop.local`)
- **Session persistence** using refresh tokens in SharedPreferences
- **Failed login lockout** — 3 failed attempts triggers a 30-second lockout
- **Auto sign-out** after 20 seconds of inactivity (paused during recording)

### Video Recording
- **Canon camera support** — Filters for EOS Webcam Utility or Canon cameras
- **Live camera preview** with frame guide overlay
- **90-second max recording** — Automatic stop at 90 seconds with visual/audio warning at 75 seconds
- **Recording limit** — Maximum 3 recordings per session
- **Audio capture** — Video recorded with microphone audio (AAC)

### Post-Recording
- **Video preview** — Play/pause recorded video before sending
- **Record again** — Option to re-record (within session limit)
- **Upload to Firebase** — Zip compression + upload to Firebase Storage under `recordings/{uid}/`

### Kiosk Mode
- **Fullscreen, always-on-top** window
- **Admin escape** — Ctrl+Shift+F12 + PIN to exit kiosk
- **Soft kiosk** — BAT-based watchdog can hide Explorer and restart app (see `docs/kiosk_setup.md`)

---

## Technology Stack

| Category | Technology |
|----------|------------|
| **Framework** | Flutter 3.x (Dart ^3.10.7) |
| **State Management** | Flutter Riverpod |
| **Camera** | `camera` + `camera_windows` |
| **Video Playback** | `video_player` + `video_player_win` |
| **Authentication** | Firebase Auth REST API (Identity Toolkit) |
| **Storage** | Firebase Storage (REST API) |
| **HTTP** | `http` package |
| **Persistence** | `shared_preferences` |
| **Window** | `window_manager` (fullscreen, always on top) |
| **Archive** | `archive` (zip for upload) |
| **Platform** | Windows (primary), Android/iOS (structure present) |

---

## Project Structure (Clean Architecture)

```
desktop_recorder/
├── lib/
│   ├── main.dart                    # App entry, kiosk escape, auth gate
│   ├── core/
│   │   └── config/
│   │       ├── firebase_config.dart  # Firebase API key, storage bucket
│   │       └── kiosk_config.dart     # Admin PIN, stop file path
│   ├── data/
│   │   ├── models/
│   │   │   ├── auth_user.dart        # Signed-in user model
│   │   │   ├── doctor.dart            # Doctor model (uid, name)
│   │   │   └── rec_state.dart        # Recording state enum
│   │   └── services/
│   │       └── video_upload_service.dart # Zip + Firebase Storage upload
│   ├── presentation/
│   │   ├── providers/
│   │   │   ├── auth_provider.dart    # Firebase auth (sign in/up, token)
│   │   │   └── recording_provider.dart # Save path, filename helpers
│   │   ├── screens/
│   │   │   ├── home_screen.dart      # Camera, recording, preview, upload
│   │   │   └── sign_in_screen.dart  # Login form, lockout
│   │   └── widgets/
│   │       ├── framing_overlay_painter.dart # Frame guide overlay
│   │       ├── indicator_chip.dart   # Warning/error chip
│   │       └── recorded_video_preview.dart  # Playback + send UI
│   ├── features/sign_in/            # Alternate sign-in (SignInPage)
│   └── app.dart, home_page.dart      # Alternate app entry (optional)
├── assets/bin/                       # FFmpeg (optional, for future use)
├── recordings/                       # Local recording output
├── docs/
│   ├── kiosk_setup.md               # Soft kiosk deployment
│   └── recording_verification.md    # Recording verification checklist
└── pubspec.yaml
```

---

## Prerequisites

- **Flutter SDK** 3.x
- **Windows 10/11** (primary target)
- **Canon camera** with EOS Webcam Utility installed and running
- **Firebase project** with:
  - Authentication (Email/Password) enabled
  - Storage bucket created
  - Web API key and bucket name in `lib/config/firebase_config.dart`

---

## Setup

1. **Clone and install dependencies**
   ```bash
   cd desktop_recorder
   flutter pub get
   ```

2. **Configure Firebase**
   - Create a Firebase project at [Firebase Console](https://console.firebase.google.com)
   - Enable Email/Password authentication
   - Create a Storage bucket
   - Copy Web API Key and bucket name to `lib/core/config/firebase_config.dart`:
     ```dart
     const String firebaseWebApiKey = 'YOUR_WEB_API_KEY';
     const String firebaseStorageBucket = 'your-bucket.appspot.com';
     ```

3. **Run on Windows**
   ```bash
   flutter run -d windows
   ```

4. **Build release**
   ```bash
   flutter build windows
   ```
   Output: `build/windows/x64/runner/Release/`

---

## Usage

1. **Sign in** — Enter username and password (new users are created on first sign-in)
2. **Camera** — Ensure Canon EOS Webcam Utility is running; camera preview appears
3. **Record** — Tap the green record button; recording starts (max 90 seconds)
4. **Preview** — After stopping, review the video
5. **Send** — Tap "Gönder" to zip and upload to Firebase Storage
6. **Sign out** — Automatic after successful upload, or use logout in app bar

---

## Kiosk Deployment

For locked-down kiosk mode:

1. Build: `flutter build windows`
2. Copy `build/windows/x64/runner/Release/*` to `C:\KioskApp\`
3. Copy `starter.bat` to the same folder
4. Run `starter.bat` as Administrator

**Exit kiosk:** Ctrl+Shift+F12 → enter PIN (default `1234`) → Exit

See `docs/kiosk_setup.md` for full details.

---

## Configuration

| Setting | Location | Description |
|---------|-----------|-------------|
| Admin PIN | `core/config/kiosk_config.dart` | Default `1234`; change for production |
| Firebase | `core/config/firebase_config.dart` | API key, storage bucket |
| Inactivity timeout | `presentation/screens/home_screen.dart` | 20 seconds before auto sign-out |
| Max recording attempts | `presentation/screens/home_screen.dart` | 3 per session |
| Max recording duration | `presentation/screens/home_screen.dart` | 90 seconds |

---

## License

Private project. See repository for details.
