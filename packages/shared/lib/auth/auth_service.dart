import 'package:firebase_auth/firebase_auth.dart';

/// Wraps Firebase Auth for phone/OTP authentication.
///
/// Both the Customer and Seller apps use this same service for sign-in.
/// Firebase is used for Auth only -- NOT for data storage.
class AuthService {
  final FirebaseAuth _auth;

  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  /// The currently signed-in Firebase user, or null.
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes (sign-in / sign-out).
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Get the current user's Firebase ID token, or null if not signed in.
  Future<String?> idToken() async {
    return _auth.currentUser?.getIdToken();
  }

  /// Start phone verification. Firebase will either auto-verify (on Android
  /// with SMS Retriever) or send an OTP that the user enters manually.
  Future<void> verifyPhone({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(FirebaseAuthException error) onError,
    required void Function(PhoneAuthCredential credential) onAutoVerify,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: onAutoVerify,
      verificationFailed: onError,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  /// Sign in with a manually-entered OTP code.
  Future<UserCredential> signInWithOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return _auth.signInWithCredential(credential);
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
