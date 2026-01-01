
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/users.dart';

class AuthProvider with ChangeNotifier {
  final fbAuth.FirebaseAuth _auth = fbAuth.FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? _currentUser;
  bool _isLoading = false;

  User? get user => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _auth.authStateChanges().listen((fbUser) async {
      if (fbUser != null) {
        final doc = await _db.collection('users').doc(fbUser.uid).get();
        if (doc.exists) {
          _currentUser = User.fromJson(doc.data()!, doc.id);
        }
      } else {
        _currentUser = null;
      }
      notifyListeners();
    });
  }

  // REGISTER
  Future<void> registerUser(User user, String password) async {
    _isLoading = true;
    notifyListeners();

    final cred = await _auth.createUserWithEmailAndPassword(
      email: user.email,
      password: password,
    );

    await cred.user!.sendEmailVerification();

    final newUser = user.copyWith(
      id: cred.user!.uid,
      createdAt: DateTime.now(),
    );

    await _db.collection('users').doc(newUser.id).set(newUser.toJson());

    _currentUser = newUser;
    _isLoading = false;
    notifyListeners();
  }

  // LOGIN
  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final doc = await _db.collection('users').doc(cred.user!.uid).get();
    if (doc.exists) {
      _currentUser = User.fromJson(doc.data()!, doc.id);
    }

    _isLoading = false;
    notifyListeners();
  }

  // POINTS
  Future<void> incrementPoints(int points) async {
    if (_currentUser == null) return;

    final updated = _currentUser!.copyWith(
      points: (_currentUser!.points) + points,
    );

    await _db.collection('users').doc(updated.id).update({
      'points': updated.points,
    });

    _currentUser = updated;
    notifyListeners();
  }

  // REFRESH USER DATA
  void refreshUserData() async {
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.id)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        _currentUser = User.fromJson(userData, user!.id);
        notifyListeners();
      }
    }
  }

  // USERNAME
  Future<void> updateUsername(String username) async {
    if (_currentUser == null) return;

    await _db.collection('users').doc(_currentUser!.id).update({
      'username': username,
    });

    _currentUser = _currentUser!.copyWith(username: username);
    notifyListeners();
  }

  // LOGOUT
  Future<void> logout() async {
    await _auth.signOut();
    _currentUser = null;
    notifyListeners();
  }

  Future<void> resendVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }
}
