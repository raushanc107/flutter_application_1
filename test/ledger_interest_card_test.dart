import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:khatabook/core/database/database.dart';
import 'package:khatabook/core/providers/language_provider.dart';
import 'package:khatabook/features/ledger/ledger_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase(NativeDatabase.memory());
  });

  void expectDarkCardSurface(WidgetTester tester, Finder finder) {
    final decoration =
        tester.widget<Container>(finder).decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFF1E293B).withValues(alpha: 0.6));
    expect(decoration.borderRadius, BorderRadius.circular(20));
    expect(
      decoration.border!.top.color,
      const Color(0xFF334155).withValues(alpha: 0.3),
    );
    expect(decoration.boxShadow, hasLength(1));
  }

  tearDown(() async {
    await database.close();
  });

  testWidgets(
    'interest entry shows due summary and paid action in ledger card',
    (tester) async {
      final now = DateTime.now();
      const customerId = 'interest-card-customer';
      const parentId = 'interest-card-parent';
      const interestId = 'interest-card-record';

      await database.insertCustomer(
        const CustomersCompanion(
          id: Value(customerId),
          name: Value('Test Customer'),
          phoneNumber: Value(''),
        ),
      );
      await database.insertTransaction(
        TransactionsCompanion(
          id: const Value(parentId),
          customerId: const Value(customerId),
          amount: const Value(1000),
          type: const Value('GAVE'),
          date: Value(now.subtract(const Duration(days: 40))),
          notes: const Value('Loan'),
          interestRate: const Value(2),
          interestPeriod: const Value('MONTHLY'),
          lastInterestCalculatedDate: Value(
            now.subtract(const Duration(days: 2)),
          ),
        ),
      );
      await database.insertTransaction(
        TransactionsCompanion(
          id: const Value(interestId),
          customerId: const Value(customerId),
          amount: const Value(20),
          type: const Value('GAVE'),
          date: Value(now.subtract(const Duration(days: 2))),
          notes: const Value('Interest for October'),
          isInterestEntry: const Value(true),
          parentTransactionId: const Value(parentId),
        ),
      );
      await database.insertTransaction(
        TransactionsCompanion(
          id: const Value('interest-card-paid-record'),
          customerId: const Value(customerId),
          amount: const Value(15),
          type: const Value('GAVE'),
          date: Value(now.subtract(const Duration(days: 20))),
          notes: const Value('Interest for September'),
          isInterestEntry: const Value(true),
          parentTransactionId: const Value(parentId),
          isPaid: const Value(true),
        ),
      );
      final customer = await database.getCustomerById(customerId);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AppDatabase>.value(value: database),
            ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: LedgerScreen(customer: customer!),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expectDarkCardSurface(
        tester,
        find.byKey(const ValueKey('interest-card-interest-card-parent')),
      );
      expect(
        find.byKey(const ValueKey('summary-row-interest')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('summary-row-normal')), findsNothing);
      expect(find.byKey(const ValueKey('summary-row-recurring')), findsNothing);
      expect(find.text('2.0% Monthly'), findsOneWidget);
      expect(find.byIcon(Icons.percent), findsOneWidget);
      expect(find.textContaining('Interest due'), findsNWidgets(2));
      expect(find.text('Mark as Paid'), findsOneWidget);
      expect(find.text('Record payment'), findsOneWidget);

      await tester.tap(find.text('Loan'));
      await tester.pumpAndSettle();

      expect(find.text('OVERDUE'), findsOneWidget);
      expect(find.text('November Interest'), findsOneWidget);
      expect(find.text('Overdue interest'), findsOneWidget);
      expect(find.text('Interest for October'), findsOneWidget);
      expect(find.text('Mark as Paid'), findsNWidgets(2));
      expect(find.text('Paid history · ₹15'), findsOneWidget);
      final paidInterestRow = find.byKey(
        const ValueKey('interest-paid-interest-card-paid-record'),
      );
      expect(paidInterestRow, findsOneWidget);
      expect(
        find.descendant(of: paidInterestRow, matching: find.text('PAID')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.descendant(of: paidInterestRow, matching: find.text('₹15')),
            )
            .style
            ?.decoration,
        TextDecoration.lineThrough,
      );
      expect(find.textContaining('Next'), findsWidgets);
      expect(
        tester
            .getTopLeft(
              find.byKey(const ValueKey('interest-next-interest-card-parent')),
            )
            .dy,
        lessThan(tester.getTopLeft(find.text('Overdue interest')).dy),
      );

      await tester.drag(find.text('Loan'), const Offset(0, -250));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark as Paid').last);
      await tester.pumpAndSettle();

      final paidRecord = await database.getTransactionById(interestId);
      expect(paidRecord?.isPaid, isTrue);
      expect(find.text('Paid history · ₹35'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('interest-paid-interest-card-paid-record')),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets('recurring parent uses the scheduled payment card', (
    tester,
  ) async {
    final now = DateTime.now();
    const customerId = 'recurring-card-customer';
    const parentId = 'recurring-card-parent';
    const recurringId = 'recurring-card-schedule';
    const recordId = 'recurring-card-record';
    const paidRecordId = 'recurring-card-paid-record';
    final lastGeneratedDate = now.subtract(const Duration(days: 2));

    await database.insertCustomer(
      const CustomersCompanion(
        id: Value(customerId),
        name: Value('Recurring Customer'),
        phoneNumber: Value(''),
      ),
    );
    await database.insertTransaction(
      TransactionsCompanion(
        id: const Value(parentId),
        customerId: const Value(customerId),
        amount: const Value(0),
        type: const Value('GAVE'),
        date: Value(now.subtract(const Duration(days: 40))),
        notes: const Value('Monthly Rent'),
        isRecurringParent: const Value(true),
      ),
    );
    await database.insertRecurringTransaction(
      RecurringTransactionsCompanion(
        id: const Value(recurringId),
        customerId: const Value(customerId),
        amount: const Value(3000),
        type: const Value('GAVE'),
        frequency: const Value('MONTHLY'),
        startDate: Value(now.subtract(const Duration(days: 40))),
        note: const Value('Monthly Rent'),
        lastGeneratedDate: Value(lastGeneratedDate),
        linkedTransactionId: const Value(parentId),
      ),
    );
    await database.insertTransaction(
      TransactionsCompanion(
        id: const Value(recordId),
        customerId: const Value(customerId),
        amount: const Value(3000),
        type: const Value('GAVE'),
        date: Value(lastGeneratedDate),
        notes: const Value('Monthly Rent - October'),
        parentTransactionId: const Value(parentId),
      ),
    );
    await database.insertTransaction(
      TransactionsCompanion(
        id: const Value(paidRecordId),
        customerId: const Value(customerId),
        amount: const Value(1500),
        type: const Value('GAVE'),
        date: Value(lastGeneratedDate.subtract(const Duration(days: 30))),
        notes: const Value('September Rent'),
        parentTransactionId: const Value(parentId),
        isPaid: const Value(true),
      ),
    );
    final customer = await database.getCustomerById(customerId);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppDatabase>.value(value: database),
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: LedgerScreen(customer: customer!),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expectDarkCardSurface(
      tester,
      find.byKey(const ValueKey('recurring-card-recurring-card-parent')),
    );
    expect(find.text('Monthly Rent'), findsOneWidget);
    expect(find.text('₹3,000'), findsWidgets);

    await tester.tap(find.text('Monthly Rent'));
    await tester.pumpAndSettle();

    expect(find.text('Monthly Rent - October'), findsOneWidget);
    final nextDueDate = DateTime(
      lastGeneratedDate.year,
      lastGeneratedDate.month + 1,
      lastGeneratedDate.day,
    );
    expect(find.text('November Monthly Rent'), findsOneWidget);
    expect(find.text('Recurring due'), findsNWidgets(2));
    expect(find.text('Paid history · ₹1,500'), findsOneWidget);
    expect(find.text('Monthly Rent - October'), findsOneWidget);
    final paidRecurringRow = find.byKey(
      const ValueKey('recurring-paid-recurring-card-paid-record'),
    );
    expect(paidRecurringRow, findsOneWidget);
    expect(
      find.descendant(of: paidRecurringRow, matching: find.text('PAID')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: paidRecurringRow,
              matching: find.text('₹1,500'),
            ),
          )
          .style
          ?.decoration,
      TextDecoration.lineThrough,
    );
    expect(
      find.textContaining(DateFormat('dd MMM yyyy').format(nextDueDate)),
      findsOneWidget,
    );
    final recurringCard = find.byKey(
      const ValueKey('recurring-card-recurring-card-parent'),
    );
    expect(
      find.descendant(of: recurringCard, matching: find.text('Mark as Paid')),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Mark as Paid'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as Paid').last);
    await tester.pumpAndSettle();
    expect((await database.getTransactionById(recordId))?.isPaid, isTrue);
    expect(
      find.descendant(of: recurringCard, matching: find.text('Recurring due')),
      findsNothing,
    );
    final newlyPaidRecurringRow = find.byKey(
      const ValueKey('recurring-paid-recurring-card-record'),
    );
    expect(newlyPaidRecurringRow, findsOneWidget);
    expect(
      find.descendant(of: newlyPaidRecurringRow, matching: find.text('PAID')),
      findsOneWidget,
    );
    expect(find.text('Paid history · ₹4,500'), findsOneWidget);
    expect(
      tester
          .getTopLeft(
            find.byKey(const ValueKey('recurring-next-recurring-card-parent')),
          )
          .dy,
      lessThan(tester.getTopLeft(find.text('Monthly Rent - October')).dy),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('summary shows due and paid totals for present categories', (
    tester,
  ) async {
    final now = DateTime.now();
    const customerId = 'summary-customer';

    await database.insertCustomer(
      const CustomersCompanion(
        id: Value(customerId),
        name: Value('Summary Customer'),
        phoneNumber: Value(''),
      ),
    );

    Future<void> addTransaction({
      required String id,
      required double amount,
      String? parentId,
      bool isInterestEntry = false,
      bool isRecurringParent = false,
      bool isPaid = false,
      bool isExcluded = false,
      double? interestRate,
    }) {
      return database.insertTransaction(
        TransactionsCompanion(
          id: Value(id),
          customerId: const Value(customerId),
          amount: Value(amount),
          type: const Value('GAVE'),
          date: Value(now),
          notes: Value(id),
          parentTransactionId: Value(parentId),
          isInterestEntry: Value(isInterestEntry),
          isRecurringParent: Value(isRecurringParent),
          isPaid: Value(isPaid),
          isExcluded: Value(isExcluded),
          interestRate: Value(interestRate),
        ),
      );
    }

    await addTransaction(id: 'normal-due', amount: 300);
    await addTransaction(id: 'normal-paid', amount: 125, isPaid: true);
    await addTransaction(id: 'normal-excluded', amount: 400, isExcluded: true);
    await addTransaction(id: 'interest-parent', amount: 1000, interestRate: 2);
    await addTransaction(
      id: 'interest-due',
      amount: 20,
      parentId: 'interest-parent',
      isInterestEntry: true,
    );
    await addTransaction(
      id: 'interest-paid',
      amount: 10,
      parentId: 'interest-parent',
      isInterestEntry: true,
      isPaid: true,
    );
    await addTransaction(
      id: 'recurring-parent',
      amount: 0,
      isRecurringParent: true,
    );
    await addTransaction(
      id: 'recurring-due',
      amount: 200,
      parentId: 'recurring-parent',
    );
    await addTransaction(
      id: 'recurring-paid',
      amount: 100,
      parentId: 'recurring-parent',
      isPaid: true,
    );

    final customer = await database.getCustomerById(customerId);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppDatabase>.value(value: database),
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ],
        child: MaterialApp(home: LedgerScreen(customer: customer!)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('summary-row-normal')), findsNothing);
    expect(find.text('Normal paid'), findsNothing);

    for (final (category, due, paid) in [
      ('interest', '₹20', '₹10'),
      ('recurring', '₹200', '₹100'),
    ]) {
      final row = find.byKey(ValueKey('summary-row-$category'));
      expect(row, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.text(due)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text(paid)),
        findsOneWidget,
      );
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('consecutive ordinary transactions form separate month runs', (
    tester,
  ) async {
    final now = DateTime.now();
    const customerId = 'mixed-ledger-customer';
    const firstNormalId = 'normal-first';
    const secondNormalId = 'normal-second';
    const firstInterestId = 'interest-first';
    const secondInterestId = 'interest-second';
    const laterNormalId = 'normal-later-first';
    const laterNormalTwoId = 'normal-later-second';
    const laterNormalThreeId = 'normal-later-third';

    await database.insertCustomer(
      const CustomersCompanion(
        id: Value(customerId),
        name: Value('Mixed Ledger Customer'),
        phoneNumber: Value(''),
      ),
    );

    Future<void> addTransaction({
      required String id,
      required int daysAgo,
      required String note,
      double amount = 100,
      double? interestRate,
    }) {
      return database.insertTransaction(
        TransactionsCompanion(
          id: Value(id),
          customerId: const Value(customerId),
          amount: Value(amount),
          type: const Value('GAVE'),
          date: Value(now.subtract(Duration(days: daysAgo))),
          notes: Value(note),
          interestRate: Value(interestRate),
          interestPeriod: interestRate == null
              ? const Value.absent()
              : const Value('MONTHLY'),
          lastInterestCalculatedDate: interestRate == null
              ? const Value.absent()
              : Value(now.subtract(Duration(days: daysAgo))),
        ),
      );
    }

    await addTransaction(id: firstNormalId, daysAgo: 1, note: 'Normal one');
    await addTransaction(id: secondNormalId, daysAgo: 2, note: 'Normal two');
    await addTransaction(
      id: firstInterestId,
      daysAgo: 3,
      note: 'Interest one',
      interestRate: 2,
    );
    await addTransaction(
      id: secondInterestId,
      daysAgo: 4,
      note: 'Interest two',
      interestRate: 3,
    );
    await addTransaction(id: laterNormalId, daysAgo: 5, note: 'Normal three');
    await addTransaction(id: laterNormalTwoId, daysAgo: 6, note: 'Normal four');
    await addTransaction(
      id: laterNormalThreeId,
      daysAgo: 7,
      note: 'Normal five',
    );

    final customer = await database.getCustomerById(customerId);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppDatabase>.value(value: database),
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: LedgerScreen(customer: customer!),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final firstGroup = find.byKey(const ValueKey('normal-group-normal-first'));
    final secondGroup = find.byKey(
      const ValueKey('normal-group-normal-later-first'),
    );
    expect(firstGroup, findsOneWidget);
    expect(
      find.descendant(of: firstGroup, matching: find.byType(Material)),
      findsNWidgets(2),
    );
    final groupDecoration =
        tester.widget<Container>(firstGroup).decoration! as BoxDecoration;
    expect(
      groupDecoration.color,
      const Color(0xFF1E293B).withValues(alpha: 0.6),
    );
    expect(groupDecoration.borderRadius, BorderRadius.circular(20));
    final dateBadgeFinder = find.byKey(
      const ValueKey('transaction-badge-normal-first'),
    );
    final dateBadge = tester.widget<Container>(dateBadgeFinder);
    expect(dateBadge.decoration, equals(null));
    expect(tester.getSize(dateBadgeFinder).width, 38);
    expect(tester.getTopLeft(dateBadgeFinder).dx, 26);
    expect(
      tester.getTopLeft(find.text('Normal one')).dx -
          tester.getTopRight(dateBadgeFinder).dx,
      11,
    );
    await tester.scrollUntilVisible(
      secondGroup,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(secondGroup, findsOneWidget);
    expect(
      find.descendant(of: secondGroup, matching: find.byType(Material)),
      findsNWidgets(3),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
