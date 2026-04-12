import '../../config/app_config.dart';
import 'payment_service.dart';
import 'mock_payment_service.dart';
import 'momo_payment_service.dart';

class PaymentFactory {
  PaymentFactory._();
  static PaymentService? _instance;

  static PaymentService create() {
    if (_instance != null) return _instance!;
    switch (AppConfig.paymentProvider) {
      case 'mock':
        _instance = MockPaymentService();
        return _instance!;
      case 'momo':
        _instance = MoMoPaymentService();
        return _instance!;
      default:
        throw Exception('Unknown paymentProvider: "${AppConfig.paymentProvider}"');
    }
  }
}
