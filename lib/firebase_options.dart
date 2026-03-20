// Firebase: one *project*, separate *apps* per platform (Android vs iOS).
//
// If you only registered Android in the Firebase Console, add an iOS app to the SAME project:
//   Firebase Console → Project overview → "Add app" → iOS
//   Bundle ID must be: com.auction.lilly (matches Xcode & Android applicationId)
//   Download GoogleService-Info.plist → replace ios/Runner/GoogleService-Info.plist
//   Copy API_KEY, GOOGLE_APP_ID from that file into [ios] below (and refresh [macos] if needed).
//
// Or run: dart pub global run flutterfire_cli:flutterfire configure

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for the auction-command Firebase project.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB8YrtOjk0hV37stEAFus0C-RUUdcVhmuQ',
    appId: '1:26908867979:android:268600ee98442c3cdd038e',
    messagingSenderId: '26908867979',
    projectId: 'auction-command',
    storageBucket: 'auction-command.firebasestorage.app',
  );

  /// Values must match ios/Runner/GoogleService-Info.plist after you register the iOS app.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCmviwxHdEdYlaLVNfBjQPRpL6nVojKWto',
    appId: '1:26908867979:ios:9bb9c0b6957d7991dd038e',
    messagingSenderId: '26908867979',
    projectId: 'auction-command',
    storageBucket: 'auction-command.firebasestorage.app',
    iosBundleId: 'com.auction.lilly',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCmviwxHdEdYlaLVNfBjQPRpL6nVojKWto',
    appId: '1:26908867979:ios:9bb9c0b6957d7991dd038e',
    messagingSenderId: '26908867979',
    projectId: 'auction-command',
    storageBucket: 'auction-command.firebasestorage.app',
    iosBundleId: 'com.auction.lilly',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB8YrtOjk0hV37stEAFus0C-RUUdcVhmuQ',
    appId: '1:26908867979:android:268600ee98442c3cdd038e',
    messagingSenderId: '26908867979',
    projectId: 'auction-command',
    authDomain: 'auction-command.firebaseapp.com',
    storageBucket: 'auction-command.firebasestorage.app',
  );
}
