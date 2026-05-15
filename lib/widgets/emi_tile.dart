import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/emi_payment.dart';

class EmiTile extends StatelessWidget {
  final EmiPayment payment;
  final VoidCallback onMarkPaid;
  final VoidCallback onMarkWaived;

  const EmiTile({
    super.key,
    required this.payment,
    required this.onMarkPaid,
    required this.onMarkWaived,
  });

  Color _statusColor() {
    switch (payment.status) {
      case PaymentStatus.paid:
        return Colors.green;
      case PaymentStatus.waived:
        return Colors.blue;
      case PaymentStatus.pending:
        return payment.isOverdue ? Colors.red : Colors.grey;
    }
  }

  IconData _statusIcon() {
    switch (payment.status) {
      case PaymentStatus.paid:
        return Icons.check_circle;
      case PaymentStatus.waived:
        return Icons.remove_circle;
      case PaymentStatus.pending:
        return payment.isOverdue
            ? Icons.error
            : Icons.radio_button_unchecked;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');
    final isPending = payment.status == PaymentStatus.pending;
    final hasFine = payment.fineAmount > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status icon
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(_statusIcon(), color: _statusColor(), size: 22),
            ),
            const SizedBox(width: 12),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'EMI #${payment.emiNumber}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      // Amount column
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (hasFine) ...[
                            Text(
                              '₹${payment.totalCollected.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                            Text(
                              '₹${payment.amount.toStringAsFixed(0)} + ₹${payment.fineAmount.toStringAsFixed(0)} fine',
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.red),
                            ),
                          ] else
                            Text(
                              '₹${payment.amount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Due date / paid date
                  Row(
                    children: [
                      Text(
                        'Due: ${fmt.format(payment.dueDate)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: payment.isOverdue ? Colors.red : null,
                            ),
                      ),
                      if (payment.paidDate != null) ...[
                        const SizedBox(width: 10),
                        Text(
                          'Paid: ${fmt.format(payment.paidDate!)}',
                          style: const TextStyle(
                              color: Colors.green, fontSize: 12),
                        ),
                      ],
                    ],
                  ),

                  if (payment.isOverdue && isPending)
                    const Text(
                      'OVERDUE — ₹100 fine on collection',
                      style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 11),
                    ),

                  if (payment.remarks != null && payment.remarks!.isNotEmpty)
                    Text(
                      payment.remarks!,
                      style: const TextStyle(
                          fontStyle: FontStyle.italic, fontSize: 11),
                    ),
                ],
              ),
            ),

            // Action menu (pending only)
            if (isPending)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (v) {
                  if (v == 'paid') onMarkPaid();
                  if (v == 'waived') onMarkWaived();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: 'paid', child: Text('Collect payment')),
                  PopupMenuItem(
                      value: 'waived', child: Text('Mark as Waived')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
