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
  final double contributionAmount;
  final String contributionFrequencyStr;
  final bool contributionAtBeginning;
  final String currency;
  final int precision;

  const ChartPage({
    super.key,
    required this.principal,
    required this.annualRatePercent,
    required this.timeValue,
    required this.timeUnit,
    required this.frequencyStr,
    required this.contributionAmount,
    required this.contributionFrequencyStr,
    required this.contributionAtBeginning,
    required this.currency,
    required this.precision,
  });

  @override
  State<ChartPage> createState() => ChartPageState();
}

class ChartPageState extends State<ChartPage> {
  late final double _tInYears;
  late final int _n;
  late final double _finalAmount;
  late final double _interestAmount;
  late final double _totalContributed;
  late final List<Map<String, dynamic>> _schedule;

  @override
  void initState() {
    super.initState();
    _computeSchedule();
  }

  int _freqPerYear(String freq) {
    switch (freq) {
      case 'Daily':
        return 365;
      case 'Weekly':
        return 52;
      case 'Monthly':
        return 12;
      case 'Semi-Annual':
        return 2;
      case 'Annual':
        return 1;
      default:
        return 0;
    }
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

    _n = _freqPerYear(widget.frequencyStr);

    final P = widget.principal;
    final r = widget.annualRatePercent / 100.0;
    final ratePerPeriod = r / _n;

    final contribEnabled =
        widget.contributionFrequencyStr != 'None' && widget.contributionAmount > 0;
    final contribFreq = contribEnabled ? _freqPerYear(widget.contributionFrequencyStr) : 0;
    final contribIntervalYears = contribFreq > 0 ? (1.0 / contribFreq) : double.infinity;

    final totalPeriodsExact = _n * _tInYears;
    final fullPeriods = totalPeriodsExact.floor();
    final remainder = totalPeriodsExact - fullPeriods;

    final schedule = <Map<String, dynamic>>[];

    double balance = P;
    double contributed = P;
    double currentTime = 0.0;

    // Contribution timing model (time-based, works even if contribution frequency != comp frequency):
    // - Beginning: apply when contribution time == currentTime
    // - End: apply when contribution time is in (currentTime, nextTime]
    double nextContributionTime = contribEnabled ? 0.0 : double.infinity;
    if (contribEnabled && !widget.contributionAtBeginning) {
      nextContributionTime = contribIntervalYears;
    }

    schedule.add({
      'period': 0,
      'timeYears': 0.0,
      'amount': balance,
      'contributed': contributed,
      'interestToDate': balance - contributed,
    });

    for (int i = 1; i <= fullPeriods; i++) {
      final nextTime = i / _n;

      if (contribEnabled && widget.contributionAtBeginning) {
        while ((nextContributionTime - currentTime).abs() < 1e-12 ||
            nextContributionTime < currentTime + 1e-12) {
          balance += widget.contributionAmount;
          contributed += widget.contributionAmount;
          nextContributionTime += contribIntervalYears;
          if (nextContributionTime > _tInYears + 1e-12) break;
        }
      }

      // Interest accrual over a full compounding period.
      balance *= (1.0 + ratePerPeriod);

      if (contribEnabled && !widget.contributionAtBeginning) {
        while (nextContributionTime <= nextTime + 1e-12) {
          balance += widget.contributionAmount;
          contributed += widget.contributionAmount;
          nextContributionTime += contribIntervalYears;
          if (nextContributionTime > _tInYears + 1e-12) break;
        }
      }

      currentTime = nextTime;
      schedule.add({
        'period': i,
        'timeYears': currentTime,
        'amount': balance,
        'contributed': contributed,
        'interestToDate': balance - contributed,
      });
    }

    // Partial last period (no partial contribution; contributions only occur on their own schedule).
    if (remainder > 1e-12) {
      final factor = pow(1.0 + ratePerPeriod, remainder).toDouble();
      balance *= factor;
      currentTime = _tInYears;
      schedule.add({
        'period': fullPeriods + 1,
        'timeYears': currentTime,
        'amount': balance,
        'contributed': contributed,
        'interestToDate': balance - contributed,
      });
    }

    _schedule = schedule;
    _finalAmount = balance;
    _totalContributed = contributed;
    _interestAmount = _finalAmount - _totalContributed;
  }

  String _formatCurrency(double value) {
    final pattern =
        widget.precision == 0 ? '#,##0' : '#,##0.${'0' * widget.precision}';
    final nf = NumberFormat(pattern, 'en_US');
    return widget.currency + nf.format(value);
  }

  Future<void> _exportToExcelAndShare() async {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];
    sheet.appendRow([
      TextCellValue('Period'),
      TextCellValue('Time (Years)'),
      TextCellValue('Contributed'),
      TextCellValue('Interest To Date'),
      TextCellValue('Balance'),
    ]);
    for (var row in _schedule) {
      sheet.appendRow([
        IntCellValue(row['period'] as int),
        DoubleCellValue(
            double.parse((row['timeYears'] as double).toStringAsFixed(2))),
        DoubleCellValue(double.parse(
            (row['contributed'] as double).toStringAsFixed(widget.precision))),
        DoubleCellValue(double.parse(
            (row['interestToDate'] as double).toStringAsFixed(widget.precision))),
        DoubleCellValue(double.parse(
            (row['amount'] as double).toStringAsFixed(widget.precision))),
      ]);
    }
    final summary = excel['Summary'];
    summary.appendRow(
        [TextCellValue('Principal'), DoubleCellValue(widget.principal)]);
    summary.appendRow([
      TextCellValue('Contribution Amount'),
      DoubleCellValue(widget.contributionAmount)
    ]);
    summary.appendRow([
      TextCellValue('Contribution Frequency'),
      TextCellValue(widget.contributionFrequencyStr)
    ]);
    summary.appendRow([
      TextCellValue('Contribution Timing'),
      TextCellValue(widget.contributionAtBeginning ? 'Beginning' : 'End')
    ]);
    summary.appendRow(
        [TextCellValue('Rate (%)'), DoubleCellValue(widget.annualRatePercent)]);
    summary.appendRow([
      TextCellValue('Time (${widget.timeUnit})'),
      DoubleCellValue(widget.timeValue)
    ]);
    summary.appendRow(
        [TextCellValue('Frequency'), TextCellValue(widget.frequencyStr)]);
    summary.appendRow(
        [TextCellValue('Total Contributed'), DoubleCellValue(_totalContributed)]);
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
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          text: 'Compound Interest Schedule',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.blueAccent : Colors.blue;
    final secondaryColor = isDark ? Colors.orangeAccent : Colors.orange;

    final contributedSection = PieChartSectionData(
        value: _totalContributed, color: primaryColor, showTitle: false);
    final interestSection = PieChartSectionData(
        value: _interestAmount, color: secondaryColor, showTitle: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Result Summary'),
        actions: [
          IconButton(
            onPressed: _exportToExcelAndShare,
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export to Excel',
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(child: AdService().getBannerAdWidget()),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Line chart (balance vs time)
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      color: primaryColor,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      spots: _schedule
                          .map((r) => FlSpot(
                                (r['timeYears'] as double).toDouble(),
                                (r['amount'] as double).toDouble(),
                              ))
                          .toList(),
                    ),
                    LineChartBarData(
                      isCurved: true,
                      color: secondaryColor,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      spots: _schedule
                          .map((r) => FlSpot(
                                (r['timeYears'] as double).toDouble(),
                                (r['contributed'] as double).toDouble(),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendDot(color: primaryColor, label: 'Balance'),
                const SizedBox(width: 16),
                _LegendDot(color: secondaryColor, label: 'Contributed'),
              ],
            ),
            const SizedBox(height: 16),

            // Pie chart
            SizedBox(
              height: 240,
              child: PieChart(
                PieChartData(
                  sections: [contributedSection, interestSection],
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
                    Text('Total Contributed',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(_formatCurrency(_totalContributed),
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
                  child: Text('Balance',
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

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
