import 'package:cloud_firestore/cloud_firestore.dart';

const double lateFineAmount = 100.0;

enum PaymentStatus { pending, paid, waived }

extension PaymentStatusExt on PaymentStatus {
  String get label {
    switch (this) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.waived:
        return 'Waived';
    }
  }

  static PaymentStatus fromString(String value) {
    return PaymentStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PaymentStatus.pending,
    );
  }
}

class EmiPayment {
  final String id;
  final String loanId;

  /// 1-based EMI number (EMI #1, #2, …)
  final int emiNumber;

  final double amount;

  /// ₹100 fine added when EMI is collected after the due date.
  final double fineAmount;

  final DateTime dueDate;
  final DateTime? paidDate;
  final PaymentStatus status;
  final String? remarks;

  EmiPayment({
    required this.id,
    required this.loanId,
    required this.emiNumber,
    required this.amount,
    required this.dueDate,
    this.fineAmount = 0,
    this.paidDate,
    this.status = PaymentStatus.pending,
    this.remarks,
  });

  /// Total amount collected = EMI + late fine (if any).
  double get totalCollected => amount + fineAmount;

  bool get isOverdue =>
      status == PaymentStatus.pending &&
      DateTime.now().isAfter(
        DateTime(dueDate.year, dueDate.month, dueDate.day + 1),
      );

  Map<String, dynamic> toFirestore() {
    return {
      'loanId': loanId,
      'emiNumber': emiNumber,
      'amount': amount,
      'fineAmount': fineAmount,
      'dueDate': Timestamp.fromDate(dueDate),
      'paidDate': paidDate != null ? Timestamp.fromDate(paidDate!) : null,
      'status': status.name,
      'remarks': remarks,
    };
  }

  factory EmiPayment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EmiPayment(
      id: doc.id,
      loanId: data['loanId'] as String,
      emiNumber: data['emiNumber'] as int,
      amount: (data['amount'] as num).toDouble(),
      fineAmount: (data['fineAmount'] as num? ?? 0).toDouble(),
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      paidDate: data['paidDate'] != null
          ? (data['paidDate'] as Timestamp).toDate()
          : null,
      status: PaymentStatusExt.fromString(data['status'] as String),
      remarks: data['remarks'] as String?,
    );
  }
}
