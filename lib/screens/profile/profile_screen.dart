import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid  = FirebaseAuth.instance.currentUser!.uid;
    final auth = AuthService();

    return Scaffold(
      backgroundColor: const Color(0xFFF1EFE8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF534AB7),
        title: const Text(
          'Profile',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: const Text('Sign out',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  content:
                      const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF534AB7),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) await auth.signOut();
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF534AB7)),
            );
          }

          final data    = snap.data!.data() as Map<String, dynamic>? ?? {};
          final name    = data['displayName'] ?? 'User';
          final email   = FirebaseAuth.instance.currentUser?.email ?? '';
          final phone   = data['phoneNumber'] ?? '';
          final momo    = data['momoNumber'] ?? '';
          final balance = data['walletBalance'] ?? 0;
          final txns    = data['totalTransactions'] ?? 0;
          final trust   = data['trustScore'] ?? 0;
          final disputes= data['disputeCount'] ?? 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                // Avatar + name
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80, height: 80,
                        decoration: const BoxDecoration(
                          color: Color(0xFF534AB7),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            name.isNotEmpty
                                ? name[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C2C2A),
                        )),
                      const SizedBox(height: 4),
                      Text(email,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF888780),
                        )),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Wallet card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF534AB7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Virtual wallet',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'UGX ${_format(balance)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _showTopUpDialog(context, uid, balance),
                          icon: const Icon(Icons.add,
                              color: Colors.white, size: 18),
                          label: const Text('Top up balance',
                            style: TextStyle(color: Colors.white)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: Colors.white54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Stats
                Row(
                  children: [
                    _StatCard(label: 'Transactions', value: '$txns'),
                    const SizedBox(width: 10),
                    _StatCard(label: 'Trust score',  value: '$trust'),
                    const SizedBox(width: 10),
                    _StatCard(label: 'Disputes',     value: '$disputes'),
                  ],
                ),
                const SizedBox(height: 16),

                // Details card
                _InfoCard(
                  title: 'Account details',
                  rows: [
                    _InfoRow(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: phone.isEmpty ? 'Not set' : phone,
                    ),
                    _InfoRow(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'MoMo number',
                      value: momo.isEmpty ? 'Not set' : momo,
                    ),
                    _InfoRow(
                      icon: Icons.verified_user_outlined,
                      label: 'Account status',
                      value: data['isVerified'] == true
                          ? 'Verified'
                          : 'Unverified',
                      valueColor: data['isVerified'] == true
                          ? const Color(0xFF0F6E56)
                          : const Color(0xFF854F0B),
                    ),
                    _InfoRow(
                      icon: Icons.shield_outlined,
                      label: 'Role',
                      value: data['role'] ?? 'user',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // MVP notice
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAEEDA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF854F0B), width: 0.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                        color: Color(0xFF854F0B), size: 18),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'This is a demo build using a virtual wallet. '
                          'Real MTN MoMo integration coming in production.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF633806),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showTopUpDialog(
      BuildContext context, String uid, int currentBalance) {
    final amounts = [5000000, 10000000, 20000000, 50000000];
    final labels  = ['UGX 5M', 'UGX 10M', 'UGX 20M', 'UGX 50M'];

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Top up virtual wallet',
          style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select an amount to add to your demo wallet:',
              style: TextStyle(
                  fontSize: 13, color: Color(0xFF888780)),
            ),
            const SizedBox(height: 16),
            ...List.generate(amounts.length, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .update({
                      'walletBalance':
                          currentBalance + amounts[i],
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF0F6E56),
                          content: Text(
                            '${labels[i]} added to your wallet'),
                        ),
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: Color(0xFF534AB7)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(labels[i],
                    style: const TextStyle(
                      color: Color(0xFF534AB7),
                      fontWeight: FontWeight.bold,
                    )),
                ),
              ),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  String _format(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFFD3D1C7), width: 0.5),
        ),
        child: Column(
          children: [
            Text(value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF534AB7),
              )),
            const SizedBox(height: 4),
            Text(label,
              style: const TextStyle(
                fontSize: 11, color: Color(0xFF888780)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<_InfoRow> rows;
  const _InfoCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFFD3D1C7), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF2C2C2A),
            )),
          const SizedBox(height: 14),
          ...rows.map((row) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(row.icon,
                  color: const Color(0xFF534AB7), size: 18),
                const SizedBox(width: 10),
                Text(row.label,
                  style: const TextStyle(
                    fontSize: 13, color: Color(0xFF888780))),
                const Spacer(),
                Text(row.value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: row.valueColor ??
                        const Color(0xFF2C2C2A),
                  )),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _InfoRow {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });
}