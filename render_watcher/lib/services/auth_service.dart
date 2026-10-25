import 'package:firebase_auth/firebase_auth.dart';

class AuthFailure implements Exception {
  AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// GitHub is the only provider. Firebase runs the OAuth redirect itself, so
/// the app needs no GitHub client secret — it lives in the Firebase console.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _injected = auth;

  final FirebaseAuth? _injected;

  /// Lazy for the same reason as PushService: no Firebase access at
  /// construction time.
  FirebaseAuth get _auth => _injected ?? FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  bool get signedIn => _auth.currentUser != null;

  Future<User> signInWithGitHub() async {
    try {
      final provider = GithubAuthProvider()..addScope('read:user');
      final cred = await _auth.signInWithProvider(provider);
      final user = cred.user;
      if (user == null) throw AuthFailure('GitHub sign-in returned no account');
      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_readable(e));
    }
  }

  Future<void> signOut() => _auth.signOut();

  String _readable(FirebaseAuthException e) => switch (e.code) {
        'web-context-canceled' || 'canceled' || 'user-canceled' => 'Sign-in cancelled',
        'network-request-failed' => 'No connection. Check your network and try again.',
        'account-exists-with-different-credential' =>
          'That email is already signed in with another provider.',
        'operation-not-allowed' =>
          'GitHub sign-in is not enabled for this Firebase project yet.',
        'invalid-api-key' || 'api-key-not-valid' =>
          'This build has the wrong Firebase config.',
        _ => e.message ?? 'GitHub sign-in failed (${e.code})',
      };
}
