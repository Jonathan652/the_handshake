class UserModel {
  final String uid;
  final String phoneNumber;
  final String momoNumber;
  final String displayName;
  final String role;
  final bool isVerified;
  final int walletBalance;
  final int totalTransactions;
  final int disputeCount;
  final int trustScore;

  UserModel({
    required this.uid,
    required this.phoneNumber,
    required this.momoNumber,
    required this.displayName,
    this.role = 'user',
    this.isVerified = false,
    this.walletBalance = 10000000,
    this.totalTransactions = 0,
    this.disputeCount = 0,
    this.trustScore = 0,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid:               uid,
      phoneNumber:       data['phoneNumber'] ?? '',
      momoNumber:        data['momoNumber'] ?? '',
      displayName:       data['displayName'] ?? '',
      role:              data['role'] ?? 'user',
      isVerified:        data['isVerified'] ?? false,
      walletBalance:     data['walletBalance'] ?? 10000000,
      totalTransactions: data['totalTransactions'] ?? 0,
      disputeCount:      data['disputeCount'] ?? 0,
      trustScore:        data['trustScore'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'phoneNumber':       phoneNumber,
      'momoNumber':        momoNumber,
      'displayName':       displayName,
      'role':              role,
      'isVerified':        isVerified,
      'walletBalance':     walletBalance,
      'totalTransactions': totalTransactions,
      'disputeCount':      disputeCount,
      'trustScore':        trustScore,
    };
  }
}