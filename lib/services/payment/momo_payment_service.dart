import 'payment_service.dart';

class MoMoPaymentService extends PaymentService {
  @override
  Future<PaymentResult> lockFunds({required String buyerId, required String txnId, required int amountUgx}) async {
    throw UnimplementedError('MoMoPaymentService.lockFunds not yet implemented');
  }
  @override
  Future<PaymentResult> releaseFunds({required String sellerId, required String txnId, required int amountUgx}) async {
    throw UnimplementedError('MoMoPaymentService.releaseFunds not yet implemented');
  }
  @override
  Future<PaymentResult> refund({required String buyerId, required String txnId, required int amountUgx}) async {
    throw UnimplementedError('MoMoPaymentService.refund not yet implemented');
  }
  @override
  Future<int> getBalance(String userId) async {
    throw UnimplementedError('MoMoPaymentService.getBalance not yet implemented');
  }
  @override
  int calculateFee(int amountUgx) {
    if (amountUgx <= 2500)  return 250;
    if (amountUgx <= 5000)  return 350;
    if (amountUgx <= 15000) return 600;
    if (amountUgx <= 45000) return 900;
    return (amountUgx * 0.01).ceil();
  }
}
