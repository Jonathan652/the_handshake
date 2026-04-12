import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';
import 'payment/payment_factory.dart';
import 'payment/payment_service.dart';

class TransactionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final PaymentService _payment = PaymentFactory.create();

  int calculateFee(int amountUgx) => _payment.calculateFee(amountUgx);

  Future<String> createTransaction({
    required String buyerId,
    required String sellerId,
    required int amountUgx,
    required String description,
    required String deliveryType,
  }) async {
    final int feeUgx   = _payment.calculateFee(amountUgx);
    final int totalUgx = amountUgx + feeUgx;

    final docRef = await _db.collection('transactions').add({
      'buyerId':      buyerId,
      'sellerId':     sellerId,
      'deliveryType': deliveryType,
      'currentState': 'CREATED',
      'amountUgx':    amountUgx,
      'feeUgx':       feeUgx,
      'totalUgx':     totalUgx,
      'vaultAmount':  0,
      'description':  description,
      'createdAt':    FieldValue.serverTimestamp(),
      'expiresAt':    Timestamp.fromDate(
        DateTime.now().add(const Duration(minutes: 30)),
      ),
    });
    return docRef.id;
  }

  Future<PaymentResult> lockFunds(String txnId, String buyerId) async {
    final snap = await _db.collection('transactions').doc(txnId).get();
    if (!snap.exists) throw Exception('Transaction not found');
    final int totalUgx = snap.data()?['totalUgx'] ?? 0;
    return _payment.lockFunds(buyerId: buyerId, txnId: txnId, amountUgx: totalUgx);
  }

  Future<void> sellerAccept(String txnId, String sellerId) async {
    final txnRef  = _db.collection('transactions').doc(txnId);
    final txnSnap = await txnRef.get();
    if (!txnSnap.exists) throw Exception('Transaction not found');
    final data  = txnSnap.data()!;
    if (data['sellerId'] != sellerId) throw Exception('Only the seller can accept');
    if (data['currentState'] != 'LOCKED') throw Exception('Cannot accept: state is ${data['currentState']}');
    await txnRef.update({'currentState': 'PENDING_DELIVERY'});
    await _db.collection('audit_log').add({
      'txnId': txnId, 'actorUid': sellerId,
      'fromState': 'LOCKED', 'toState': 'PENDING_DELIVERY',
      'action': 'seller_accepted',
      'occurredAt': FieldValue.serverTimestamp(),
    });
  }

  Future<PaymentResult> confirmDelivery(String txnId, String buyerId) async {
    final snap = await _db.collection('transactions').doc(txnId).get();
    if (!snap.exists) throw Exception('Transaction not found');
    final data = snap.data()!;
    if (data['buyerId'] != buyerId) throw Exception('Only the buyer can confirm');
    if (data['currentState'] != 'PENDING_DELIVERY') throw Exception('Cannot confirm: state is ${data['currentState']}');
    return _payment.releaseFunds(sellerId: data['sellerId'], txnId: txnId, amountUgx: data['vaultAmount']);
  }

  Future<PaymentResult> sellerReject(String txnId, String sellerId) async {
    final snap = await _db.collection('transactions').doc(txnId).get();
    if (!snap.exists) throw Exception('Transaction not found');
    final data = snap.data()!;
    if (data['sellerId'] != sellerId) throw Exception('Only the seller can reject');
    if (data['currentState'] != 'LOCKED') throw Exception('Cannot reject: state is ${data['currentState']}');
    return _payment.refund(buyerId: data['buyerId'], txnId: txnId, amountUgx: data['vaultAmount']);
  }

  Future<int> getBalance(String userId) => _payment.getBalance(userId);

  Stream<TransactionModel?> watchTransaction(String txnId) {
    return _db.collection('transactions').doc(txnId).snapshots().map(
      (snap) => snap.exists ? TransactionModel.fromFirestore(snap.data()!, snap.id) : null,
    );
  }

  Stream<List<TransactionModel>> watchUserTransactions(String userId) {
    return _db.collection('transactions')
      .where('buyerId', isEqualTo: userId)
      .snapshots()
      .map((snap) => snap.docs
        .map((d) => TransactionModel.fromFirestore(d.data(), d.id))
        .toList());
  }
}
