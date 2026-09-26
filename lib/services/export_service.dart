import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../core/money.dart';
import '../data/app_database.dart';
import '../models/entities.dart';

class ExportService {
  const ExportService._();

  static Future<File> createBackup(AppDatabase db) async {
    final directory = await getTemporaryDirectory();
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final file = File('${directory.path}/MasterDesk_Backup_$stamp.json');
    await file.writeAsString(await db.exportSnapshotJson(), flush: true);
    return file;
  }

  static Future<void> shareBackup(AppDatabase db) async {
    final file = await createBackup(db);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'MasterDesk backup',
    );
  }

  static Future<void> restoreBackup(AppDatabase db, String path) async {
    final content = await File(path).readAsString();
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Invalid backup');
    }
    await db.restoreSnapshot(decoded);
  }

  static String _csvCell(Object? value) =>
      '"${(value ?? '').toString().replaceAll('"', '""')}"';

  static Future<void> shareOrdersCsv(
    List<RepairOrder> orders,
    String currency,
    String localeCode,
  ) async {
    final rows = <String>[
      ['Number', 'Customer', 'Phone', 'Device', 'Status', 'Total', 'Paid', 'Balance', 'Created UTC']
          .map(_csvCell)
          .join(','),
      ...orders.map(
        (order) => [
          order.displayNumber,
          order.customerName,
          order.customerPhone,
          order.deviceName,
          order.status,
          Money.format(order.totalMinor, currency, localeCode),
          Money.format(order.paidMinor, currency, localeCode),
          Money.format(order.balanceMinor, currency, localeCode),
          order.createdAtUtc.toIso8601String(),
        ].map(_csvCell).join(','),
      ),
    ];
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/MasterDesk_Orders.csv');
    await file.writeAsString('\uFEFF${rows.join('\r\n')}', flush: true);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'MasterDesk orders',
    );
  }

  static Future<Uint8List> buildOrderPdf({
    required RepairOrder order,
    required WorkshopSettings settings,
    required List<Map<String, Object?>> items,
    required bool isRu,
  }) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'));
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      title: order.displayNumber,
      author: 'NEXVIRO',
    );
    String money(int value) => Money.format(value, settings.currency, isRu ? 'ru' : 'en');
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('${context.pageNumber} / ${context.pagesCount}', style: const pw.TextStyle(fontSize: 9)),
        ),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(settings.name, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                if (settings.phone.isNotEmpty) pw.Text(settings.phone),
                if (settings.address.isNotEmpty) pw.Text(settings.address),
              ]),
              pw.Text('MasterDesk', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.SizedBox(height: 28),
          pw.Text(
            isRu ? 'Заказ-наряд ${order.displayNumber}' : 'Repair order ${order.displayNumber}',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            children: [
              _pdfInfoRow(isRu ? 'Клиент' : 'Customer', order.customerName),
              _pdfInfoRow(isRu ? 'Телефон' : 'Phone', order.customerPhone),
              _pdfInfoRow(isRu ? 'Устройство' : 'Device', order.deviceName),
              _pdfInfoRow(isRu ? 'Неисправность' : 'Reported issue', order.problem),
              _pdfInfoRow(isRu ? 'Статус' : 'Status', order.status),
              _pdfInfoRow(isRu ? 'Дата приёма' : 'Received', _date(order.createdAtUtc.toLocal())),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text(isRu ? 'Работы и запчасти' : 'Work and parts', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (items.isEmpty)
            pw.Text(isRu ? 'Позиции не добавлены' : 'No items added')
          else
            pw.TableHelper.fromTextArray(
              headers: [isRu ? 'Наименование' : 'Item', isRu ? 'Кол-во' : 'Qty', isRu ? 'Цена' : 'Price', isRu ? 'Сумма' : 'Amount'],
              data: items.map((item) {
                final qty = item['quantity']! as int;
                final price = item['unit_price_minor']! as int;
                return [item['name'], qty, money(price), money(qty * price)];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue50),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellPadding: const pw.EdgeInsets.all(6),
            ),
          pw.SizedBox(height: 20),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 260,
              child: pw.Column(children: [
                _pdfMoneyRow(isRu ? 'Итого' : 'Total', money(order.totalMinor), bold: true),
                _pdfMoneyRow(isRu ? 'Получено' : 'Paid', money(order.paidMinor)),
                _pdfMoneyRow(isRu ? 'Осталось' : 'Amount due', money(order.balanceMinor), bold: true),
              ]),
            ),
          ),
          pw.SizedBox(height: 36),
          pw.Text(isRu ? 'Подпись клиента: ____________________' : 'Customer signature: ____________________'),
          pw.SizedBox(height: 12),
          pw.Text(isRu ? 'Подпись мастера: ____________________' : 'Technician signature: ____________________'),
          pw.SizedBox(height: 28),
          pw.Text(isRu ? 'Документ создан в MasterDesk · Разработано NEXVIRO' : 'Created with MasterDesk · Developed by NEXVIRO', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        ],
      ),
    );
    return document.save();
  }

  static pw.TableRow _pdfInfoRow(String label, String value) => pw.TableRow(children: [
        pw.Padding(padding: const pw.EdgeInsets.all(7), child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
        pw.Padding(padding: const pw.EdgeInsets.all(7), child: pw.Text(value.isEmpty ? '—' : value)),
      ]);

  static pw.Widget _pdfMoneyRow(String label, String value, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(label, style: bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null),
          pw.Text(value, style: bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null),
        ]),
      );

  static String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  static Future<void> shareOrderPdf({
    required RepairOrder order,
    required WorkshopSettings settings,
    required List<Map<String, Object?>> items,
    required bool isRu,
  }) async {
    final bytes = await buildOrderPdf(order: order, settings: settings, items: items, isRu: isRu);
    await Printing.sharePdf(bytes: bytes, filename: '${order.displayNumber}.pdf');
  }
}
