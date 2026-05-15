import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/due_payment.dart';
import '../models/emi_payment.dart';
import '../services/firestore_service.dart';

class TodayCollectionScreen extends StatefulWidget {
  const TodayCollectionScreen({super.key});

  @override
  State<TodayCollectionScreen> createState() => _TodayCollectionScreenState();
}

class _TodayCollectionScreenState extends State<TodayCollectionScreen> {
  int _refreshKey = 0;

  void _refresh() => setState(() => _refreshKey++);

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirestoreService>();
    final today = DateFormat('dd MMM yyyy').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Collection"),
        subtitle: Text(today, style: const TextStyle(fontSize: 12)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<List<DuePayment>>(
        key: ValueKey(_refreshKey),
        future: service.todaysDuePayments(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final dues = snapshot.data ?? [];

          if (dues.isEmpty) {
            return _EmptyCollection();
          }

          final overdue = dues.where((d) => d.hasLateFine).toList();
          final dueToday = dues.where((d) => !d.hasLateFine).toList();
          final totalToCollect =
              dues.fold(0.0, (sum, d) => sum + d.totalIfPaidNow);

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _SummaryHeader(
                    totalCount: dues.length,
                    overdueCount: overdue.length,
                    totalToCollect: totalToCollect,
                  ),
                ),
                if (overdue.isNotEmpty) ...[
                  _sectionHeader(context, 'OVERDUE', Colors.red),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _DuePaymentTile(
                        due: overdue[i],
                        onCollect: () =>
                            _collect(context, service, overdue[i]),
                        onWaive: () =>
                            _waive(context, service, overdue[i]),
                      ),
                      childCount: overdue.length,
                    ),
                  ),
                ],
                if (dueToday.isNotEmpty) ...[
                  _sectionHeader(context, 'DUE TODAY', Colors.orange),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _DuePaymentTile(
                        due: dueToday[i],
                        onCollect: () =>
                            _collect(context, service, dueToday[i]),
                        onWaive: () =>
                            _waive(context, service, dueToday[i]),
                      ),
                      childCount: dueToday.length,
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          );
        },
      ),
    );
  }

  SliverToBoxAdapter _sectionHeader(
      BuildContext context, String label, Color color) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: color.withValues(alpha: 0.1),
        child: Row(
          children: [
            Container(width: 4, height: 16, color: color,
                margin: const EdgeInsets.only(right: 8)),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _collect(
    BuildContext context,
    FirestoreService service,
    DuePayment due,
  ) async {
    final remarksCtrl = TextEditingController();
    final fine = due.fineIfPaidNow;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Collect EMI #${due.payment.emiNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Borrower: ${due.loan.borrowerName}'),
            const SizedBox(height: 8),
            _amountRow('EMI amount', due.payment.amount),
            if (fine > 0)
              _amountRow('Late fine', fine, color: Colors.red),
            const Divider(),
            _amountRow('Total to collect', due.totalIfPaidNow,
                bold: true),
            const SizedBox(height: 12),
            TextField(
              controller: remarksCtrl,
              decoration: const InputDecoration(
                labelText: 'Remarks (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Collect'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await service.markEmiPaid(
        due.loan.id,
        due.payment,
        remarks: remarksCtrl.text.trim().isEmpty
            ? null
            : remarksCtrl.text.trim(),
      );
      _refresh();
    }
  }

  Future<void> _waive(
    BuildContext context,
    FirestoreService service,
    DuePayment due,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Waive EMI #${due.payment.emiNumber}?'),
        content: Text(
          'Waiving means ₹${due.payment.amount.toStringAsFixed(0)} '
          'will not be collected from ${due.loan.borrowerName}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Waive'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await service.markEmiWaived(due.loan.id, due.payment.id);
      _refresh();
    }
  }

  Widget _amountRow(String label, double amount,
      {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              color: color,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final int totalCount;
  final int overdueCount;
  final double totalToCollect;

  const _SummaryHeader({
    required this.totalCount,
    required this.overdueCount,
    required this.totalToCollect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat('Total Due', '$totalCount EMIs'),
          Container(width: 1, height: 40, color: cs.outline),
          _Stat(
            'Overdue',
            '$overdueCount EMIs',
            color: overdueCount > 0 ? Colors.red : null,
          ),
          Container(width: 1, height: 40, color: cs.outline),
          _Stat(
            'To Collect',
            '₹${totalToCollect.toStringAsFixed(0)}',
            bold: true,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool bold;

  const _Stat(this.label, this.value, {this.color, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _DuePaymentTile extends StatelessWidget {
  final DuePayment due;
  final VoidCallback onCollect;
  final VoidCallback onWaive;

  const _DuePaymentTile({
    required this.due,
    required this.onCollect,
    required this.onWaive,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM');
    final cs = Theme.of(context).colorScheme;
    final hasFine = due.hasLateFine;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              backgroundColor:
                  hasFine ? Colors.red.withValues(alpha: 0.15) : cs.primaryContainer,
              child: Text(
                due.loan.borrowerName[0].toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: hasFine ? Colors.red : cs.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    due.loan.borrowerName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    due.loan.borrowerPhone,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'EMI #${due.payment.emiNumber}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Due: ${fmt.format(due.payment.dueDate)}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: hasFine ? Colors.red : null,
                            ),
                      ),
                    ],
                  ),
                  // Fine indicator
                  if (hasFine)
                    Text(
                      '+₹${lateFineAmount.toStringAsFixed(0)} late fine',
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),

            // Amount + Collect button
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${due.totalIfPaidNow.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (hasFine)
                  Text(
                    '₹${due.payment.amount.toStringAsFixed(0)} + fine',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    TextButton(
                      onPressed: onWaive,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(40, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Waive',
                          style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 6),
                    FilledButton(
                      onPressed: onCollect,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Collect',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCollection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline,
              size: 72,
              color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'All clear!\nNo EMIs due today.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
