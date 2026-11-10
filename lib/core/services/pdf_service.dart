import 'package:flutter/foundation.dart'; // For compute
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../database/database.dart';
import '../models/pdf_config.dart';

import 'package:printing/printing.dart';

/// Generates the two customer PDFs:
///  * Full statement (date range, opening balance, running balance,
///    interest-loan and recurring sections)
///  * Payment request (only pending interest and recurring dues, as of today)
class PdfService {
  static Future<Uint8List> generateCustomerReport({
    required Customer customer,
    required List<Transaction> transactions,
    required List<RecurringTransaction> recurringRules,
    required PdfConfig config,
  }) async {
    final font = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();

    return await compute(
      _generatePdfBytes,
      _PdfGenerationParams(
        customer: customer,
        transactions: transactions,
        recurringRules: recurringRules,
        config: config,
        font: font,
        bold: bold,
      ),
    );
  }

  static Future<Uint8List> _generatePdfBytes(
    _PdfGenerationParams params,
  ) async {
    final pdf = pw.Document();
    final ledger = _Ledger(params.transactions);
    final now = DateTime.now();

    final theme = pw.ThemeData.withFont(base: params.font, bold: params.bold);

    final List<pw.Widget> Function() body;
    final PdfColor accent;
    if (params.config.type == StatementType.paymentRequest) {
      accent = _orangeDark;
      body = () =>
          _paymentRequest(params.customer, ledger, params.recurringRules, now);
    } else {
      accent = _indigo;
      body = () => _fullStatement(
        params.customer,
        ledger,
        params.recurringRules,
        params.config,
        now,
      );
    }

    final title = params.config.type == StatementType.paymentRequest
        ? 'PAYMENT REQUEST'
        : 'ACCOUNT STATEMENT';
    final subtitle = params.config.type == StatementType.paymentRequest
        ? 'Interest & recurring dues'
        : 'Customer Ledger';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: theme,
        build: (context) => [
          _banner(title, subtitle, accent, now),
          pw.SizedBox(height: 18),
          ...body(),
        ],
        footer: _buildFooter,
      ),
    );

    return pdf.save();
  }

  // ---------------------------------------------------------------------
  // Colours & formats
  // ---------------------------------------------------------------------
  static const _indigo = PdfColor.fromInt(0xFF283593);
  static const _orangeDark = PdfColor.fromInt(0xFFBF360C);
  static const _orange = PdfColor.fromInt(0xFFE65100);
  static const _red = PdfColor.fromInt(0xFFC62828);
  static const _green = PdfColor.fromInt(0xFF2E7D32);
  static const _grey = PdfColor.fromInt(0xFF6B7280);
  static const _line = PdfColor.fromInt(0xFFE1E3EE);
  static const _headBg = PdfColor.fromInt(0xFFEEF0FA);
  static const _totBg = PdfColor.fromInt(0xFFFAFBFF);
  static const _greenBg = PdfColor.fromInt(0xFFF6FBF6);
  static const _orangeBg = PdfColor.fromInt(0xFFFFF3E0);
  static const _purpleBg = PdfColor.fromInt(0xFFF3EFFB);

  static final _num = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '',
    decimalDigits: 2,
  );
  static final _money = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs. ',
    decimalDigits: 2,
  );
  static final _date = DateFormat('dd MMM yyyy');

  static String _n(double v) => _num.format(v);
  static String _m(double v) => _money.format(v);
  static String _d(DateTime d) => _date.format(d);

  static String _rate(double r) =>
      r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toString();

  // ---------------------------------------------------------------------
  // Full statement
  // ---------------------------------------------------------------------
  static List<pw.Widget> _fullStatement(
    Customer customer,
    _Ledger ledger,
    List<RecurringTransaction> rules,
    PdfConfig config,
    DateTime now,
  ) {
    final start = config.getStartDate();
    final end = config.getEndDate() ?? now;

    bool beforeStart(Transaction t) => start != null && t.date.isBefore(start);
    bool afterEnd(Transaction t) => t.date.isAfter(end);

    final upToEnd = ledger.txs.where((t) => !afterEnd(t)).toList();
    final before = upToEnd.where(beforeStart).toList();
    final inRange = upToEnd.where((t) => !beforeStart(t)).toList();

    double net(Transaction t) =>
        t.type == 'GOT' ? -t.amount : (t.isPaid ? 0 : t.amount);

    final opening = before.fold<double>(0, (s, t) => s + net(t));

    double given = 0, interest = 0, got = 0, settled = 0;
    for (final t in inRange) {
      if (t.type == 'GOT') {
        got += t.amount;
        continue;
      }
      if (ledger.kindOf(t) == _Kind.interest) {
        interest += t.amount;
      } else {
        given += t.amount;
      }
      if (t.isPaid) settled += t.amount;
    }
    final closing = opening + given + interest - got - settled;

    final periodStart =
        start ?? (inRange.isNotEmpty ? inRange.first.date : now);
    final widgets = <pw.Widget>[];

    // Top cards
    widgets.add(
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 11,
            child: _card(
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _cardTitle('CUSTOMER', _indigo),
                  pw.Text(
                    customer.name,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  _kv(
                    'Phone',
                    customer.phoneNumber.isNotEmpty
                        ? customer.phoneNumber
                        : '-',
                  ),
                  _kv('Period', '${_d(periodStart)} - ${_d(end)}'),
                ],
              ),
            ),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            flex: 10,
            child: _card(
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _cardTitle('TOTAL AMOUNT PAYABLE', _indigo),
                  pw.Text(
                    _m(closing),
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: closing > 0 ? _red : _green,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    closing < 0
                        ? 'Advance / credit in your favour'
                        : 'Amount you need to pay us',
                    style: const pw.TextStyle(fontSize: 9, color: _grey),
                  ),
                ],
              ),
              color: _headBg,
            ),
          ),
        ],
      ),
    );

    // Account summary
    widgets.add(_h2('Account summary'));
    widgets.add(
      pw.Table(
        columnWidths: {
          0: const pw.FlexColumnWidth(3),
          1: const pw.FlexColumnWidth(1.4),
        },
        border: const pw.TableBorder(
          horizontalInside: pw.BorderSide(color: _line, width: 0.5),
        ),
        children: [
          if (start != null) _sumRow('Previous balance', _m(opening)),
          _sumRow('+ Amounts given to you', _m(given)),
          _sumRow('+ Interest charged', _m(interest)),
          _sumRow('- Payments made by you', _m(got), color: _green),
          _sumRow('- Entries marked paid', _m(settled), color: _green),
          _sumRow(
            '= Total amount payable',
            _m(closing),
            bold: true,
            color: closing > 0 ? _red : _green,
            bg: _totBg,
          ),
        ],
      ),
    );

    // Interest loans
    final loanRows = <List<pw.Widget>>[];
    for (final loan in ledger.loans) {
      if (loan.date.isAfter(end)) continue;
      final all = ledger.interestEntriesOf(loan).where((t) => !afterEnd(t));
      final inR = all.where((t) => !beforeStart(t)).toList();
      final pending = all
          .where((t) => !t.isPaid)
          .fold<double>(0, (s, t) => s + t.amount);
      final loanInRange = !beforeStart(loan);
      if (!loanInRange && inR.isEmpty && pending == 0) continue;
      final charged = inR.fold<double>(0, (s, t) => s + t.amount);
      final paid = inR
          .where((t) => t.isPaid)
          .fold<double>(0, (s, t) => s + t.amount);
      final period = (loan.interestPeriod ?? 'MONTHLY').toLowerCase();
      final kind = (loan.interestType ?? 'SIMPLE').toLowerCase();
      loanRows.add([
        _cell(_d(loan.date)),
        _cell(ledger.loanLabel(loan)),
        _cell(_n(loan.amount), right: true),
        _cell('${_rate(loan.interestRate!)}% $period - $kind'),
        _cell('${inR.length}', right: true),
        _cell(_n(charged), right: true),
        _cell(_n(paid), right: true, color: _green),
        _cell(_n(pending), right: true, color: _orange, bold: true),
      ]);
    }
    if (loanRows.isNotEmpty) {
      widgets.add(
        _h2('Interest loans', '${loanRows.length} loan(s) charging interest'),
      );
      widgets.add(
        _table(
          headers: const [
            'Date',
            'Loan',
            'Principal',
            'Rate',
            'Entries',
            'Charged',
            'Paid',
            'Pending',
          ],
          rightCols: const {2, 4, 5, 6, 7},
          flex: const [1.5, 2.1, 1.5, 1.9, 1.15, 1.4, 1.3, 1.4],
          rows: loanRows,
        ),
      );
    }

    // Recurring
    final recRows = <List<pw.Widget>>[];
    for (final g in ledger.recurringGroups) {
      final all = g.entries.where((t) => !afterEnd(t)).toList();
      final inR = all.where((t) => !beforeStart(t)).toList();
      final unpaid = all.where((t) => !t.isPaid).toList();
      if (inR.isEmpty && unpaid.isEmpty) continue;
      final rule = ledger.ruleFor(g.parentId, rules);
      final amount = rule?.amount ?? g.entries.last.amount;
      final freq = rule == null
          ? '-'
          : '${_title(rule.frequency)} - ${rule.isActive ? 'Active' : 'Stopped'}';
      recRows.add([
        _cell(g.name),
        _cell(_n(amount), right: true),
        _cell(freq),
        _cell('${inR.length}', right: true),
        _cell('${inR.where((t) => t.isPaid).length}', right: true),
        _cell('${unpaid.length}', right: true),
        _cell(
          _n(unpaid.fold<double>(0, (s, t) => s + t.amount)),
          right: true,
          color: _orange,
          bold: true,
        ),
      ]);
    }
    if (recRows.isNotEmpty) {
      widgets.add(
        _h2('Recurring charges', '${recRows.length} recurring rule(s)'),
      );
      widgets.add(
        _table(
          headers: const [
            'Charge',
            'Amount',
            'Frequency',
            'Entries',
            'Paid',
            'Unpaid',
            'Pending',
          ],
          rightCols: const {1, 3, 4, 5, 6},
          flex: const [2.2, 1.4, 2, 1.15, 0.9, 1.1, 1.5],
          rows: recRows,
        ),
      );
    }

    // Transactions
    widgets.add(_h2('Transactions', 'With running balance'));
    final txRows = <pw.TableRow>[];
    double run = opening;
    if (start != null) {
      txRows.add(
        _txRow(
          _d(start),
          'Previous balance',
          null,
          null,
          null,
          _n(run),
          bg: _totBg,
        ),
      );
    }
    for (final t in inRange) {
      final kind = ledger.kindOf(t);
      if (t.type == 'GOT') {
        run -= t.amount;
        txRows.add(
          _txRow(
            _d(t.date),
            _desc(t.notes, 'Payment'),
            _Tag('Payment', _green, _greenBg),
            null,
            _n(t.amount),
            _n(run),
            bg: _greenBg,
          ),
        );
        continue;
      }
      run += t.amount;
      final tag = switch (kind) {
        _Kind.interest => _Tag(ledger.interestTag(t), _orange, _orangeBg),
        _Kind.principal => _Tag('Principal', _orange, _orangeBg),
        _Kind.recurring => _Tag(
          'Recurring',
          const PdfColor.fromInt(0xFF5E35B1),
          _purpleBg,
        ),
        _ => _Tag('Given', _indigo, _headBg),
      };
      txRows.add(
        _txRow(
          _d(t.date),
          _desc(t.notes, '-'),
          tag,
          _n(t.amount),
          null,
          _n(run),
        ),
      );
      if (t.isPaid) {
        run -= t.amount;
        txRows.add(
          _txRow(
            _d(t.date),
            'Marked as paid - ${_desc(t.notes, '-')}',
            _Tag('Settled', _green, _greenBg),
            null,
            _n(t.amount),
            _n(run),
            bg: _greenBg,
          ),
        );
      }
    }
    widgets.add(
      pw.Table(
        columnWidths: {
          0: const pw.FlexColumnWidth(1.5),
          1: const pw.FlexColumnWidth(4),
          2: const pw.FlexColumnWidth(1.5),
          3: const pw.FlexColumnWidth(1.5),
          4: const pw.FlexColumnWidth(1.6),
        },
        border: const pw.TableBorder(
          horizontalInside: pw.BorderSide(color: _line, width: 0.5),
        ),
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _headBg),
            children: [
              _head('Date'),
              _head('Description'),
              _head('Debit', right: true),
              _head('Credit', right: true),
              _head('Balance', right: true),
            ],
          ),
          ...txRows,
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _totBg),
            children: [
              _cell(''),
              _cell('Closing balance payable', bold: true),
              _cell(''),
              _cell(''),
              _cell(_n(run), right: true, bold: true, color: _red),
            ],
          ),
        ],
      ),
    );

    widgets.add(
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 16),
        child: pw.Text(
          'Debit = amount given to you or charged. Credit = payments made by '
          'you or entries marked paid. Computer-generated statement; no '
          'signature required.',
          style: const pw.TextStyle(fontSize: 8, color: _grey),
        ),
      ),
    );
    return widgets;
  }

  // ---------------------------------------------------------------------
  // Payment request
  // ---------------------------------------------------------------------
  static List<pw.Widget> _paymentRequest(
    Customer customer,
    _Ledger ledger,
    List<RecurringTransaction> rules,
    DateTime now,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    int daysPending(Transaction t) {
      final d = DateTime(t.date.year, t.date.month, t.date.day);
      final diff = today.difference(d).inDays;
      return diff < 0 ? 0 : diff;
    }

    bool pending(Transaction t) => !t.isPaid && !t.date.isAfter(now);

    // Pending interest grouped by loan
    final loanBlocks = <_DueGroup>[];
    for (final loan in ledger.loans) {
      final items = ledger.interestEntriesOf(loan).where(pending).toList();
      if (items.isEmpty) continue;
      loanBlocks.add(
        _DueGroup(
          title: ledger.loanLabel(loan),
          info:
              'Principal ${_m(loan.amount)}   Rate ${_rate(loan.interestRate!)}% '
              '${(loan.interestPeriod ?? 'MONTHLY').toLowerCase()}',
          items: items,
        ),
      );
    }
    // Pending recurring grouped by rule
    final recBlocks = <_DueGroup>[];
    for (final g in ledger.recurringGroups) {
      final items = g.entries.where(pending).toList();
      if (items.isEmpty) continue;
      final rule = ledger.ruleFor(g.parentId, rules);
      recBlocks.add(
        _DueGroup(
          title: g.name,
          info: rule == null
              ? 'Recurring'
              : '${_m(rule.amount)} ${rule.frequency.toLowerCase()}',
          items: items,
        ),
      );
    }

    double sum(Iterable<_DueGroup> gs) => gs.fold<double>(
      0,
      (s, g) => s + g.items.fold<double>(0, (a, t) => a + t.amount),
    );
    final interestTotal = sum(loanBlocks);
    final recurringTotal = sum(recBlocks);
    final total = interestTotal + recurringTotal;

    final widgets = <pw.Widget>[];
    widgets.add(
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: _card(
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _cardTitle('TO', _orangeDark),
                  pw.Text(
                    customer.name,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  _kv(
                    'Phone',
                    customer.phoneNumber.isNotEmpty
                        ? customer.phoneNumber
                        : '-',
                  ),
                ],
              ),
            ),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: _card(
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _cardTitle('AMOUNT DUE NOW', _orange),
                  pw.Text(
                    _m(total),
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: total > 0 ? _red : _green,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    [
                      if (interestTotal > 0) 'Interest ${_m(interestTotal)}',
                      if (recurringTotal > 0) 'Recurring ${_m(recurringTotal)}',
                    ].join(' + '),
                    style: const pw.TextStyle(fontSize: 9, color: _grey),
                  ),
                ],
              ),
              color: _orangeBg,
            ),
          ),
        ],
      ),
    );

    if (total <= 0) {
      widgets.add(pw.SizedBox(height: 20));
      widgets.add(
        _card(
          pw.Text(
            'No interest or recurring payments are pending.',
            style: const pw.TextStyle(fontSize: 12),
          ),
        ),
      );
      return widgets;
    }

    widgets.add(pw.SizedBox(height: 16));
    widgets.add(
      pw.Text(
        'Dear ${customer.name}, this is a gentle reminder for the payments '
        'listed below. Kindly clear them at the earliest.',
        style: const pw.TextStyle(fontSize: 11),
      ),
    );

    final allGroups = [...loanBlocks, ...recBlocks];
    if (allGroups.length > 1) {
      widgets.add(_h2('What this is made up of'));
      widgets.add(
        pw.Table(
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(1.4),
          },
          border: const pw.TableBorder(
            horizontalInside: pw.BorderSide(color: _line, width: 0.5),
          ),
          children: [
            for (final g in allGroups) _sumRow(g.title, _n(g.total)),
            _sumRow(
              'Total due now',
              _n(total),
              bold: true,
              color: _red,
              bg: _totBg,
            ),
          ],
        ),
      );
    }

    pw.Widget block(
      _DueGroup g,
      PdfColor bg,
      String firstHead,
      String dateHead,
    ) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 12),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: bg,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              '${g.title}   ${g.info}',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(1.6),
              1: const pw.FlexColumnWidth(4),
              2: const pw.FlexColumnWidth(1.4),
              3: const pw.FlexColumnWidth(1.6),
            },
            border: const pw.TableBorder(
              horizontalInside: pw.BorderSide(color: _line, width: 0.5),
            ),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _headBg),
                children: [
                  _head(dateHead),
                  _head(firstHead),
                  _head('Days pending', right: true),
                  _head('Amount', right: true),
                ],
              ),
              for (final t in g.items)
                pw.TableRow(
                  children: [
                    _cell(_d(t.date)),
                    _cell(_desc(t.notes, '-')),
                    _cell('${daysPending(t)}', right: true),
                    _cell(_n(t.amount), right: true, bold: true),
                  ],
                ),
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _totBg),
                children: [
                  _cell(''),
                  _cell('${g.title} due', bold: true),
                  _cell(''),
                  _cell(_n(g.total), right: true, bold: true, color: _red),
                ],
              ),
            ],
          ),
        ],
      );
    }

    if (loanBlocks.isNotEmpty) {
      widgets.add(_h2('Interest due', '${loanBlocks.length} loan(s)'));
      for (final g in loanBlocks) {
        widgets.add(block(g, _orangeBg, 'Interest for', 'Date'));
      }
    }
    if (recBlocks.isNotEmpty) {
      widgets.add(
        _h2('Recurring payments due', '${recBlocks.length} charge(s)'),
      );
      for (final g in recBlocks) {
        widgets.add(block(g, _purpleBg, 'Description', 'Due date'));
      }
    }

    widgets.add(
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 18),
        child: pw.Text(
          'This request covers pending interest and recurring payments only. '
          'Loan principal is not part of this request. Computer-generated; no '
          'signature required.',
          style: const pw.TextStyle(fontSize: 8, color: _grey),
        ),
      ),
    );
    return widgets;
  }

  // ---------------------------------------------------------------------
  // Shared widgets
  // ---------------------------------------------------------------------
  static pw.Widget _banner(
    String title,
    String subtitle,
    PdfColor color,
    DateTime now,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                subtitle,
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.white),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Date',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.white),
              ),
              pw.Text(
                _d(now),
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _card(pw.Widget child, {PdfColor? color}) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: color,
        border: pw.Border.all(color: _line),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: child,
    );
  }

  static pw.Widget _cardTitle(String text, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: color,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  static pw.Widget _kv(String k, String v) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(k, style: const pw.TextStyle(fontSize: 9, color: _grey)),
          pw.Text(v, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  static pw.Widget _h2(String title, [String? sub]) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 20, bottom: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: _indigo,
              letterSpacing: 0.6,
            ),
          ),
          if (sub != null)
            pw.Text(sub, style: const pw.TextStyle(fontSize: 8, color: _grey)),
        ],
      ),
    );
  }

  static pw.Widget _head(String t, {bool right = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        t.toUpperCase(),
        textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey800,
        ),
      ),
    );
  }

  static pw.Widget _cell(
    String t, {
    bool right = false,
    bool bold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        t,
        textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  static pw.TableRow _sumRow(
    String label,
    String value, {
    bool bold = false,
    PdfColor? color,
    PdfColor? bg,
  }) {
    return pw.TableRow(
      decoration: bg == null ? null : pw.BoxDecoration(color: bg),
      children: [
        _cell(label, bold: bold),
        _cell(value, right: true, bold: bold, color: color),
      ],
    );
  }

  static pw.Widget _table({
    required List<String> headers,
    required Set<int> rightCols,
    required List<double> flex,
    required List<List<pw.Widget>> rows,
  }) {
    return pw.Table(
      columnWidths: {
        for (var i = 0; i < flex.length; i++) i: pw.FlexColumnWidth(flex[i]),
      },
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _line, width: 0.5),
      ),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _headBg),
          children: [
            for (var i = 0; i < headers.length; i++)
              _head(headers[i], right: rightCols.contains(i)),
          ],
        ),
        for (final r in rows) pw.TableRow(children: r),
      ],
    );
  }

  static pw.TableRow _txRow(
    String date,
    String desc,
    _Tag? tag,
    String? debit,
    String? credit,
    String balance, {
    PdfColor? bg,
  }) {
    return pw.TableRow(
      decoration: bg == null ? null : pw.BoxDecoration(color: bg),
      children: [
        _cell(date),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: pw.Wrap(
            crossAxisAlignment: pw.WrapCrossAlignment.center,
            spacing: 5,
            runSpacing: 2,
            children: [
              pw.Text(desc, style: const pw.TextStyle(fontSize: 9)),
              if (tag != null)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: pw.BoxDecoration(
                    color: tag.bg,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    tag.text,
                    style: pw.TextStyle(fontSize: 6.5, color: tag.fg),
                  ),
                ),
            ],
          ),
        ),
        _cell(debit ?? '', right: true),
        _cell(credit ?? '', right: true, color: _green),
        _cell(balance, right: true),
      ],
    );
  }

  static String _desc(String? notes, String fallback) =>
      (notes != null && notes.trim().isNotEmpty) ? notes.trim() : fallback;

  static String _title(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 12),
      child: pw.Text(
        'Page ${context.pageNumber} of ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 9, color: _grey),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// Ledger classification helpers
// ----------------------------------------------------------------------

enum _Kind { given, principal, interest, recurring, payment }

class _Tag {
  final String text;
  final PdfColor fg;
  final PdfColor bg;
  _Tag(this.text, this.fg, this.bg);
}

class _DueGroup {
  final String title;
  final String info;
  final List<Transaction> items;
  _DueGroup({required this.title, required this.info, required this.items});
  double get total => items.fold<double>(0, (s, t) => s + t.amount);
}

class _RecurringGroup {
  final String parentId;
  final String name;
  final List<Transaction> entries; // sorted by date ascending
  _RecurringGroup(this.parentId, this.name, this.entries);
}

/// Splits a customer's transactions into regular entries, interest-bearing
/// loans with their interest entries, and recurring-charge entries.
class _Ledger {
  late final Map<String, Transaction> byId;

  /// Visible, non-excluded entries sorted by date (recurring "template"
  /// parents are not real entries and are left out).
  late final List<Transaction> txs;
  late final List<Transaction> loans;
  late final List<_RecurringGroup> recurringGroups;

  _Ledger(List<Transaction> all) {
    byId = {for (final t in all) t.id: t};
    txs = all.where((t) => !t.isRecurringParent && !t.isExcluded).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    loans = txs
        .where(
          (t) =>
              t.type == 'GAVE' &&
              t.interestRate != null &&
              t.parentTransactionId == null &&
              !(t.isInterestEntry ?? false),
        )
        .toList();

    final groups = <String, List<Transaction>>{};
    for (final t in txs) {
      final p = t.parentTransactionId == null
          ? null
          : byId[t.parentTransactionId];
      if (p != null && p.isRecurringParent) {
        groups.putIfAbsent(p.id, () => []).add(t);
      }
    }
    recurringGroups = [
      for (final e in groups.entries)
        _RecurringGroup(
          e.key,
          (byId[e.key]?.notes?.trim().isNotEmpty ?? false)
              ? byId[e.key]!.notes!.trim()
              : 'Recurring',
          e.value,
        ),
    ];
  }

  bool _isLoan(Transaction? t) =>
      t != null &&
      t.interestRate != null &&
      t.parentTransactionId == null &&
      !(t.isInterestEntry ?? false);

  _Kind kindOf(Transaction t) {
    if (t.type == 'GOT') return _Kind.payment;
    final p = t.parentTransactionId == null
        ? null
        : byId[t.parentTransactionId];
    if (p != null && p.isRecurringParent) return _Kind.recurring;
    if ((t.isInterestEntry ?? false) || _isLoan(p)) return _Kind.interest;
    if (_isLoan(t)) return _Kind.principal;
    return _Kind.given;
  }

  List<Transaction> interestEntriesOf(Transaction loan) => txs
      .where(
        (t) =>
            t.parentTransactionId == loan.id &&
            t.type == 'GAVE' &&
            kindOf(t) == _Kind.interest,
      )
      .toList();

  /// "Loan 2 - phone purchase". Numbered by loan date so that loans with the
  /// same note can still be told apart.
  String loanLabel(Transaction loan) {
    final n = loans.indexOf(loan) + 1;
    final note = loan.notes?.trim() ?? '';
    return note.isEmpty ? 'Loan $n' : 'Loan $n - $note';
  }

  String interestTag(Transaction t) {
    final p = t.parentTransactionId == null
        ? null
        : byId[t.parentTransactionId];
    if (p != null && _isLoan(p)) {
      return 'Interest - Loan ${loans.indexOf(p) + 1}';
    }
    return 'Interest';
  }

  RecurringTransaction? ruleFor(
    String parentId,
    List<RecurringTransaction> rules,
  ) {
    for (final r in rules) {
      if (r.linkedTransactionId == parentId) return r;
    }
    return null;
  }
}

class _PdfGenerationParams {
  final Customer customer;
  final List<Transaction> transactions;
  final List<RecurringTransaction> recurringRules;
  final PdfConfig config;
  final pw.Font font;
  final pw.Font bold;

  _PdfGenerationParams({
    required this.customer,
    required this.transactions,
    required this.recurringRules,
    required this.config,
    required this.font,
    required this.bold,
  });
}
