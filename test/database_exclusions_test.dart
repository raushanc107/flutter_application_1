import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khatabook/core/database/database.dart';
import 'package:khatabook/core/services/backup_service.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('exclusions are applied to balances and report aggregates', () async {
    final today = DateTime.now();
    await database.insertCustomer(
      const CustomersCompanion(
        id: Value('included'),
        name: Value('Included'),
        phoneNumber: Value('111'),
      ),
    );
    await database.insertCustomer(
      const CustomersCompanion(
        id: Value('hidden'),
        name: Value('Hidden'),
        phoneNumber: Value('222'),
        isExcluded: Value(true),
      ),
    );

    await database.insertTransaction(
      TransactionsCompanion(
        id: const Value('included-tx'),
        customerId: const Value('included'),
        amount: const Value(120),
        type: const Value('GAVE'),
        date: Value(today),
      ),
    );
    await database.insertTransaction(
      TransactionsCompanion(
        id: const Value('excluded-tx'),
        customerId: const Value('included'),
        amount: const Value(80),
        type: const Value('GAVE'),
        date: Value(today),
        isExcluded: const Value(true),
      ),
    );
    await database.insertTransaction(
      TransactionsCompanion(
        id: const Value('hidden-customer-tx'),
        customerId: const Value('hidden'),
        amount: const Value(500),
        type: const Value('GAVE'),
        date: Value(today),
      ),
    );

    await database.recalculateAllBalances();

    final customers = await database.getAllCustomers();
    expect(
      customers
          .singleWhere((customer) => customer.id == 'included')
          .currentBalance,
      120,
    );

    final overview = await database.getFinancialOverview(
      today.subtract(const Duration(days: 1)),
      today.add(const Duration(days: 1)),
    );
    expect(overview['totalGiven'], 120);
    expect(overview['totalTransactions'], 1);
    expect(overview['totalCustomers'], 1);
    expect(overview['totalOutstanding'], 120);

    final cashFlow = await database.getCashFlowData(
      today.subtract(const Duration(days: 1)),
      today.add(const Duration(days: 1)),
    );
    expect(cashFlow.values.single['given'], 120);
  });

  test(
    'Drive restore replaces data and retains inactive recurring entries',
    () async {
      final source = AppDatabase(NativeDatabase.memory());
      addTearDown(source.close);

      await source.insertCustomer(
        const CustomersCompanion(
          id: Value('restored-customer'),
          name: Value('Restored'),
          phoneNumber: Value('333'),
          isExcluded: Value(true),
        ),
      );
      await source.insertTransaction(
        TransactionsCompanion(
          id: const Value('restored-transaction'),
          customerId: const Value('restored-customer'),
          amount: const Value(40),
          type: const Value('GAVE'),
          date: Value(DateTime.now()),
          isExcluded: const Value(true),
        ),
      );
      await source.insertRecurringTransaction(
        RecurringTransactionsCompanion(
          id: const Value('inactive-recurring'),
          customerId: const Value('restored-customer'),
          amount: const Value(20),
          type: const Value('GAVE'),
          frequency: const Value('MONTHLY'),
          startDate: Value(DateTime.now()),
          note: const Value('Paused rent'),
          isActive: const Value(false),
        ),
      );

      final backup = await BackupService(source).createBackupJson();
      await database.insertCustomer(
        const CustomersCompanion(
          id: Value('old-customer'),
          name: Value('Old'),
          phoneNumber: Value('444'),
        ),
      );
      await database.insertTransaction(
        TransactionsCompanion(
          id: const Value('old-transaction'),
          customerId: const Value('old-customer'),
          amount: const Value(10),
          type: const Value('GAVE'),
          date: Value(DateTime.now()),
        ),
      );
      await database.insertRecurringTransaction(
        RecurringTransactionsCompanion(
          id: const Value('old-recurring'),
          customerId: const Value('old-customer'),
          amount: const Value(5),
          type: const Value('GAVE'),
          frequency: const Value('MONTHLY'),
          startDate: Value(DateTime.now()),
          note: const Value('Old recurring'),
          linkedTransactionId: const Value('old-transaction'),
        ),
      );

      await BackupService(database).restoreFromJsonString(backup);

      final customers = await database.getAllCustomers();
      expect(customers.map((customer) => customer.id), ['restored-customer']);
      expect(customers.single.isExcluded, isTrue);
      expect((await database.getAllTransactions()).single.isExcluded, isTrue);
      final recurring = await database.getAllRecurringTransactions();
      expect(recurring.single.id, 'inactive-recurring');
      expect(recurring.single.isActive, isFalse);
    },
  );

  test('failed restore leaves existing data unchanged', () async {
    await database.insertCustomer(
      const CustomersCompanion(
        id: Value('keep-me'),
        name: Value('Keep'),
        phoneNumber: Value('555'),
      ),
    );

    await expectLater(
      BackupService(database).restoreFromJsonString('not-json'),
      throwsA(isA<FormatException>()),
    );
    expect((await database.getAllCustomers()).single.id, 'keep-me');
  });
}
