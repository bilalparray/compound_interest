import 'package:compounding_calculator/admob.dart';
import 'package:excel/excel.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class ChartPage extends StatefulWidget {
  final double principal;
  final double annualRatePercent;
  final double timeValue;
  final String timeUnit;
  final String frequencyStr;
  final String currency;
  final int precision;

  const ChartPage({
    Key? key,
    required this.principal,
    required this.annualRatePercent,
    required this.timeValue,
    required this.timeUnit,
    required this.frequencyStr,
    required this.currency,
    required this.precision,
  }) : super(key: key);

  @override
  _ChartPageState createState() => _ChartPageState();
}

class _ChartPageState extends State<ChartPage> {
  late final double _tInYears;
  late final int _n;
  late final double _finalAmount;
  late final double _interestAmount;
  late final List<Map<String, dynamic>> _schedule;

  @override
  void initState() {
    super.initState();
    _computeSchedule();
  }

  void _computeSchedule() {
    double t = widget.timeValue;
    switch (widget.timeUnit) {
      case 'Months':
        t /= 12;
        break;
      case 'Weeks':
        t /= 52;
        break;
      case 'Days':
        t /= 365;
        break;
    }
    _tInYears = t;

    final freqMap = {
      'Daily': 365,
      'Weekly': 52,
      'Monthly': 12,
      'Semi-Annual': 2,
      'Annual': 1,
    };
    _n = freqMap[widget.frequencyStr]!;

    final P = widget.principal;
    final r = widget.annualRatePercent / 100.0;
    _finalAmount = P * pow((1 + r / _n), _n * _tInYears);
    _interestAmount = _finalAmount - P;

    final totalPeriods = (_n * _tInYears).round();
    _schedule = List.generate(totalPeriods, (index) {
      final i = index + 1;
      return {
        'period': i,
        'timeYears': i / _n,
        'amount': P * pow((1 + r / _n), i),
      };
    });
  }

  String _formatCurrency(double value) {
    final pattern =
        widget.precision == 0 ? '#,##0' : '#,##0.${'0' * widget.precision}';
    final nf = NumberFormat(pattern, 'en_US');
    return widget.currency + nf.format(value);
  }

  Future<void> _exportToExcel() async {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];
    sheet.appendRow([
      TextCellValue('Period'),
      TextCellValue('Time (Years)'),
      TextCellValue('Amount')
    ]);
    for (var row in _schedule) {
      sheet.appendRow([
        IntCellValue(row['period'] as int),
        DoubleCellValue(
            double.parse((row['timeYears'] as double).toStringAsFixed(2))),
        DoubleCellValue(double.parse(
            (row['amount'] as double).toStringAsFixed(widget.precision))),
      ]);
    }
    final summary = excel['Summary'];
    summary.appendRow(
        [TextCellValue('Principal'), DoubleCellValue(widget.principal)]);
    summary.appendRow(
        [TextCellValue('Rate (%)'), DoubleCellValue(widget.annualRatePercent)]);
    summary.appendRow([
      TextCellValue('Time (${widget.timeUnit})'),
      DoubleCellValue(widget.timeValue)
    ]);
    summary.appendRow(
        [TextCellValue('Frequency'), TextCellValue(widget.frequencyStr)]);
    summary.appendRow(
        [TextCellValue('Interest Earned'), DoubleCellValue(_interestAmount)]);
    summary.appendRow(
        [TextCellValue('Final Amount'), DoubleCellValue(_finalAmount)]);

    final bytes = excel.encode();
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate Excel data')));
      return;
    }
    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/schedule_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles([XFile(path)],
          text: 'Compound Interest Schedule');
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.blueAccent : Colors.blue;
    final secondaryColor = isDark ? Colors.orangeAccent : Colors.orange;

    final principalSection = PieChartSectionData(
        value: widget.principal, color: primaryColor, showTitle: false);
    final interestSection = PieChartSectionData(
        value: _interestAmount, color: secondaryColor, showTitle: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Result Summary'),
        actions: [
          IconButton(
            onPressed: _exportToExcel,
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export to Excel',
          ),
          IconButton(
            onPressed: _exportToExcel,
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Excel',
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(child: AdService().getBannerAdWidget()),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pie chart
            SizedBox(
              height: 240,
              child: PieChart(
                PieChartData(
                  sections: [principalSection, interestSection],
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Legend card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Principal Amount',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(_formatCurrency(widget.principal),
                        style: Theme.of(context).textTheme.titleLarge),
                    const Divider(height: 24),
                    Text('Interest Earned',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(_formatCurrency(_interestAmount),
                        style: Theme.of(context).textTheme.titleLarge),
                    const Divider(height: 24),
                    Text('Total Amount',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(_formatCurrency(_finalAmount),
                        style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // Schedule header
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Text('Period',
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Time (yr)',
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('Amount',
                      textAlign: TextAlign.right,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Divider(),

            // Shrink‐wrapped schedule list
            ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: _schedule.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final row = _schedule[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                          flex: 1,
                          child: Text('${row['period']}',
                              style: Theme.of(context).textTheme.bodyMedium)),
                      Expanded(
                          flex: 2,
                          child: Text(
                              (row['timeYears'] as double).toStringAsFixed(2),
                              style: Theme.of(context).textTheme.bodyMedium)),
                      Expanded(
                          flex: 3,
                          child: Text(_formatCurrency(row['amount'] as double),
                              textAlign: TextAlign.right,
                              style: Theme.of(context).textTheme.bodyMedium)),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
