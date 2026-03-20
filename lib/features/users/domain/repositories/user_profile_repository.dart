import 'package:firebase_auth/firebase_auth.dart';

/// Syncs Firebase Auth user into the `users` collection (profile + team link).
abstract class UserProfileRepository {
  Future<void> syncUserDocumentAfterSignIn(User user);
}
