abstract class PaymentService {
  Future<PaymentResult> lockFunds({
    required String buyerId,
    required String txnId,
    required int amountUgx,
  });

  Future<PaymentResult> releaseFunds({
    required String sellerId,
    required String txnId,
    required int amountUgx,
  });

  Future<PaymentResult> refund({
    required String buyerId,
    required String txnId,
    required int amountUgx,
  });

  Future<int> getBalance(String userId);
  int calculateFee(int amountUgx);
}

class PaymentResult {
  final bool success;
  final String reference;
  final String message;
  final int? balanceAfter;

  PaymentResult({
    required this.success,
    required this.reference,
    required this.message,
    this.balanceAfter,
  });
}