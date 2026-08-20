class UserModel {
  final String uid;
  final String name;
  final String email;
  final int points;
  final int totalEarnings;
  final int todayEarning;
  final String? referredBy;
  final String myReferralCode;
  final String upiId;
  final DateTime? lastLoginDate;
  final int spinsToday;
  final DateTime? lastSpinDate;
  final bool referralCodeApplied;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.points,
    required this.totalEarnings,
    required this.todayEarning,
    this.referredBy,
    required this.myReferralCode,
    required this.upiId,
    this.lastLoginDate,
    required this.spinsToday,
    this.lastSpinDate,
    required this.referralCodeApplied,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      points: (map['points'] ?? map['point']) as int? ?? 0,
      totalEarnings: (map['totalEarnings'] ?? map['totalEarning']) as int? ?? 0,
      todayEarning: (map['todayEarning'] as int?) ?? 0,
      referredBy: map['referredBy'] as String?,
      myReferralCode: map['myReferralCode'] as String? ?? map['myReferralC'] as String? ?? '',
      upiId: map['upiId'] as String? ?? map['upid'] as String? ?? '',
      lastLoginDate: _parseTimestamp(map['lastLoginDate'] ?? map['lastLoging']),
      spinsToday: (map['spinsToday'] as int?) ?? 0,
      lastSpinDate: _parseTimestamp(map['lastSpinDate']),
      referralCodeApplied: (map['referralCodeApplied'] as bool?) ?? false,
    );
  }

  static DateTime? _parseTimestamp(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    // Firestore Timestamp
    try {
      return (v as dynamic).toDate() as DateTime?;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'uid': uid,
      'points': points,
      'totalEarnings': totalEarnings,
      'todayEarning': todayEarning,
      'referredBy': referredBy,
      'myReferralCode': myReferralCode,
      'upiId': upiId,
      'lastLoginDate': lastLoginDate,
      'spinsToday': spinsToday,
      'lastSpinDate': lastSpinDate,
      'referralCodeApplied': referralCodeApplied,
    };
  }

  UserModel copyWith({
    String? name,
    String? email,
    int? points,
    int? totalEarnings,
    int? todayEarning,
    String? referredBy,
    String? myReferralCode,
    String? upiId,
    DateTime? lastLoginDate,
    int? spinsToday,
    DateTime? lastSpinDate,
    bool? referralCodeApplied,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      points: points ?? this.points,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      todayEarning: todayEarning ?? this.todayEarning,
      referredBy: referredBy ?? this.referredBy,
      myReferralCode: myReferralCode ?? this.myReferralCode,
      upiId: upiId ?? this.upiId,
      lastLoginDate: lastLoginDate ?? this.lastLoginDate,
      spinsToday: spinsToday ?? this.spinsToday,
      lastSpinDate: lastSpinDate ?? this.lastSpinDate,
      referralCodeApplied: referralCodeApplied ?? this.referralCodeApplied,
    );
  }
}
