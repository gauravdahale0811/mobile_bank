import '../models/loan.dart';

class EmiCalculator {
  /// Total EMI count based on duration and payment frequency.
  /// Example: 2 months weekly = 8 EMIs
  static int numberOfEmis(int durationMonths, PaymentFrequency frequency) {
    switch (frequency) {
      case PaymentFrequency.weekly:
        return durationMonths * 4;
      case PaymentFrequency.biweekly:
        return durationMonths * 2;
      case PaymentFrequency.monthly:
        return durationMonths;
    }
  }

  /// EMI amount = totalRepayment / numberOfEmis
  /// e.g. 6000 / 8 = 750 per week
  static double emiAmount(double totalRepayment, int durationMonths, PaymentFrequency frequency) {
    final count = numberOfEmis(durationMonths, frequency);
    return totalRepayment / count;
  }

  /// Interest = totalRepayment - principal
  static double interest(double principal, double totalRepayment) {
    return totalRepayment - principal;
  }

  /// Generate due dates for each EMI starting from disbursementDate
  static List<DateTime> emiDueDates(
    DateTime disbursementDate,
    int durationMonths,
    PaymentFrequency frequency,
  ) {
    final count = numberOfEmis(durationMonths, frequency);
    final interval = _intervalDays(frequency);
    return List.generate(count, (i) {
      return disbursementDate.add(Duration(days: interval * (i + 1)));
    });
  }

  static int _intervalDays(PaymentFrequency frequency) {
    switch (frequency) {
      case PaymentFrequency.weekly:
        return 7;
      case PaymentFrequency.biweekly:
        return 14;
      case PaymentFrequency.monthly:
        return 30;
    }
  }
}
