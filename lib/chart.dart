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
    // 1) Convert raw timeValue + timeUnit -> tInYears
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
      // 'Years' => no change
    }
    _tInYears = t;

    // 2) Map frequencyStr -> n
    final freqMap = {
      'Daily': 365,
      'Weekly': 52,
      'Monthly': 12,
      'Semi-Annual': 2,
      'Annual': 1,
    };
    _n = freqMap[widget.frequencyStr]!;

    // 3) Compute final amount A = P * (1 + r/n)^(n * t)
    final P = widget.principal;
    final r = widget.annualRatePercent / 100.0;
    _finalAmount = P * pow((1 + r / _n), _n * _tInYears);
    _interestAmount = _finalAmount - P;

    // 4) Build per‐period schedule
    final totalPeriods = (_n * _tInYears).round();
    _schedule = List.generate(totalPeriods, (index) {
      final int i = index + 1;
      final double timeAtPeriod = i / _n; // in years
      final double amountAtPeriod = P * pow((1 + r / _n), i);
      return {
        'period': i,
        'timeYears': timeAtPeriod,
        'amount': amountAtPeriod,
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

    // --- 1) Write header row as CellValue.string(...) ---
    sheet.appendRow([
      TextCellValue('Period'),
      TextCellValue('Time (Years)'),
      TextCellValue('Amount'),
    ]);

    // --- 2) Write each schedule row as CellValue.number(...) or .string(...) ---
    for (var row in _schedule) {
      final int period = row['period'] as int;
      final double tY = row['timeYears'] as double;
      final double amt = row['amount'] as double;

      sheet.appendRow([
        IntCellValue(period),
        DoubleCellValue(double.parse(tY.toStringAsFixed(2))),
        DoubleCellValue(double.parse(amt.toStringAsFixed(widget.precision))),
      ]);
    }

    // --- 3) Add a “Summary” sheet with principal/rate/time/frequency/interest/final ---
    final summarySheet = excel['Summary'];
    summarySheet.appendRow(
        [TextCellValue('Principal'), DoubleCellValue(widget.principal)]);
    summarySheet.appendRow(
        [TextCellValue('Rate (%)'), DoubleCellValue(widget.annualRatePercent)]);
    summarySheet.appendRow([
      TextCellValue('Time (${widget.timeUnit})'),
      DoubleCellValue(widget.timeValue)
    ]);
    summarySheet.appendRow(
        [TextCellValue('Frequency'), TextCellValue(widget.frequencyStr)]);
    summarySheet.appendRow([
      TextCellValue('Interest Earned'),
      DoubleCellValue(_interestAmount),
    ]);
    summarySheet.appendRow([
      TextCellValue('Final Amount'),
      DoubleCellValue(_finalAmount),
    ]);

    // --- 4) Encode and save to a temporary file ---
    final bytes = excel.encode();
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate Excel data')),
      );
      return;
    }

    try {
      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/compound_schedule_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);

      // --- 5) Share that .xlsx file ---
      await Share.shareXFiles(
        [XFile(path)],
        text: 'Compound Interest Schedule',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting to Excel: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Result Summary'),
        actions: [
          IconButton(
            tooltip: 'Export schedule to Excel',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _exportToExcel,
          ),
          IconButton(
            tooltip: 'Share Excel',
            icon: const Icon(Icons.share_outlined),
            onPressed: _exportToExcel,
          ),
          // … (you can keep “Copy” and “Share” icons here as well) …
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildPieChart(),
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Text(
                    'Period',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Time (yr)',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Amount',
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Divider(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ListView.separated(
                itemCount: _schedule.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final row = _schedule[index];
                  final int period = row['period'] as int;
                  final double timeY = row['timeYears'] as double;
                  final double amt = row['amount'] as double;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Text(
                            '$period',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            timeY.toStringAsFixed(2),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            _formatCurrency(amt),
                            textAlign: TextAlign.right,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    final principalSection = PieChartSectionData(
      value: widget.principal,
      title: 'Principal\n${_formatCurrency(widget.principal)}',
      radius: 80,
      titleStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      color: Theme.of(context).colorScheme.primary,
    );
    final interestSection = PieChartSectionData(
      value: _interestAmount,
      title: 'Interest\n${_formatCurrency(_interestAmount)}',
      radius: 80,
      titleStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      color: Theme.of(context).colorScheme.secondary,
    );

    return SizedBox(
      height: 240,
      child: PieChart(
        PieChartData(
          sections: [principalSection, interestSection],
          centerSpaceRadius: 40,
          sectionsSpace: 2,
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}
