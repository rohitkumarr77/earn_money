import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class UserProvider with ChangeNotifier {
  UserProvider({
    required AuthService authService,
    required FirestoreService firestoreService,
  })  : _auth = authService,
        _firestore = firestoreService;

  final AuthService _auth;
  final FirestoreService _firestore;

  User? get firebaseUser => _auth.currentUser;
  UserModel? _user;
  UserModel? get user => _user;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  String? _error;

  Future<void> init() async {
    _auth.authStateChanges.listen((User? u) async {
      if (u == null) {
        _cleanup();
        notifyListeners();
        return;
      }
      await ensureUserAndListen(u.uid);
    });
    final u = _auth.currentUser;
    if (u != null) await ensureUserAndListen(u.uid);
    notifyListeners();
  }

  Future<void> ensureUserAndListen(String uid) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      _user = await _firestore.ensureUserDocument(user);
      _userSub?.cancel();
      _userSub = _firestore.userStream(uid).listen((snap) {
        if (snap.exists && snap.data() != null) {
          _user = UserModel.fromFirestore(snap.data()!, uid);
          notifyListeners();
        }
      });
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  void _cleanup() {
    _userSub?.cancel();
    _userSub = null;
    _user = null;
    _error = null;
  }

  /// Returns null if user cancelled; otherwise returns after user is ready.
  Future<UserCredential?> signInWithGoogle() async {
    final cred = await _auth.signInWithGoogle();
    if (cred?.user != null) await ensureUserAndListen(cred!.user!.uid);
    return cred;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _cleanup();
    notifyListeners();
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }
}
