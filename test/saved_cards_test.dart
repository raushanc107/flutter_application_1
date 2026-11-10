import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khatabook/core/database/database.dart';
import 'package:khatabook/core/services/backup_service.dart';

SavedCardsCompanion _card(
  String id, {
  bool isDefault = false,
  String name = 'Card',
  DateTime? createdAt,
}) {
  return SavedCardsCompanion(
    id: Value(id),
    name: Value(name),
    issuer: const Value('Test Bank'),
    cardType: const Value('CREDIT'),
    network: const Value('visa'),
    cardNumber: const Value('4532771234564821'),
    expiry: const Value('08/29'),
    holderName: const Value('Test User'),
    colorTone: const Value('ocean'),
    isDefault: Value(isDefault),
    createdAt: Value(createdAt ?? DateTime.now()),
  );
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('default card rules', () {
    test('first saved card becomes the default', () async {
      await db.saveCard(_card('a'));
      final cards = await db.getAllSavedCards();
      expect(cards.single.isDefault, isTrue);
    });

    test('marking a card default clears the previous default', () async {
      await db.saveCard(_card('a'));
      await db.saveCard(_card('b', isDefault: true));
      final cards = {for (final c in await db.getAllSavedCards()) c.id: c};
      expect(cards['a']!.isDefault, isFalse);
      expect(cards['b']!.isDefault, isTrue);
    });

    test('a non-default card does not steal the default', () async {
      await db.saveCard(_card('a'));
      await db.saveCard(_card('b'));
      final cards = {for (final c in await db.getAllSavedCards()) c.id: c};
      expect(cards['a']!.isDefault, isTrue);
      expect(cards['b']!.isDefault, isFalse);
    });

    test('deleting the default promotes the oldest remaining card', () async {
      final t = DateTime(2026, 1, 1);
      await db.saveCard(_card('a', createdAt: t));
      await db.saveCard(_card('b', createdAt: t.add(const Duration(days: 1))));
      await db.saveCard(_card('c', createdAt: t.add(const Duration(days: 2))));
      await db.deleteSavedCard('a');
      final cards = {for (final c in await db.getAllSavedCards()) c.id: c};
      expect(cards.keys, unorderedEquals(['b', 'c']));
      expect(cards['b']!.isDefault, isTrue);
      expect(cards['c']!.isDefault, isFalse);
    });

    test('setDefaultSavedCard leaves exactly one default', () async {
      await db.saveCard(_card('a'));
      await db.saveCard(_card('b'));
      await db.setDefaultSavedCard('b');
      final defaults = (await db.getAllSavedCards()).where((c) => c.isDefault);
      expect(defaults.map((c) => c.id), ['b']);
    });

    test('editing a card keeps its creation date', () async {
      final t = DateTime(2026, 3, 3);
      await db.saveCard(_card('a', createdAt: t));
      await db.saveCard(
        SavedCardsCompanion(
          id: const Value('a'),
          name: const Value('Renamed'),
          issuer: const Value('Test Bank'),
          cardType: const Value('DEBIT'),
          network: const Value('visa'),
          cardNumber: const Value('4532771234564821'),
          expiry: const Value('08/29'),
          holderName: const Value('Test User'),
          isDefault: const Value(true),
        ),
      );
      final card = (await db.getAllSavedCards()).single;
      expect(card.name, 'Renamed');
      expect(card.cardType, 'DEBIT');
      expect(
        card.createdAt.millisecondsSinceEpoch ~/ 1000,
        t.millisecondsSinceEpoch ~/ 1000,
      );
    });
  });

  group('backup and restore', () {
    test('backup JSON contains cards and schema version 7', () async {
      await db.saveCard(_card('a', name: 'Everyday'));
      final json =
          jsonDecode(await BackupService(db).createBackupJson())
              as Map<String, dynamic>;
      expect(json['version'], 7);
      final cards = json['savedCards'] as List;
      expect(cards, hasLength(1));
      expect(cards.single['cardNumber'], '4532771234564821');
      expect(cards.single['name'], 'Everyday');
    });

    test('restore round-trips cards into a fresh database', () async {
      await db.saveCard(_card('a', name: 'One'));
      await db.saveCard(_card('b', name: 'Two', isDefault: true));
      final backup = await BackupService(db).createBackupJson();

      final other = AppDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      final result = await BackupService(other).restoreFromJsonString(backup);

      expect(result['savedCards'], 2);
      final cards = {for (final c in await other.getAllSavedCards()) c.id: c};
      expect(cards.keys, unorderedEquals(['a', 'b']));
      expect(cards['b']!.isDefault, isTrue);
      expect(cards['a']!.isDefault, isFalse);
      expect(cards['a']!.cardNumber, '4532771234564821');
      expect(cards['a']!.colorTone, 'ocean');
    });

    test('restore replaces existing cards (does not merge)', () async {
      await db.saveCard(_card('old'));
      final other = AppDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      await other.saveCard(_card('new'));
      final backup = await BackupService(other).createBackupJson();

      await BackupService(db).restoreFromJsonString(backup);
      expect((await db.getAllSavedCards()).map((c) => c.id), ['new']);
    });

    test('merge import adds missing cards and keeps one default', () async {
      await db.saveCard(_card('mine')); // default
      final other = AppDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      await other.saveCard(_card('mine'));
      await other.saveCard(_card('theirs', isDefault: true));
      final backup = await BackupService(other).createBackupJson();

      final result = await BackupService(db).importFromJsonString(backup);
      expect(result['savedCards'], 1); // 'mine' already existed
      final cards = {for (final c in await db.getAllSavedCards()) c.id: c};
      expect(cards.keys, unorderedEquals(['mine', 'theirs']));
      expect(cards.values.where((c) => c.isDefault), hasLength(1));
      expect(cards['mine']!.isDefault, isTrue);
    });

    test('backups from before cards existed still import', () async {
      final old = jsonEncode({
        'customers': [],
        'transactions': [],
        'recurringTransactions': [],
        'version': 6,
      });
      await db.saveCard(_card('keep'));
      final result = await BackupService(db).restoreFromJsonString(old);
      expect(result['savedCards'], 0);
      expect(await db.getAllSavedCards(), isEmpty); // restore wipes cards too
    });

    test('factory reset (deleteAllData) removes cards', () async {
      await db.saveCard(_card('a'));
      await db.deleteAllData();
      expect(await db.getAllSavedCards(), isEmpty);
    });
  });

  test('upgrading a v6 database creates the saved_cards table', () async {
    final dir = await Directory.systemTemp.createTemp('khatabook_mig');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/db.sqlite');

    var first = AppDatabase(NativeDatabase(file));
    await first.customSelect('SELECT 1').get(); // forces creation at v7
    await first.customStatement('DROP TABLE saved_cards');
    await first.customStatement('PRAGMA user_version = 6');
    await first.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    await upgraded.saveCard(_card('after-upgrade'));
    expect((await upgraded.getAllSavedCards()).single.id, 'after-upgrade');
  });
}
