import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../utils/referral_helper.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _usersCol = 'users';
  final _referralCodesCol = 'referralCodes';
  final _withdrawalRequestsCol = 'withdrawalRequests';

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(_usersCol);
  CollectionReference<Map<String, dynamic>> get _referralCodes =>
      _firestore.collection(_referralCodesCol);
  CollectionReference<Map<String, dynamic>> get _withdrawalRequests =>
      _firestore.collection(_withdrawalRequestsCol);

  /// Ensure user doc exists; create with defaults if not. Returns user doc snapshot.
  Future<UserModel> ensureUserDocument(User user) async {
    final uid = user.uid;
    final docRef = _users.doc(uid);
    final snap = await docRef.get();

    if (snap.exists && snap.data() != null) {
      final existing = UserModel.fromFirestore(snap.data()!, uid);
      await _applyDailyBonusIfNeeded(docRef, existing);
      return existing;
    }

    String code = generateReferralCode();
    while (true) {
      final codeDoc = await _referralCodes.doc(code).get();
      if (!codeDoc.exists) break;
      code = generateReferralCode();
    }

    final now = DateTime.now();
    final dailyBonus = 1000 + Random().nextInt(2001); // 1000–3000 points (₹1–₹3)

    final defaultData = {
      'name': user.displayName ?? '',
      'email': user.email ?? '',
      'uid': uid,
      'points': dailyBonus,
      'totalEarnings': dailyBonus,
      'todayEarning': dailyBonus,
      'referredBy': null,
      'myReferralCode': code,
      'upiId': '',
      'lastLoginDate': Timestamp.fromDate(now),
      'spinsToday': 0,
      'lastSpinDate': null,
      'referralCodeApplied': false,
    };

    await docRef.set(defaultData);
    await _referralCodes.doc(code).set({'uid': uid});
    return UserModel.fromFirestore(defaultData, uid);
  }

  /// If lastLoginDate is not today, grant daily bonus and update lastLoginDate.
  Future<void> _applyDailyBonusIfNeeded(
    DocumentReference<Map<String, dynamic>> docRef,
    UserModel user,
  ) async {
    final now = DateTime.now();
    final last = user.lastLoginDate;
    if (last != null &&
        last.year == now.year &&
        last.month == now.month &&
        last.day == now.day) {
      return; // already logged in today
    }

    final bonus = 1000 + Random().nextInt(2001);
    await docRef.update({
      'points': FieldValue.increment(bonus),
      'totalEarnings': FieldValue.increment(bonus),
      'todayEarning': bonus,
      'lastLoginDate': Timestamp.fromDate(now),
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> userStream(String uid) {
    return _users.doc(uid).snapshots();
  }

  Future<UserModel?> getUser(String uid) async {
    final snap = await _users.doc(uid).get();
    if (!snap.exists || snap.data() == null) return null;
    return UserModel.fromFirestore(snap.data()!, uid);
  }

  /// Reset spins if lastSpinDate is not today.
  Future<void> ensureSpinsResetIfNewDay(String uid) async {
    final docRef = _users.doc(uid);
    final snap = await docRef.get();
    if (!snap.exists) return;
    final data = snap.data()!;
    final lastSpin = data['lastSpinDate'] as Timestamp?;
    final now = DateTime.now();
    if (lastSpin != null) {
      final d = lastSpin.toDate();
      if (d.year == now.year && d.month == now.month && d.day == now.day) return;
    }
    await docRef.update({'spinsToday': 0, 'lastSpinDate': null});
  }

  /// Returns remaining spins today (max 5). Call ensureSpinsResetIfNewDay first.
  Future<int> getRemainingSpins(String uid) async {
    final snap = await _users.doc(uid).get();
    if (!snap.exists) return 0;
    final used = (snap.data()!['spinsToday'] as int?) ?? 0;
    return (5 - used).clamp(0, 5);
  }

  static const List<int> spinRewards = [10, 25, 50, 100];

  /// Perform one spin: increment spinsToday, set lastSpinDate, add random reward to points/totalEarnings.
  /// Returns the reward amount, or 0 if no spin was performed (e.g. already at 5 spins).
  Future<int> performSpin(String uid) async {
    final docRef = _users.doc(uid);
    final reward = spinRewards[Random().nextInt(spinRewards.length)];
    final now = Timestamp.fromDate(DateTime.now());

    final applied = await _firestore.runTransaction<int>((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) return 0;
      final data = snap.data()!;
      final spinsToday = (data['spinsToday'] as int?) ?? 0;
      if (spinsToday >= 5) return 0;
      tx.update(docRef, {
        'spinsToday': spinsToday + 1,
        'lastSpinDate': now,
        'points': FieldValue.increment(reward),
        'totalEarnings': FieldValue.increment(reward),
      });
      return reward;
    });

    return applied;
  }

  Future<void> updateUpiId(String uid, String upiId) async {
    await _users.doc(uid).update({'upiId': upiId});
  }

  Future<void> createWithdrawalRequest({
    required String uid,
    required String upiId,
    required int amountRupees,
  }) async {
    await _withdrawalRequests.add({
      'uid': uid,
      'upiId': upiId,
      'amount': amountRupees,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deduct points when withdrawal is requested (1000 points = ₹1).
  Future<bool> deductPointsForWithdrawal(String uid, int rupees) async {
    final pointsToDeduct = rupees * 1000;
    final docRef = _users.doc(uid);
    return _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) return false;
      final current = (snap.data()!['points'] as int?) ?? 0;
      if (current < pointsToDeduct) return false;
      tx.update(docRef, {'points': current - pointsToDeduct});
      return true;
    });
  }

  /// Apply referral: set referredBy, give 2000 points to both. Only if not already applied.
  Future<bool> applyReferralCode(String uid, String code) async {
    if (code.isEmpty) return false;
    final codeDoc = await _referralCodes.doc(code.toUpperCase()).get();
    if (!codeDoc.exists) return false;
    final referrerUid = codeDoc.data()?['uid'] as String?;
    if (referrerUid == null || referrerUid == uid) return false;

    final userRef = _users.doc(uid);
    final userSnap = await userRef.get();
    if (!userSnap.exists) return false;
    if ((userSnap.data()!['referralCodeApplied'] as bool?) == true) return false;

    final referrerRef = _users.doc(referrerUid);
    const bonus = 2000;

    await _firestore.runTransaction((tx) async {
      tx.update(userRef, {
        'referredBy': code,
        'referralCodeApplied': true,
        'points': FieldValue.increment(bonus),
        'totalEarnings': FieldValue.increment(bonus),
      });
      tx.update(referrerRef, {
        'points': FieldValue.increment(bonus),
        'totalEarnings': FieldValue.increment(bonus),
      });
    });
    return true;
  }
}
