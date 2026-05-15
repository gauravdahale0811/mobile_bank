import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/loan.dart';
import '../models/due_payment.dart';
import '../providers/auth_provider.dart' as app_auth;
import '../services/firestore_service.dart';
import '../widgets/loan_card.dart';
import 'add_loan_screen.dart';
import 'today_collection_screen.dart';
import 'settings_screen.dart';
import 'loan_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  LoanStatus? _filter;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('MicroFinance'),
        centerTitle: true,
        actions: [
          PopupMenuButton<LoanStatus?>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
            onSelected: (val) => setState(() => _filter = val),
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('All')),
              const PopupMenuItem(
                  value: LoanStatus.active, child: Text('Active')),
              const PopupMenuItem(
                  value: LoanStatus.completed, child: Text('Completed')),
              const PopupMenuItem(
                  value: LoanStatus.defaulted, child: Text('Defaulted')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search bar ─────────────────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SearchBar(
              hintText: 'Search by name or phone…',
              leading: const Icon(Icons.search),
              onChanged: (v) => setState(() => _search = v.trim()),
              padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 12)),
              elevation: const WidgetStatePropertyAll(1),
            ),
          ),

          // ── Weekly alert banner ────────────────────────────────────────────
          _WeeklyAlertBanner(service: service),

          // ── Loan list ──────────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<Loan>>(
              stream: service.loansStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                var loans = snapshot.data ?? [];

                if (_filter != null) {
                  loans = loans
                      .where((l) => l.status == _filter)
                      .toList();
                }

                if (_search.isNotEmpty) {
                  final q = _search.toLowerCase();
                  loans = loans
                      .where((l) =>
                          l.borrowerName.toLowerCase().contains(q) ||
                          l.borrowerPhone.contains(q))
                      .toList();
                }

                if (loans.isEmpty) {
                  return _EmptyState(
                      filtered: _filter != null || _search.isNotEmpty);
                }

                return Column(
                  children: [
                    _SummaryBar(loans: loans),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: loans.length,
                        itemBuilder: (context, i) {
                          final loan = loans[i];
                          return LoanCard(
                            loan: loan,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    LoanDetailScreen(loan: loan),
                              ),
                            ),
                            onDelete: () =>
                                _confirmDelete(context, service, loan),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddLoanScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New Loan'),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    FirestoreService service,
    Loan loan,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Loan'),
        content: Text(
          'Delete loan for ${loan.borrowerName}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await service.deleteLoan(loan.id);
    }
  }
}

// ── Weekly alert banner ───────────────────────────────────────────────────────

class _WeeklyAlertBanner extends StatefulWidget {
  final FirestoreService service;

  const _WeeklyAlertBanner({required this.service});

  @override
  State<_WeeklyAlertBanner> createState() => _WeeklyAlertBannerState();
}

class _WeeklyAlertBannerState extends State<_WeeklyAlertBanner> {
  late Future<List<DuePayment>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.service.weeksDuePayments();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DuePayment>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final dues = snapshot.data!;
        final overdueCount = dues.where((d) => d.hasLateFine).length;
        final todayCount =
            dues.where((d) => !d.hasLateFine && _isDueToday(d)).length;
        final weekCount = dues.length;
        final hasUrgent = overdueCount > 0 || todayCount > 0;

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const TodayCollectionScreen()),
          ).then((_) => setState(
                () => _future = widget.service.weeksDuePayments(),
              )),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: hasUrgent
                  ? Colors.red.withValues(alpha: 0.1)
                  : Colors.orange.withValues(alpha: 0.1),
              border: Border.all(
                color: hasUrgent ? Colors.red : Colors.orange,
                width: 1.2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  hasUrgent
                      ? Icons.notification_important
                      : Icons.calendar_today,
                  color: hasUrgent ? Colors.red : Colors.orange,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasUrgent
                            ? _urgentText(overdueCount, todayCount)
                            : '$weekCount EMI${weekCount == 1 ? '' : 's'} due this week',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: hasUrgent ? Colors.red : Colors.orange,
                        ),
                      ),
                      Text(
                        'Tap to view collection sheet',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: hasUrgent ? Colors.red : Colors.orange,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _urgentText(int overdue, int today) {
    final parts = <String>[];
    if (overdue > 0) parts.add('$overdue overdue');
    if (today > 0) parts.add('$today due today');
    return parts.join(' · ');
  }

  bool _isDueToday(DuePayment d) {
    final now = DateTime.now();
    final due = d.payment.dueDate;
    return due.year == now.year &&
        due.month == now.month &&
        due.day == now.day;
  }
}

// ── Summary bar ───────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final List<Loan> loans;

  const _SummaryBar({required this.loans});

  @override
  Widget build(BuildContext context) {
    final totalPrincipal =
        loans.fold(0.0, (sum, l) => sum + l.principal);
    final active =
        loans.where((l) => l.status == LoanStatus.active).length;

    return Container(
      color: Theme.of(context).colorScheme.primaryContainer,
      padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(label: 'Total Loans', value: '${loans.length}'),
          _Stat(label: 'Active', value: '$active'),
          _Stat(
            label: 'Capital Out',
            value: '₹${totalPrincipal.toStringAsFixed(0)}',
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool filtered;

  const _EmptyState({required this.filtered});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.account_balance_wallet_outlined,
              size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            filtered
                ? 'No loans match your search.'
                : 'No loans yet.\nTap + to add one.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
