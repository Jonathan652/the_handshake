class TransactionModel {
  final String txnId;
  final String buyerId;
  final String sellerId;
  final String deliveryType;
  final String currentState;
  final int amountUgx;
  final int feeUgx;
  final int totalUgx;
  final int vaultAmount;
  final String description;

  TransactionModel({
    required this.txnId,
    required this.buyerId,
    required this.sellerId,
    required this.deliveryType,
    required this.currentState,
    required this.amountUgx,
    required this.feeUgx,
    required this.totalUgx,
    required this.vaultAmount,
    required this.description,
  });

  factory TransactionModel.fromFirestore(Map<String, dynamic> data, String id) {
    return TransactionModel(
      txnId:        id,
      buyerId:      data['buyerId'] ?? '',
      sellerId:     data['sellerId'] ?? '',
      deliveryType: data['deliveryType'] ?? 'IN_PERSON',
      currentState: data['currentState'] ?? 'CREATED',
      amountUgx:    data['amountUgx'] ?? 0,
      feeUgx:       data['feeUgx'] ?? 0,
      totalUgx:     data['totalUgx'] ?? 0,
      vaultAmount:  data['vaultAmount'] ?? 0,
      description:  data['description'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'buyerId':      buyerId,
      'sellerId':     sellerId,
      'deliveryType': deliveryType,
      'currentState': currentState,
      'amountUgx':    amountUgx,
      'feeUgx':       feeUgx,
      'totalUgx':     totalUgx,
      'vaultAmount':  vaultAmount,
      'description':  description,
    };
  }
}