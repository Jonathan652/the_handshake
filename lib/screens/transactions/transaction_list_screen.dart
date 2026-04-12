import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:async/async.dart';
import 'transaction_detail_screen.dart';

class TransactionListScreen extends StatelessWidget {
  const TransactionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF1EFE8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF534AB7),
        title: const Text(
          'My transactions',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<QuerySnapshot>>(
  stream: StreamZip([
    FirebaseFirestore.instance
      .collection('transactions')
      .where('buyerId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots(),
    FirebaseFirestore.instance
      .collection('transactions')
      .where('sellerId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots(),
  ]),
  builder: (context, snap) {
    if (snap.connectionState == ConnectionState.waiting) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF534AB7)),
      );
    }

    if (!snap.hasData) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF534AB7)),
      );
    }

    // Merge both query results and remove duplicates
    final allDocs = <String, QueryDocumentSnapshot>{};
    for (final snapshot in snap.data!) {
      for (final doc in snapshot.docs) {
        allDocs[doc.id] = doc;
      }
    }

    final docs = allDocs.values.toList()
      ..sort((a, b) {
        final aTime = (a.data() as Map)['createdAt'];
        final bTime = (b.data() as Map)['createdAt'];
        if (aTime == null || bTime == null) return 0;
        return (bTime as Timestamp).compareTo(aTime as Timestamp);
      });

    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
              size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No transactions yet',
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold,
                color: Color(0xFF888780),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a new transaction to get started',
              style: TextStyle(color: Color(0xFF888780), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final data  = docs[i].data() as Map<String, dynamic>;
        final txnId = docs[i].id;
        final isBuyer = data['buyerId'] == uid;

        return _TransactionCard(
          txnId:   txnId,
          data:    data,
          isBuyer: isBuyer,
          onTap:   () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TransactionDetailScreen(txnId: txnId),            ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}


class _TransactionCard extends StatelessWidget {
  final String txnId;
  final Map<String, dynamic> data;
  final bool isBuyer;
  final VoidCallback onTap;

  const _TransactionCard({
    required this.txnId,
    required this.data,
    required this.isBuyer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final state       = data['currentState'] ?? 'CREATED';
    final description = data['description'] ?? '';
    final totalUgx    = data['totalUgx'] ?? 0;
    final stateConfig = _stateConfig(state);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD3D1C7), width: 0.5),
        ),
        child: Row(
          children: [
            // State indicator dot
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                color: stateConfig['color'] as Color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),

            // Main content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF2C2C2A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (stateConfig['color'] as Color).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          stateConfig['label'] as String,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: stateConfig['color'] as Color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isBuyer ? 'You are buyer' : 'You are seller',
                        style: const TextStyle(
                          fontSize: 11, color: Color(0xFF888780),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'UGX ${_format(totalUgx)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF534AB7),
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right,
                  color: Color(0xFF888780), size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _stateConfig(String state) {
    switch (state) {
      case 'CREATED':
        return {'color': const Color(0xFF888780), 'label': 'Created'};
      case 'LOCKED':
        return {'color': const Color(0xFF854F0B), 'label': 'Locked'};
      case 'PENDING_DELIVERY':
        return {'color': const Color(0xFF534AB7), 'label': 'Pending delivery'};
      case 'IN_TRANSIT':
        return {'color': const Color(0xFF185FA5), 'label': 'In transit'};
      case 'INSPECTION_WINDOW':
        return {'color': const Color(0xFF185FA5), 'label': 'Inspection window'};
      case 'COMPLETED':
        return {'color': const Color(0xFF0F6E56), 'label': 'Completed'};
      case 'DISPUTED':
        return {'color': const Color(0xFFA32D2D), 'label': 'Disputed'};
      case 'REFUNDED':
        return {'color': const Color(0xFF0F6E56), 'label': 'Refunded'};
      default:
        return {'color': const Color(0xFF888780), 'label': state};
    }
  }

  String _format(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}