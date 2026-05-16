// File: lib/firebase_options.dart
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux. '
          'You can reconfigure this by running FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Web config
  static final FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCBkcpyamtUJPI9qQo6vZisNaeO9tEk4fQ',
    appId: '1:917940140360:web:e5e36005d124df26859b7d',
    messagingSenderId: '917940140360',
    projectId: 'ziscord-4c7ff',
    authDomain: 'ziscord-4c7ff.firebaseapp.com',
    storageBucket: 'ziscord-4c7ff.firebasestorage.app',
    measurementId: 'G-QBMV56WG4Z',
  );

  // Android config
  static final FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDuKJKVTdLih5dHmPcrUoOvpRmM9qwLyQY',
    appId: '1:917940140360:android:1f23f454612daff4859b7d',
    messagingSenderId: '917940140360',
    projectId: 'ziscord-4c7ff',
    storageBucket: 'ziscord-4c7ff.firebasestorage.app',
  );

  // iOS config
  static final FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDA64HMdX0HRGIyLI1a03F77Ts7UWEOULg',
    appId: '1:917940140360:ios:cdbb47a76cc08faa859b7d',
    messagingSenderId: '917940140360',
    projectId: 'ziscord-4c7ff',
    storageBucket: 'ziscord-4c7ff.firebasestorage.app',
    iosBundleId: 'com.example.ziscord',
  );

  // macOS config (dùng chung iOS)
  static final FirebaseOptions macos = ios;

  // Windows config (dùng chung Web)
  static final FirebaseOptions windows = web;
}