import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/transaction_service.dart';

class TransactionDetailScreen extends StatefulWidget {
  final String txnId;
  const TransactionDetailScreen({super.key, required this.txnId});

  @override
  State<TransactionDetailScreen> createState() =>
    _TransactionDetailScreenState();
}

class _TransactionDetailScreenState
    extends State<TransactionDetailScreen> {
  final _txnService = TransactionService();
  bool _loading     = false;

  Future<void> _sellerAccept(String sellerId) async {
    setState(() => _loading = true);
    try {
      await _txnService.sellerAccept(widget.txnId, sellerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF0F6E56),
            content: Text('Order accepted — pending delivery'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFA32D2D),
            content: Text(e.toString()),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sellerReject(
      String sellerId, int vaultAmount) async {
    final confirmed = await _confirmDialog(
      title:   'Reject order',
      message: 'This will refund UGX ${_format(vaultAmount)} to the buyer.',
      confirm: 'Reject',
      danger:  true,
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      await _txnService.sellerReject(widget.txnId, sellerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order rejected — buyer refunded')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFA32D2D),
            content: Text(e.toString()),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _buyerConfirm(
      String buyerId, int vaultAmount) async {
    final confirmed = await _confirmDialog(
      title:   'Confirm receipt',
      message: 'This will release UGX ${_format(vaultAmount)} '
               'to the seller. This cannot be undone.',
      confirm: 'Confirm receipt',
      danger:  false,
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      final result =
          await _txnService.confirmDelivery(widget.txnId, buyerId);
      if (mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF0F6E56),
              content: Text(
                'Payment released to seller. '
                'Your balance: UGX ${_format(result.balanceAfter ?? 0)}',
              ),
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFA32D2D),
              content: Text(result.message),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFA32D2D),
            content: Text(e.toString()),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _raiseDispute(String buyerId) async {
    final confirmed = await _confirmDialog(
      title:   'Raise dispute',
      message: 'Funds will be frozen until an arbiter resolves this.',
      confirm: 'Raise dispute',
      danger:  true,
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      final txnRef = FirebaseFirestore.instance
          .collection('transactions')
          .doc(widget.txnId);
      await txnRef.update({'currentState': 'DISPUTED'});

      await FirebaseFirestore.instance.collection('disputes').add({
        'txnId':       widget.txnId,
        'raisedByUid': buyerId,
        'reasonCode':  'OTHER',
        'description': 'Raised by buyer',
        'status':      'OPEN',
        'arbiterId':   null,
        'resolution':  null,
        'raisedAt':    FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('audit_log').add({
        'txnId':     widget.txnId,
        'actorUid':  buyerId,
        'fromState': 'PENDING_DELIVERY',
        'toState':   'DISPUTED',
        'action':    'dispute_raised',
        'occurredAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF854F0B),
            content: Text('Dispute raised — funds frozen'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFA32D2D),
            content: Text(e.toString()),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF1EFE8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF534AB7),
        title: const Text(
          'Transaction detail',
          style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('transactions')
            .doc(widget.txnId)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF534AB7)),
            );
          }

          final data     = snap.data!.data() as Map<String, dynamic>;
          final state    = data['currentState'] ?? '';
          final isBuyer  = data['buyerId'] == uid;
          final isSeller = data['sellerId'] == uid;
          final vault    = data['vaultAmount'] ?? 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                // State banner
                _StateBanner(state: state),
                const SizedBox(height: 16),

                // Details card
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Transaction details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF2C2C2A),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _row('Item',        data['description'] ?? ''),
                      _row('Delivery',    data['deliveryType'] ?? ''),
                      _row('Your role',   isBuyer ? 'Buyer' : 'Seller'),
                      const Divider(height: 20),
                      _row('Amount',
                        'UGX ${_format(data['amountUgx'] ?? 0)}'),
                      _row('Service fee',
                        'UGX ${_format(data['feeUgx'] ?? 0)}'),
                      _row('Total locked',
                        'UGX ${_format(data['totalUgx'] ?? 0)}',
                        bold: true,
                        color: const Color(0xFF534AB7)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Vault card
                if (vault > 0)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEEDFE),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF534AB7), width: 0.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock,
                          color: Color(0xFF534AB7), size: 20),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('In escrow',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF534AB7),
                              ),
                            ),
                            Text(
                              'UGX ${_format(vault)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF534AB7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),

                // ── ACTION BUTTONS by role + state ──
                if (_loading)
                  const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF534AB7)),
                  )
                else ...[

                  // SELLER actions when LOCKED
                  if (isSeller && state == 'LOCKED') ...[
                    _actionButton(
                      label: 'Accept order',
                      icon:  Icons.check_circle_outline,
                      color: const Color(0xFF0F6E56),
                      onTap: () => _sellerAccept(uid),
                    ),
                    const SizedBox(height: 10),
                    _actionButton(
                      label:   'Reject order',
                      icon:    Icons.cancel_outlined,
                      color:   const Color(0xFFA32D2D),
                      onTap:   () => _sellerReject(uid, vault),
                      outline: true,
                    ),
                  ],

                  // BUYER actions when PENDING_DELIVERY
                  if (isBuyer && state == 'PENDING_DELIVERY') ...[
                    _actionButton(
                      label: 'Confirm receipt',
                      icon:  Icons.verified_outlined,
                      color: const Color(0xFF0F6E56),
                      onTap: () => _buyerConfirm(uid, vault),
                    ),
                    const SizedBox(height: 10),
                    _actionButton(
                      label:   'Raise dispute',
                      icon:    Icons.gavel_outlined,
                      color:   const Color(0xFFA32D2D),
                      onTap:   () => _raiseDispute(uid),
                      outline: true,
                    ),
                  ],

                  // Terminal states
                  if (state == 'COMPLETED')
                    _statusChip(
                      'Transaction completed',
                      Icons.check_circle,
                      const Color(0xFF0F6E56),
                    ),
                  if (state == 'REFUNDED')
                    _statusChip(
                      'Refunded to buyer',
                      Icons.undo,
                      const Color(0xFF888780),
                    ),
                  if (state == 'DISPUTED')
                    _statusChip(
                      'Under dispute — funds frozen',
                      Icons.gavel,
                      const Color(0xFFA32D2D),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFD3D1C7), width: 0.5),
    ),
    child: child,
  );

  Widget _row(String label, String value,
      {bool bold = false, Color color = const Color(0xFF2C2C2A)}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
            style: const TextStyle(
              fontSize: 13, color: Color(0xFF888780))),
          Text(value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color,
            )),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool outline = false,
  }) {
    return SizedBox(
      height: 50,
      child: outline
        ? OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, color: color),
            label: Text(label,
              style: TextStyle(
                color: color, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: color),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            ),
          )
        : ElevatedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, color: Colors.white),
            label: Text(label,
              style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            ),
          ),
    );
  }

  Widget _statusChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            )),
        ],
      ),
    );
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String message,
    required String confirm,
    required bool danger,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message,
          style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: danger
                ? const Color(0xFFA32D2D)
                : const Color(0xFF534AB7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(confirm),
          ),
        ],
      ),
    );
  }

  String _format(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}


class _StateBanner extends StatelessWidget {
  final String state;
  const _StateBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    final config = _config();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: (config['color'] as Color).withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (config['color'] as Color).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(config['icon'] as IconData,
            color: config['color'] as Color, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(config['label'] as String,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: config['color'] as Color,
                  fontSize: 14,
                )),
              Text(config['subtitle'] as String,
                style: TextStyle(
                  fontSize: 12,
                  color: (config['color'] as Color).withOpacity(0.8),
                )),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _config() {
    switch (state) {
      case 'CREATED':
        return {
          'color':    const Color(0xFF888780),
          'icon':     Icons.edit_outlined,
          'label':    'Created',
          'subtitle': 'Waiting for payment to be locked',
        };
      case 'LOCKED':
        return {
          'color':    const Color(0xFF854F0B),
          'icon':     Icons.lock_outline,
          'label':    'Funds locked in escrow',
          'subtitle': 'Waiting for seller to accept',
        };
      case 'PENDING_DELIVERY':
        return {
          'color':    const Color(0xFF534AB7),
          'icon':     Icons.local_shipping_outlined,
          'label':    'Pending delivery',
          'subtitle': 'Seller has accepted — awaiting delivery',
        };
      case 'COMPLETED':
        return {
          'color':    const Color(0xFF0F6E56),
          'icon':     Icons.check_circle_outline,
          'label':    'Completed',
          'subtitle': 'Funds released to seller',
        };
      case 'DISPUTED':
        return {
          'color':    const Color(0xFFA32D2D),
          'icon':     Icons.gavel_outlined,
          'label':    'Disputed',
          'subtitle': 'Funds frozen — awaiting arbiter',
        };
      case 'REFUNDED':
        return {
          'color':    const Color(0xFF0F6E56),
          'icon':     Icons.undo,
          'label':    'Refunded',
          'subtitle': 'Funds returned to buyer',
        };
      default:
        return {
          'color':    const Color(0xFF888780),
          'icon':     Icons.info_outline,
          'label':    state,
          'subtitle': '',
        };
    }
  }
}