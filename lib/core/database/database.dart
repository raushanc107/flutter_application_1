import 'package:drift/drift.dart';

// Assuming Drift generation will create this file
part 'database.g.dart';

class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phoneNumber => text()();
  RealColumn get currentBalance => real().withDefault(const Constant(0.0))();
  DateTimeColumn get lastUpdated =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text().references(Customers, #id)();
  RealColumn get amount => real()();
  TextColumn get type => text()(); // 'GAVE' or 'GOT'
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Customers, Transactions])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  // DAO-like methods
  Future<List<Customer>> getAllCustomers() => select(customers).get();
  Stream<List<Customer>> watchAllCustomers() => select(customers).watch();
  Future<int> insertCustomer(CustomersCompanion customer) =>
      into(customers).insert(customer);
  Future updateCustomer(Customer customer) =>
      update(customers).replace(customer);
  Future<void> deleteCustomer(Customer customer) async {
    await (delete(
      transactions,
    )..where((t) => t.customerId.equals(customer.id))).go();
    await delete(customers).delete(customer);
  }

  Future<void> deleteAllData() async {
    await delete(transactions).go();
    await delete(customers).go();
  }

  Future<List<Transaction>> getAllTransactions() => select(transactions).get();

  Future<List<Transaction>> getTransactionsForCustomer(String customerId) {
    return (select(
      transactions,
    )..where((t) => t.customerId.equals(customerId))).get();
  }

  Stream<List<Transaction>> watchTransactionsForCustomer(String customerId) {
    return (select(
      transactions,
    )..where((t) => t.customerId.equals(customerId))).watch();
  }

  Future<int> insertTransaction(TransactionsCompanion transaction) =>
      into(transactions).insert(transaction);

  Future updateTransaction(Transaction transaction) =>
      update(transactions).replace(transaction);

  Future deleteTransaction(Transaction transaction) =>
      delete(transactions).delete(transaction);

  Future<Transaction?> getTransactionById(String id) {
    return (select(
      transactions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> recalculateAllBalances() async {
    final allCustomers = await getAllCustomers();
    for (final customer in allCustomers) {
      final customerTransactions = await (select(
        transactions,
      )..where((t) => t.customerId.equals(customer.id))).get();

      double balance = 0;
      for (final tx in customerTransactions) {
        // GAVE: You gave money (Credit) -> Positive
        // GOT: You got money (Payment) -> Negative (reduces credit)
        // Check logic in Dashboard: Balance > 0 is "You will get" (Credit).
        // Check logic in Ledger: GAVE is +ve effect (if deleting gave, subtract).
        if (tx.type == 'GAVE') {
          balance += tx.amount;
        } else {
          balance -= tx.amount;
        }
      }

      await updateCustomer(customer.copyWith(currentBalance: balance));
    }
  }
}
