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

  // Analytics methods for Reports & Insights
  Future<List<Transaction>> getTransactionsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return (select(transactions)
          ..where((t) => t.date.isBetweenValues(startDate, endDate))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  Future<Map<String, dynamic>> getFinancialOverview(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final txns = await getTransactionsByDateRange(startDate, endDate);
    final allCustomers = await getAllCustomers();

    double totalGiven = 0;
    double totalReceived = 0;
    int gaveCount = 0;
    int gotCount = 0;

    for (final tx in txns) {
      if (tx.type == 'GAVE') {
        totalGiven += tx.amount;
        gaveCount++;
      } else {
        totalReceived += tx.amount;
        gotCount++;
      }
    }

    int activeCustomers = 0;
    double totalOutstanding = 0;
    for (final customer in allCustomers) {
      if (customer.currentBalance.abs() > 0.01) {
        activeCustomers++;
      }
      totalOutstanding += customer.currentBalance;
    }

    return {
      'totalGiven': totalGiven,
      'totalReceived': totalReceived,
      'totalTransactions': txns.length,
      'gaveCount': gaveCount,
      'gotCount': gotCount,
      'activeCustomers': activeCustomers,
      'totalCustomers': allCustomers.length,
      'totalOutstanding': totalOutstanding,
      'avgTransaction': txns.isEmpty
          ? 0.0
          : (totalGiven + totalReceived) / txns.length,
    };
  }

  Future<Map<DateTime, Map<String, double>>> getCashFlowData(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final txns = await getTransactionsByDateRange(startDate, endDate);
    final Map<DateTime, Map<String, double>> dailyData = {};

    for (final tx in txns) {
      final date = DateTime(tx.date.year, tx.date.month, tx.date.day);
      if (!dailyData.containsKey(date)) {
        dailyData[date] = {'given': 0.0, 'received': 0.0};
      }
      if (tx.type == 'GAVE') {
        dailyData[date]!['given'] = dailyData[date]!['given']! + tx.amount;
      } else {
        dailyData[date]!['received'] =
            dailyData[date]!['received']! + tx.amount;
      }
    }

    // Limit to last 30 data points for performance
    final sortedDates = dailyData.keys.toList()..sort();
    if (sortedDates.length > 30) {
      final limitedData = <DateTime, Map<String, double>>{};
      for (final date in sortedDates.skip(sortedDates.length - 30)) {
        limitedData[date] = dailyData[date]!;
      }
      return limitedData;
    }

    return dailyData;
  }

  Future<Map<String, dynamic>> getBalanceDistribution() async {
    final allCustomers = await getAllCustomers();
    int customersOweYou = 0;
    int youOweCustomers = 0;
    int settled = 0;
    double totalPositive = 0;
    double totalNegative = 0;

    for (final customer in allCustomers) {
      if (customer.currentBalance > 0.01) {
        customersOweYou++;
        totalPositive += customer.currentBalance;
      } else if (customer.currentBalance < -0.01) {
        youOweCustomers++;
        totalNegative += customer.currentBalance.abs();
      } else {
        settled++;
      }
    }

    return {
      'customersOweYou': customersOweYou,
      'youOweCustomers': youOweCustomers,
      'settled': settled,
      'totalPositive': totalPositive,
      'totalNegative': totalNegative,
    };
  }

  Future<List<Map<String, dynamic>>> getTopCustomers({
    required int limit,
    required bool
    isDebtors, // true for debtors (owe you), false for creditors (you owe)
  }) async {
    final allCustomers = await getAllCustomers();
    final filtered = allCustomers.where((c) {
      if (isDebtors) {
        return c.currentBalance > 0.01;
      } else {
        return c.currentBalance < -0.01;
      }
    }).toList();

    filtered.sort(
      (a, b) => b.currentBalance.abs().compareTo(a.currentBalance.abs()),
    );

    return filtered
        .take(limit)
        .map(
          (c) => {
            'id': c.id,
            'name': c.name,
            'balance': c.currentBalance.abs(),
          },
        )
        .toList();
  }
}
