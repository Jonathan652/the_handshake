import 'package:cloud_firestore/cloud_firestore.dart';
import 'payment_service.dart';

class MockPaymentService extends PaymentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Future<PaymentResult> lockFunds({
    required String buyerId,
    required String txnId,
    required int amountUgx,
  }) async {
    final buyerRef = _db.collection('users').doc(buyerId);
    final txnRef   = _db.collection('transactions').doc(txnId);

    try {
      await _db.runTransaction((t) async {
        final buyerSnap = await t.get(buyerRef);
        final txnSnap   = await t.get(txnRef);

        if (!buyerSnap.exists) throw Exception('Buyer not found');
        if (!txnSnap.exists)   throw Exception('Transaction not found');

        final int currentBalance = buyerSnap.data()?['walletBalance'] ?? 0;
        final String state       = txnSnap.data()?['currentState'] ?? '';

        if (state != 'CREATED') throw Exception('Cannot lock: state is $state');
        if (currentBalance < amountUgx) {
          throw Exception('Insufficient balance. Have: UGX $currentBalance, need: UGX $amountUgx');
        }

        t.update(buyerRef, {'walletBalance': currentBalance - amountUgx});
        t.update(txnRef, {
          'vaultAmount':  amountUgx,
          'currentState': 'LOCKED',
          'lockedAt':     FieldValue.serverTimestamp(),
        });
      });

      await _writeAuditLog(txnId, buyerId, 'CREATED', 'LOCKED', 'buyer_locked_funds');

      final updated    = await buyerRef.get();
      final int newBal = updated.data()?['walletBalance'] ?? 0;

      return PaymentResult(
        success: true, reference: txnId,
        message: 'UGX $amountUgx locked in escrow.', balanceAfter: newBal,
      );
    } catch (e) {
      return PaymentResult(success: false, reference: txnId, message: e.toString());
    }
  }

  @override
  Future<PaymentResult> releaseFunds({
    required String sellerId,
    required String txnId,
    required int amountUgx,
  }) async {
    final sellerRef = _db.collection('users').doc(sellerId);
    final txnRef    = _db.collection('transactions').doc(txnId);

    try {
      await _db.runTransaction((t) async {
        final sellerSnap = await t.get(sellerRef);
        final txnSnap    = await t.get(txnRef);

        if (!sellerSnap.exists) throw Exception('Seller not found');
        if (!txnSnap.exists)    throw Exception('Transaction not found');

        final int vaultAmount    = txnSnap.data()?['vaultAmount'] ?? 0;
        final String state       = txnSnap.data()?['currentState'] ?? '';
        final int currentBalance = sellerSnap.data()?['walletBalance'] ?? 0;

        const releasableStates = ['PENDING_DELIVERY','IN_TRANSIT','INSPECTION_WINDOW','DISPUTED'];
        if (!releasableStates.contains(state)) throw Exception('Cannot release: state is $state');
        if (vaultAmount < amountUgx) throw Exception('Vault mismatch');

        t.update(sellerRef, {'walletBalance': currentBalance + amountUgx});
        t.update(txnRef, {
          'vaultAmount':  0,
          'currentState': 'COMPLETED',
          'completedAt':  FieldValue.serverTimestamp(),
        });
      });

      await _writeAuditLog(txnId, sellerId, 'PENDING_DELIVERY', 'COMPLETED', 'funds_released_to_seller');

      final updated    = await sellerRef.get();
      final int newBal = updated.data()?['walletBalance'] ?? 0;

      return PaymentResult(
        success: true, reference: txnId,
        message: 'UGX $amountUgx released to seller.', balanceAfter: newBal,
      );
    } catch (e) {
      return PaymentResult(success: false, reference: txnId, message: e.toString());
    }
  }

  @override
  Future<PaymentResult> refund({
    required String buyerId,
    required String txnId,
    required int amountUgx,
  }) async {
    final buyerRef = _db.collection('users').doc(buyerId);
    final txnRef   = _db.collection('transactions').doc(txnId);

    try {
      await _db.runTransaction((t) async {
        final buyerSnap = await t.get(buyerRef);
        final txnSnap   = await t.get(txnRef);

        if (!buyerSnap.exists) throw Exception('Buyer not found');
        if (!txnSnap.exists)   throw Exception('Transaction not found');

        final int currentBalance = buyerSnap.data()?['walletBalance'] ?? 0;
        final String state       = txnSnap.data()?['currentState'] ?? '';

        const refundableStates = ['LOCKED', 'DISPUTED'];
        if (!refundableStates.contains(state)) throw Exception('Cannot refund: state is $state');

        t.update(buyerRef, {'walletBalance': currentBalance + amountUgx});
        t.update(txnRef, {
          'vaultAmount':  0,
          'currentState': 'REFUNDED',
          'completedAt':  FieldValue.serverTimestamp(),
        });
      });

      await _writeAuditLog(txnId, buyerId, 'DISPUTED', 'REFUNDED', 'funds_refunded_to_buyer');

      final updated    = await buyerRef.get();
      final int newBal = updated.data()?['walletBalance'] ?? 0;

      return PaymentResult(
        success: true, reference: txnId,
        message: 'UGX $amountUgx refunded to buyer.', balanceAfter: newBal,
      );
    } catch (e) {
      return PaymentResult(success: false, reference: txnId, message: e.toString());
    }
  }

  @override
  Future<int> getBalance(String userId) async {
    final snap = await _db.collection('users').doc(userId).get();
    if (!snap.exists) throw Exception('User not found');
    return snap.data()?['walletBalance'] ?? 0;
  }

  @override
  int calculateFee(int amountUgx) => (amountUgx * 0.015).ceil();

  Future<void> _writeAuditLog(
    String txnId, String actorUid,
    String fromState, String toState, String action,
  ) async {
    await _db.collection('audit_log').add({
      'txnId': txnId, 'actorUid': actorUid,
      'fromState': fromState, 'toState': toState,
      'action': action, 'provider': 'MOCK',
      'occurredAt': FieldValue.serverTimestamp(),
    });
  }
}
