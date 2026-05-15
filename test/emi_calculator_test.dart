import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_bank/models/loan.dart';
import 'package:mobile_bank/utils/emi_calculator.dart';

void main() {
  group('EmiCalculator', () {
    test('weekly 2 months → 8 EMIs', () {
      expect(
        EmiCalculator.numberOfEmis(2, PaymentFrequency.weekly),
        8,
      );
    });

    test('biweekly 2 months → 4 EMIs', () {
      expect(
        EmiCalculator.numberOfEmis(2, PaymentFrequency.biweekly),
        4,
      );
    });

    test('monthly 3 months → 3 EMIs', () {
      expect(
        EmiCalculator.numberOfEmis(3, PaymentFrequency.monthly),
        3,
      );
    });

    test('EMI amount: 6000 / 8 weeks = 750', () {
      final emi = EmiCalculator.emiAmount(6000, 2, PaymentFrequency.weekly);
      expect(emi, closeTo(750.0, 0.001));
    });

    test('interest = totalRepayment - principal', () {
      expect(EmiCalculator.interest(5000, 6000), closeTo(1000.0, 0.001));
    });

    test('emiDueDates generates correct count and interval', () {
      final start = DateTime(2024, 1, 1);
      final dates = EmiCalculator.emiDueDates(start, 2, PaymentFrequency.weekly);
      expect(dates.length, 8);
      // First EMI 7 days after disbursement
      expect(dates.first, DateTime(2024, 1, 8));
      // Last EMI 56 days after disbursement
      expect(dates.last, DateTime(2024, 2, 26));
    });

    test('Loan model computes emiAmount correctly', () {
      final loan = Loan(
        id: 'test',
        borrowerName: 'Ravi',
        borrowerPhone: '9876543210',
        principal: 5000,
        totalRepayment: 6000,
        durationMonths: 2,
        frequency: PaymentFrequency.weekly,
        disbursementDate: DateTime(2024, 1, 1),
      );
      expect(loan.emiAmount, closeTo(750.0, 0.001));
      expect(loan.numberOfEmis, 8);
      expect(loan.interest, closeTo(1000.0, 0.001));
    });
  });
}
