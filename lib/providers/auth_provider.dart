import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AuthStatus _status = AuthStatus.initial;
  User? _user;
  String? _errorMessage;

  AuthStatus get status => _status;
  User? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  /// Phone number stored at login for display purposes.
  String? _phone;
  String? get phone => _phone;

  AuthProvider() {
    _user = _auth.currentUser;
    _status = _user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;

    _auth.authStateChanges().listen((user) {
      _user = user;
      _status =
          user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
      notifyListeners();
    });
  }

  // Derive a valid Firebase email from the phone number.
  // The phone acts as the username; this is never shown to the user.
  static String _emailFrom(String phone) => '$phone@mobilebank.com';

  Future<bool> signIn(String phone, String mpin) async {
    _loading();
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailFrom(phone),
        password: mpin,
      );
      _phone = phone;
      return true;
    } on FirebaseAuthException catch (e) {
      _error(_friendlyMessage(e.code));
      return false;
    }
  }

  Future<bool> register(String phone, String mpin) async {
    _loading();
    try {
      await _auth.createUserWithEmailAndPassword(
        email: _emailFrom(phone),
        password: mpin,
      );
      _phone = phone;
      return true;
    } on FirebaseAuthException catch (e) {
      _error(_friendlyMessage(e.code));
      return false;
    }
  }

  /// Re-authenticates with [currentMpin] then updates to [newMpin].
  Future<bool> changeMpin(String currentMpin, String newMpin) async {
    _loading();
    try {
      final user = _auth.currentUser!;
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentMpin,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newMpin);
      _status = AuthStatus.authenticated;
      _errorMessage = null;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error(_friendlyMessage(e.code));
      return false;
    }
  }

  Future<void> signOut() async {
    _phone = null;
    await _auth.signOut();
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  void _loading() {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _error(String msg) {
    _status = AuthStatus.error;
    _errorMessage = msg;
    notifyListeners();
  }

  String _friendlyMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found for this number.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect MPIN. Please try again.';
      case 'email-already-in-use':
        return 'This phone number is already registered.';
      case 'too-many-requests':
        return 'Too many attempts. Please try later.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
