import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import '../../data/local/database.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/auth/authorization_service.dart';
import '../../core/auth/permission.dart';

class CustomerDebtScreen extends StatefulWidget {
  const CustomerDebtScreen({super.key});

  @override
  State<CustomerDebtScreen> createState() => _CustomerDebtScreenState();
}

class _CustomerDebtScreenState extends State<CustomerDebtScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddCustomerModal(BuildContext context) {
    final authz = context.read<AuthorizationService>();
    if (!authz.can(Permission.customersManage)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Accès restreint: permission insuffisante pour gérer les clients.')),
      );
      return;
    }

    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Nouveau Client',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Nom du Client *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Téléphone (WhatsApp / SMS)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Adresse / Ville', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Notes / Observations', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Le nom du client est obligatoire.')),
                      );
                      return;
                    }
                    final db = context.read<AppDatabase>();
                    final storeId = context.read<AuthProvider>().session?.currentStoreId ?? '';
                    const uuid = Uuid();

                    await db.into(db.customers).insert(
                          CustomersCompanion.insert(
                            id: uuid.v4(),
                            storeId: storeId,
                            name: name,
                            phone: Value(phoneController.text.trim()),
                            address: Value(addressController.text.trim()),
                            notes: Value(notesController.text.trim()),
                            synced: const Value(false),
                          ),
                        );

                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Client "$name" enregistré avec succès.')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Enregistrer Client'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openPaymentModal(
    BuildContext context,
    Customer customer, {
    CustomerDebt? specificDebt,
    double? totalRemainingDebt,
  }) {
    final authz = context.read<AuthorizationService>();
    if (!authz.can(Permission.customersManage)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Accès restreint: permission insuffisante pour enregistrer un paiement.')),
      );
      return;
    }

    final maxDebt = specificDebt != null ? specificDebt.remainingAmount : (totalRemainingDebt ?? 0.0);
    if (maxDebt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune dette en cours à régler pour ce client.')),
      );
      return;
    }

    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String selectedPaymentMethod = 'cash';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Enregistrer un Paiement',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Client: ${customer.name}${specificDebt != null ? " • Dette #${specificDebt.id.substring(0, 8)}" : ""}',
                      style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Solde restant dû:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                          Text(
                            '${maxDebt.toStringAsFixed(3)} TND',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red.shade900),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Montant versé (TND) *',
                        hintText: 'Max: ${maxDebt.toStringAsFixed(3)}',
                        suffixText: 'TND',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedPaymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Mode de paiement',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('Espèces')),
                        DropdownMenuItem(value: 'check', child: Text('Chèque')),
                        DropdownMenuItem(value: 'credit', child: Text('Ardoise / Autre')),
                        DropdownMenuItem(value: 'transfer', child: Text('Virement bancaire')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedPaymentMethod = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: 'Note / Réf chèque (facultatif)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        final rawText = amountController.text.replaceAll(',', '.').trim();
                        final amount = double.tryParse(rawText);

                        if (amount == null || amount <= 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Veuillez saisir un montant supérieur à 0.')),
                          );
                          return;
                        }

                        if (amount > maxDebt + 0.0001) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('Le montant ne peut pas dépasser la dette (${maxDebt.toStringAsFixed(3)} TND).'),
                              backgroundColor: Colors.red.shade700,
                            ),
                          );
                          return;
                        }

                        final db = context.read<AppDatabase>();
                        final storeId = context.read<AuthProvider>().session?.currentStoreId ?? '';
                        const uuid = Uuid();
                        final now = DateTime.now();
                        final note = noteController.text.trim();

                        await db.transaction(() async {
                          if (specificDebt != null) {
                            final newRemaining = (specificDebt.remainingAmount - amount).clamp(0.0, double.infinity);
                            final newPaid = specificDebt.paidAmount + amount;
                            final newStatus = newRemaining <= 0.0001 ? 'PAID' : 'PARTIAL';

                            await db.into(db.debtPayments).insert(
                                  DebtPaymentsCompanion.insert(
                                    id: uuid.v4(),
                                    storeId: storeId,
                                    debtId: specificDebt.id,
                                    customerId: customer.id,
                                    amount: amount,
                                    paymentMethod: Value(selectedPaymentMethod),
                                    note: Value(note),
                                    createdAt: Value(now),
                                    synced: const Value(false),
                                  ),
                                );

                            await (db.update(db.customerDebts)..where((d) => d.id.equals(specificDebt.id))).write(
                              CustomerDebtsCompanion(
                                paidAmount: Value(newPaid),
                                remainingAmount: Value(newRemaining),
                                status: Value(newStatus),
                                synced: const Value(false),
                              ),
                            );
                          } else {
                            // FIFO allocation across all active unpaid debts
                            final activeDebts = await (db.select(db.customerDebts)
                                  ..where((d) =>
                                      d.customerId.equals(customer.id) &
                                      d.storeId.equals(storeId) &
                                      d.remainingAmount.isBiggerThanValue(0))
                                  ..orderBy([(d) => OrderingTerm.asc(d.createdAt)]))
                                .get();

                            double remainingPayment = amount;
                            for (final debt in activeDebts) {
                              if (remainingPayment <= 0.0001) break;
                              final toPay = remainingPayment < debt.remainingAmount ? remainingPayment : debt.remainingAmount;
                              final newRemaining = (debt.remainingAmount - toPay).clamp(0.0, double.infinity);
                              final newPaid = debt.paidAmount + toPay;
                              final newStatus = newRemaining <= 0.0001 ? 'PAID' : 'PARTIAL';

                              await db.into(db.debtPayments).insert(
                                    DebtPaymentsCompanion.insert(
                                      id: uuid.v4(),
                                      storeId: storeId,
                                      debtId: debt.id,
                                      customerId: customer.id,
                                      amount: toPay,
                                      paymentMethod: Value(selectedPaymentMethod),
                                      note: Value(note),
                                      createdAt: Value(now),
                                      synced: const Value(false),
                                    ),
                                  );

                              await (db.update(db.customerDebts)..where((d) => d.id.equals(debt.id))).write(
                                CustomerDebtsCompanion(
                                  paidAmount: Value(newPaid),
                                  remainingAmount: Value(newRemaining),
                                  status: Value(newStatus),
                                  synced: const Value(false),
                                ),
                              );

                              remainingPayment -= toPay;
                            }
                          }
                        });

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Paiement de ${amount.toStringAsFixed(3)} TND enregistré pour ${customer.name}.'),
                              backgroundColor: Colors.green.shade700,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Valider le Paiement'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCustomerDebtDetails(BuildContext context, Customer customer) {
    final db = context.read<AppDatabase>();
    final storeId = context.read<AuthProvider>().session?.currentStoreId ?? '';
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DefaultTabController(
          length: 2,
          child: Container(
            height: MediaQuery.of(ctx).size.height * 0.85,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.amber.shade100,
                      foregroundColor: Colors.amber.shade900,
                      child: Text(customer.name.substring(0, 1).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          if (customer.phone.isNotEmpty) Text('Tél: ${customer.phone}', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                StreamBuilder<List<CustomerDebt>>(
                  stream: (db.select(db.customerDebts)
                        ..where((d) => d.customerId.equals(customer.id) & d.storeId.equals(storeId))
                        ..orderBy([(d) => OrderingTerm.desc(d.createdAt)]))
                      .watch(),
                  builder: (context, snapshot) {
                    final debts = snapshot.data ?? [];
                    final totalDebt = debts.fold(0.0, (sum, d) => sum + d.totalAmount);
                    final totalPaid = debts.fold(0.0, (sum, d) => sum + d.paidAmount);
                    final totalRemaining = debts.fold(0.0, (sum, d) => sum + d.remainingAmount);

                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _SummaryBox(
                                label: 'Total dette',
                                value: '${totalDebt.toStringAsFixed(3)} TND',
                                color: Colors.blueGrey,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _SummaryBox(
                                label: 'Total payé',
                                value: '${totalPaid.toStringAsFixed(3)} TND',
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _SummaryBox(
                                label: 'Restant dû',
                                value: '${totalRemaining.toStringAsFixed(3)} TND',
                                color: totalRemaining > 0 ? Colors.red : Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (totalRemaining > 0)
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              icon: const Icon(Icons.payments_outlined),
                              label: const Text('Enregistrer un paiement'),
                              style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _openPaymentModal(context, customer, totalRemainingDebt: totalRemaining);
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                const TabBar(
                  tabs: [
                    Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Dettes'),
                    Tab(icon: Icon(Icons.history), text: 'Historique des paiements'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Debts Tab
                      StreamBuilder<List<CustomerDebt>>(
                        stream: (db.select(db.customerDebts)
                              ..where((d) => d.customerId.equals(customer.id) & d.storeId.equals(storeId))
                              ..orderBy([(d) => OrderingTerm.desc(d.createdAt)]))
                            .watch(),
                        builder: (context, snapshot) {
                          final debts = snapshot.data ?? [];
                          if (debts.isEmpty) {
                            return const Center(child: Text('Aucune dette enregistrée.'));
                          }
                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: debts.length,
                            itemBuilder: (ctx, i) {
                              final d = debts[i];
                              final statusColor = d.status == 'PAID'
                                  ? Colors.green
                                  : (d.status == 'PARTIAL' ? Colors.orange : Colors.red);

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            d.saleId.isNotEmpty ? 'Vente #${d.saleId.substring(0, 8)}' : 'Dette #${d.id.substring(0, 8)}',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              d.status == 'PAID' ? 'RÉGLÉ' : (d.status == 'PARTIAL' ? 'PARTIEL' : 'NON PAYÉ'),
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: statusColor),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Date: ${dateFormat.format(d.createdAt)}',
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                      ),
                                      if (d.dueDate != null)
                                        Text(
                                          'Échéance: ${dateFormat.format(d.dueDate!)}',
                                          style: TextStyle(color: Colors.amber.shade900, fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Total: ${d.totalAmount.toStringAsFixed(3)} TND', style: const TextStyle(fontSize: 13)),
                                          Text('Payé: ${d.paidAmount.toStringAsFixed(3)} TND', style: TextStyle(fontSize: 13, color: Colors.green.shade800)),
                                          Text('Reste: ${d.remainingAmount.toStringAsFixed(3)} TND', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red.shade800)),
                                        ],
                                      ),
                                      if (d.remainingAmount > 0) ...[
                                        const SizedBox(height: 8),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton.icon(
                                            icon: const Icon(Icons.payment, size: 16),
                                            label: const Text('Régler cette dette'),
                                            onPressed: () {
                                              Navigator.pop(ctx);
                                              _openPaymentModal(context, customer, specificDebt: d);
                                            },
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),

                      // Payments Tab
                      StreamBuilder<List<DebtPayment>>(
                        stream: (db.select(db.debtPayments)
                              ..where((p) => p.customerId.equals(customer.id) & p.storeId.equals(storeId))
                              ..orderBy([(p) => OrderingTerm.desc(p.createdAt)]))
                            .watch(),
                        builder: (context, snapshot) {
                          final payments = snapshot.data ?? [];
                          if (payments.isEmpty) {
                            return const Center(child: Text('Aucun paiement enregistré pour ce client.'));
                          }
                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: payments.length,
                            itemBuilder: (ctx, i) {
                              final p = payments[i];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.green.shade100,
                                    child: const Icon(Icons.arrow_downward, color: Colors.green, size: 20),
                                  ),
                                  title: Text(
                                    '+${p.amount.toStringAsFixed(3)} TND',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${dateFormat.format(p.createdAt)} • ${p.paymentMethod.toUpperCase()}'),
                                      if (p.note.isNotEmpty) Text('Note: ${p.note}', style: const TextStyle(fontStyle: FontStyle.italic)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    final storeId = context.watch<AuthProvider>().session?.currentStoreId ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients & Ardoises'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddCustomerModal(context),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Nouveau Client'),
        backgroundColor: Colors.amber.shade700,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher par nom ou numéro…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Customer>>(
              stream: (db.select(db.customers)
                    ..where((c) => c.storeId.equals(storeId))
                    ..orderBy([(c) => OrderingTerm.asc(c.name)]))
                  .watch(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allCustomers = snapshot.data ?? [];
                final customers = _searchQuery.isEmpty
                    ? allCustomers
                    : allCustomers
                        .where((c) =>
                            c.name.toLowerCase().contains(_searchQuery) ||
                            c.phone.toLowerCase().contains(_searchQuery))
                        .toList();

                if (customers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? 'Aucun client enregistré.' : 'Aucun résultat trouvé.',
                          style: const TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: customers.length,
                  itemBuilder: (context, index) {
                    final c = customers[index];

                    return FutureBuilder<List<CustomerDebt>>(
                      future: (db.select(db.customerDebts)..where((d) => d.customerId.equals(c.id))).get(),
                      builder: (context, debtSnapshot) {
                        final debts = debtSnapshot.data ?? [];
                        final totalRemaining = debts.fold(0.0, (sum, d) => sum + d.remainingAmount);
                        final activeDebtsCount = debts.where((d) => d.remainingAmount > 0).length;

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _showCustomerDebtDetails(context, c),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: totalRemaining > 0 ? Colors.red.shade100 : Colors.green.shade100,
                                    foregroundColor: totalRemaining > 0 ? Colors.red.shade800 : Colors.green.shade800,
                                    child: Text(c.name.isNotEmpty ? c.name.substring(0, 1).toUpperCase() : '?'),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        const SizedBox(height: 2),
                                        Text(
                                          c.phone.isNotEmpty ? 'Tél: ${c.phone}' : 'Sans numéro',
                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                        ),
                                        if (activeDebtsCount > 0)
                                          Text(
                                            '$activeDebtsCount dette(s) en cours',
                                            style: TextStyle(fontSize: 11, color: Colors.orange.shade800, fontWeight: FontWeight.w600),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${totalRemaining.toStringAsFixed(3)} DT',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: totalRemaining > 0 ? Colors.red.shade700 : Colors.green.shade700,
                                        ),
                                      ),
                                      Text(
                                        totalRemaining > 0 ? 'Ardoise en cours' : 'Réglé',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: totalRemaining > 0 ? Colors.red.shade700 : Colors.green.shade700,
                                        ),
                                      ),
                                      if (totalRemaining > 0) ...[
                                        const SizedBox(height: 4),
                                        OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                            visualDensity: VisualDensity.compact,
                                            foregroundColor: Colors.green.shade700,
                                            side: BorderSide(color: Colors.green.shade700),
                                          ),
                                          onPressed: () => _openPaymentModal(context, c, totalRemainingDebt: totalRemaining),
                                          child: const Text('Payer', style: TextStyle(fontSize: 12)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryBox extends StatelessWidget {
  final String label;
  final String value;
  final MaterialColor color;

  const _SummaryBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color.shade900)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color.shade900)),
        ],
      ),
    );
  }
}
