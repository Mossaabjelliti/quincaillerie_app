import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' hide Column;
import '../../data/local/database.dart';
import '../../core/auth/auth_provider.dart';

class CustomerDebtScreen extends StatefulWidget {
  const CustomerDebtScreen({super.key});

  @override
  State<CustomerDebtScreen> createState() => _CustomerDebtScreenState();
}

class _CustomerDebtScreenState extends State<CustomerDebtScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _paymentAmountController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _paymentAmountController.dispose();
    super.dispose();
  }

  void _openAddCustomerModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nouveau Client (Ardoise)',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nom du Client *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Téléphone (WhatsApp / SMS)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Adresse / Remarque', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (_nameController.text.trim().isEmpty) return;
                  final db = context.read<AppDatabase>();
                  final storeId = context.read<AuthProvider>().session?.currentStoreId ?? '';
                  const uuid = Uuid();

                  await db.into(db.customers).insert(
                        CustomersCompanion.insert(
                          id: uuid.v4(),
                          storeId: storeId,
                          name: _nameController.text.trim(),
                          phone: Value(_phoneController.text.trim()),
                          address: Value(_addressController.text.trim()),
                          synced: const Value(false),
                        ),
                      );

                  _nameController.clear();
                  _phoneController.clear();
                  _addressController.clear();
                  if (mounted) Navigator.pop(context);
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
        );
      },
    );
  }

  void _openPaymentModal(BuildContext context, Customer customer, double currentDebt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Règlement d\'Ardoise - ${customer.name}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Dette actuelle: ${currentDebt.toStringAsFixed(3)} TND',
                style: const TextStyle(fontSize: 16, color: Colors.red, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _paymentAmountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Montant versé (TND)',
                  suffixText: 'TND',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(_paymentAmountController.text.trim());
                  if (amount == null || amount <= 0) return;

                  final db = context.read<AppDatabase>();
                  final storeId = context.read<AuthProvider>().session?.currentStoreId ?? '';
                  const uuid = Uuid();

                  // Record payment
                  await db.into(db.debtPayments).insert(
                        DebtPaymentsCompanion.insert(
                          id: uuid.v4(),
                          storeId: storeId,
                          debtId: uuid.v4(), // Generic payment reference
                          customerId: customer.id,
                          amount: amount,
                          paymentMethod: const Value('cash'),
                          synced: const Value(false),
                        ),
                      );

                  _paymentAmountController.clear();
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Paiement de ${amount.toStringAsFixed(3)} TND enregistré.')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Valider le Versement'),
              ),
            ],
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
        title: const Text('Gestion des Clients & Ardoises'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddCustomerModal(context),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Nouveau Client'),
        backgroundColor: Colors.amber.shade700,
      ),
      body: StreamBuilder<List<Customer>>(
        stream: (db.select(db.customers)..where((c) => c.storeId.equals(storeId))).watch(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final customers = snapshot.data ?? [];
          if (customers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('Aucun client enregistré.', style: TextStyle(color: Colors.grey, fontSize: 16)),
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
                  double totalDebt = debts.fold(0.0, (sum, d) => sum + d.remainingAmount);

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: totalDebt > 0 ? Colors.red.shade100 : Colors.green.shade100,
                        foregroundColor: totalDebt > 0 ? Colors.red.shade800 : Colors.green.shade800,
                        child: Text(c.name.substring(0, 1).toUpperCase()),
                      ),
                      title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        c.phone.isNotEmpty ? 'Tél: ${c.phone}' : 'Pas de numéro',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${totalDebt.toStringAsFixed(3)} DT',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: totalDebt > 0 ? Colors.red.shade700 : Colors.green.shade700,
                            ),
                          ),
                          Text(
                            totalDebt > 0 ? 'Ardoise en cours' : 'Réglé',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                      onTap: () => _openPaymentModal(context, c, totalDebt),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
