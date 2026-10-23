import 'package:firebase_auth/firebase_auth.dart';

/// Firebase Authentication Service for ReadJournal
class AuthService {
  AuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Stream of user auth changes (logged in / logged out)
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Currently logged in user (null if guest / logged out)
  static User? get currentUser => _auth.currentUser;

  /// Sign In with Email & Password
  static Future<UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Register a new account with Email & Password
  static Future<UserCredential> signUpWithEmailPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    if (displayName != null && displayName.trim().isNotEmpty) {
      await credential.user?.updateDisplayName(displayName.trim());
      await credential.user?.reload();
    }

    return credential;
  }

  /// Sign In Anonymously (Guest / Demo mode)
  static Future<UserCredential> signInAnonymously() async {
    return await _auth.signInAnonymously();
  }

  /// Send password reset link
  static Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Sign Out
  static Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Translates FirebaseAuthException into user-friendly message
  static String getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No account found with this email.';
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect email or password. Please try again.';
        case 'email-already-in-use':
          return 'An account already exists for this email.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'weak-password':
          return 'Password must be at least 6 characters.';
        case 'operation-not-allowed':
          return 'Email/Password sign-in is not enabled in Firebase Console.';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection.';
        default:
          return error.message ?? 'Authentication error (${error.code}).';
      }
    }
    return error.toString();
  }
}
