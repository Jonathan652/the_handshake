import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/transaction_service.dart';

class NewTransactionScreen extends StatefulWidget {
  const NewTransactionScreen({super.key});

  @override
  State<NewTransactionScreen> createState() => _NewTransactionScreenState();
}

class _NewTransactionScreenState extends State<NewTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sellerCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _txnService = TransactionService();

  String _deliveryType = 'IN_PERSON';
  bool _loading = false;
  bool _searching = false;
  String? _error;

  // Resolved seller data
  Map<String, dynamic>? _sellerData;
  String? _sellerId;

  // Fee calculation
  int _amountUgx = 0;
  int _feeUgx = 0;
  int _totalUgx = 0;

  @override
  void dispose() {
    _sellerCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // Look up seller by email in Firestore
  Future<void> _lookupSeller() async {
    final input = _sellerCtrl.text.trim();
    if (input.isEmpty) return;

    setState(() {
      _searching = true;
      _sellerData = null;
      _sellerId = null;
      _error = null;
    });

    try {
      final currentUid = FirebaseAuth.instance.currentUser!.uid;

      // Search by email
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: input)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        // Try by phone number
        final snapPhone = await FirebaseFirestore.instance
            .collection('users')
            .where('phoneNumber', isEqualTo: input)
            .limit(1)
            .get();

        if (snapPhone.docs.isEmpty) {
          setState(() {
            _error = 'No user found with that email or phone number.';
            _searching = false;
          });
          return;
        }

        final doc = snapPhone.docs.first;
        if (doc.id == currentUid) {
          setState(() {
            _error = 'You cannot transact with yourself.';
            _searching = false;
          });
          return;
        }

        setState(() {
          _sellerData = doc.data();
          _sellerId = doc.id;
        });
      } else {
        final doc = snap.docs.first;
        if (doc.id == currentUid) {
          setState(() {
            _error = 'You cannot transact with yourself.';
            _searching = false;
          });
          return;
        }

        setState(() {
          _sellerData = doc.data();
          _sellerId = doc.id;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Lookup failed: ${e.toString()}';
      });
    } finally {
      setState(() {
        _searching = false;
      });
    }
  }

  // Recalculate fee when amount changes
  void _onAmountChanged(String val) {
    final parsed = int.tryParse(val.replaceAll(',', '')) ?? 0;
    final fee = _txnService.calculateFee(parsed);
    setState(() {
      _amountUgx = parsed;
      _feeUgx = fee;
      _totalUgx = parsed + fee;
    });
  }

  Future<void> _lockFunds() async {
    if (!_formKey.currentState!.validate()) return;
    if (_sellerId == null) {
      setState(() {
        _error = 'Please find a valid seller first.';
      });
      return;
    }

    // Confirm dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Confirm lock',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
            color: Color(0xFF0F172A),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _confirmRow('Seller', _sellerData!['displayName']),
            _confirmRow('Item', _descCtrl.text.trim()),
            _confirmRow('Amount', 'UGX ${_format(_amountUgx)}'),
            _confirmRow('Fee', 'UGX ${_format(_feeUgx)}'),
            const Divider(height: 20),
            _confirmRow('Total', 'UGX ${_format(_totalUgx)}',
                bold: true, color: const Color(0xFF064E3B)),
            const SizedBox(height: 8),
            const Text(
              'This amount will be locked in escrow until delivery is confirmed.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF475569),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF064E3B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Lock funds'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final buyerId = FirebaseAuth.instance.currentUser!.uid;

      // Create transaction document
      final txnId = await _txnService.createTransaction(
        buyerId: buyerId,
        sellerId: _sellerId!,
        amountUgx: _amountUgx,
        description: _descCtrl.text.trim(),
        deliveryType: _deliveryType,
      );

      // Lock funds — deducts from buyer wallet, holds in vault
      final result = await _txnService.lockFunds(txnId, buyerId);

      if (!mounted) return;

      if (result.success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0F6E56),
            content: Text(
              'Funds locked. New balance: UGX ${_format(result.balanceAfter ?? 0)}',
            ),
          ),
        );
      } else {
        setState(() {
          _error = result.message;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF064E3B),
        elevation: 0,
        title: const Text(
          'New transaction',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 21,
            letterSpacing: -0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF064E3B),
                      Color(0xFF1E293B),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22064E3B),
                      blurRadius: 24,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.lock_person_rounded,
                        color: Color(0xFF10B981),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Escrow Protocol',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Complete the steps to lock funds securely.',
                            style: TextStyle(
                              color: Color(0xFFD1FAE5),
                              fontSize: 12,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ── STEP 1: Find seller ──────────────────────────
              _sectionCard(
                step: '1',
                title: 'Find seller',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _sellerCtrl,
                            decoration: _inputDec(
                              'Seller email or phone number',
                              Icons.person_search_outlined,
                            ),
                            validator: (_) => _sellerId == null
                                ? 'Please find a valid seller'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _searching ? null : _lookupSeller,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF064E3B),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _searching
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Find'),
                          ),
                        ),
                      ],
                    ),

                    // Seller found card
                    if (_sellerData != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFF10B981),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle,
                                color: Color(0xFF10B981), size: 20),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _sellerData!['displayName'] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF065F46),
                                  ),
                                ),
                                Text(
                                  _sellerData!['phoneNumber'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF047857),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── STEP 2: Transaction details ──────────────────
              _sectionCard(
                step: '2',
                title: 'Transaction details',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _descCtrl,
                      maxLength: 200,
                      decoration: _inputDec(
                        'Item or service description',
                        Icons.description_outlined,
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Enter a description' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _inputDec(
                        'Amount (UGX)',
                        Icons.payments_outlined,
                      ),
                      onChanged: _onAmountChanged,
                      validator: (v) {
                        final n = int.tryParse(v?.replaceAll(',', '') ?? '');
                        if (n == null || n <= 0) return 'Enter a valid amount';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── STEP 3: Delivery type ────────────────────────
              _sectionCard(
                step: '3',
                title: 'Delivery type',
                child: Column(
                  children: [
                    _deliveryOption(
                      value: 'IN_PERSON',
                      label: 'In-person',
                      subtitle: 'Buyer and seller meet physically',
                      icon: Icons.handshake_outlined,
                    ),
                    const SizedBox(height: 10),
                    _deliveryOption(
                      value: 'LONG_DISTANCE',
                      label: 'Long-distance',
                      subtitle: 'Goods shipped via courier or bus',
                      icon: Icons.local_shipping_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Fee summary ──────────────────────────────────
              if (_amountUgx > 0)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0D0F172A),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.receipt_long_rounded,
                            size: 18,
                            color: Color(0xFF1E293B),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Protocol Ledger',
                            style: TextStyle(
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _feeRow('Amount', _amountUgx),
                      _feeRow('Service fee (1.5%)', _feeUgx),
                      const Divider(color: Color(0xFFCBD5E1), height: 20),
                      _feeRow('Total to lock', _totalUgx,
                          bold: true, color: const Color(0xFF064E3B)),
                    ],
                  ),
                ),

              // Error
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFFDA4AF)),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFF9F1239),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Lock button
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _lockFunds,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.lock_outline),
                  label: Text(
                    _loading
                        ? 'Locking funds...'
                        : 'Lock UGX ${_format(_totalUgx)} in escrow',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF064E3B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Funds will be held securely in escrow until the seller delivers and you confirm receipt.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────

  Widget _sectionCard({
    required String step,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF064E3B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    step,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: -0.4,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _deliveryOption({
    required String value,
    required String label,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _deliveryType == value;
    return GestureDetector(
      onTap: () => setState(() => _deliveryType = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color:
                  selected ? const Color(0xFF064E3B) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? const Color(0xFF064E3B)
                        : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (selected)
              const Icon(Icons.check_circle,
                  color: Color(0xFF10B981), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _feeRow(
    String label,
    int amount, {
    bool bold = false,
    Color color = const Color(0xFF2C2C2A),
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: bold ? color : const Color(0xFF475569),
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          Text(
            'UGX ${_format(amount)}',
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _confirmRow(
    String label,
    String value, {
    bool bold = false,
    Color color = const Color(0xFF2C2C2A),
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Color(0xFF64748B),
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(icon, color: const Color(0xFF0F766E)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFF064E3B), width: 1.8),
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
    );
  }

  String _format(int n) {
    return n.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }
}
