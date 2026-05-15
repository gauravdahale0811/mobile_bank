import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/emi_calculator.dart';

enum PaymentFrequency { weekly, biweekly, monthly }

extension PaymentFrequencyExt on PaymentFrequency {
  String get label {
    switch (this) {
      case PaymentFrequency.weekly:
        return 'Weekly';
      case PaymentFrequency.biweekly:
        return 'Bi-weekly';
      case PaymentFrequency.monthly:
        return 'Monthly';
    }
  }

  String get firestoreValue {
    return name;
  }

  static PaymentFrequency fromString(String value) {
    return PaymentFrequency.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PaymentFrequency.weekly,
    );
  }
}

enum LoanStatus { active, completed, defaulted }

extension LoanStatusExt on LoanStatus {
  String get label {
    switch (this) {
      case LoanStatus.active:
        return 'Active';
      case LoanStatus.completed:
        return 'Completed';
      case LoanStatus.defaulted:
        return 'Defaulted';
    }
  }

  static LoanStatus fromString(String value) {
    return LoanStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => LoanStatus.active,
    );
  }
}

class Loan {
  final String id;
  final String borrowerName;
  final String borrowerPhone;

  /// The principal amount lent (e.g. 5000)
  final double principal;

  /// Total amount to be repaid including interest (e.g. 6000)
  final double totalRepayment;

  final int durationMonths;
  final PaymentFrequency frequency;
  final DateTime disbursementDate;
  final LoanStatus status;
  final String? notes;

  Loan({
    required this.id,
    required this.borrowerName,
    required this.borrowerPhone,
    required this.principal,
    required this.totalRepayment,
    required this.durationMonths,
    required this.frequency,
    required this.disbursementDate,
    this.status = LoanStatus.active,
    this.notes,
  });

  /// Interest charged on this loan
  double get interest => EmiCalculator.interest(principal, totalRepayment);

  /// Number of EMI installments
  int get numberOfEmis => EmiCalculator.numberOfEmis(durationMonths, frequency);

  /// Amount per EMI installment
  double get emiAmount => EmiCalculator.emiAmount(totalRepayment, durationMonths, frequency);

  /// All scheduled due dates
  List<DateTime> get emiDueDates =>
      EmiCalculator.emiDueDates(disbursementDate, durationMonths, frequency);

  Map<String, dynamic> toFirestore() {
    return {
      'borrowerName': borrowerName,
      'borrowerPhone': borrowerPhone,
      'principal': principal,
      'totalRepayment': totalRepayment,
      'durationMonths': durationMonths,
      'frequency': frequency.firestoreValue,
      'disbursementDate': Timestamp.fromDate(disbursementDate),
      'status': status.name,
      'notes': notes,
    };
  }

  factory Loan.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Loan(
      id: doc.id,
      borrowerName: data['borrowerName'] as String,
      borrowerPhone: data['borrowerPhone'] as String,
      principal: (data['principal'] as num).toDouble(),
      totalRepayment: (data['totalRepayment'] as num).toDouble(),
      durationMonths: data['durationMonths'] as int,
      frequency: PaymentFrequencyExt.fromString(data['frequency'] as String),
      disbursementDate: (data['disbursementDate'] as Timestamp).toDate(),
      status: LoanStatusExt.fromString(data['status'] as String),
      notes: data['notes'] as String?,
    );
  }

  Loan copyWith({LoanStatus? status}) {
    return Loan(
      id: id,
      borrowerName: borrowerName,
      borrowerPhone: borrowerPhone,
      principal: principal,
      totalRepayment: totalRepayment,
      durationMonths: durationMonths,
      frequency: frequency,
      disbursementDate: disbursementDate,
      status: status ?? this.status,
      notes: notes,
    );
  }
}
