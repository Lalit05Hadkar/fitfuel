import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../services/ai_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});
  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final weightCtl = TextEditingController();
  bool coachBusy = false;
  String coachText = '';
  String? coachError;

  @override
  void dispose() {
    weightCtl.dispose();
    super.dispose();
  }

  Future<void> _coach() async {
    final s = context.read<AppState>();
    final ai = context.read<AiService>();
    setState(() {
      coachBusy = true;
      coachError = null;
    });
    try {
      final text = await ai.coach(s.coachSummary());
      setState(() => coachText = text);
    } catch (e) {
      setState(() => coachError = e is AiException ? e.message : "Couldn't reach ${AiService.baseUrl}: $e");
    } finally {
      if (mounted) setState(() => coachBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = s.profile!;
    final t = s.targets;
    final ws = [...p.weights]..sort((a, b) => a.date.compareTo(b.date));
    final cur = ws.isEmpty ? p.weightKg : ws.last.kg;
    final diff = ws.length > 1 ? cur - ws.first.kg : 0.0;
    final week = s.lastWeek;
    final logged = week.where((e) => e.$2.hasFood).length;
    final proteinHit = week.where((e) => e.$2.protein >= t.protein * 0.9).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text('Progress', style: FF.display(26)),
        const SizedBox(height: 12),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Muted('Body weight', size: 12),
                  Text('${one(cur)} kg', style: FF.display(28)),
                  if (p.targetWeightKg != null)
                    Muted('Target ${one(p.targetWeightKg!)} kg · ${one((cur - p.targetWeightKg!).abs())} kg to go', size: 12),
                ]),
              ),
              if (ws.length > 1)
                Panel(
                  radius: 999,
                  color: FF.surface2,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Text('${diff > 0 ? '+' : ''}${one(diff)} kg',
                      style: TextStyle(fontWeight: FontWeight.w600, color: diff <= 0 ? FF.accent : FF.burn)),
                ),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: ws.length < 2
                  ? const Center(child: Muted('Log your weight on two or more days to see the trend.'))
                  : _weightChart(ws.map((w) => w.kg).toList(), ws.first.date, ws.last.date),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: weightCtl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: "Today's weight (kg)", hintText: one(cur)),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(80, 52)),
                onPressed: () {
                  final v = double.tryParse(weightCtl.text.trim());
                  if (v == null || v < 30 || v > 250) {
                    toast(context, 'Enter a weight in kg.');
                    return;
                  }
                  s.logWeight(v);
                  weightCtl.clear();
                  toast(context, 'Weight logged');
                },
                child: const Text('Log'),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Calories, last 7 days', style: FF.display(19)),
            const SizedBox(height: 12),
            SizedBox(height: 160, child: _weekChart(week, t.kcal)),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _tile('Streak', '${s.streak} d')),
          const SizedBox(width: 10),
          Expanded(child: _tile('Days logged', '$logged/7')),
          const SizedBox(width: 10),
          Expanded(child: _tile('Protein hit', '$proteinHit/7')),
        ]),
        const SizedBox(height: 12),
        Panel(
          color: FF.sunk,
          outlined: true,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Icon(Icons.auto_awesome, color: FF.accent),
              const SizedBox(width: 8),
              Text('AI coach', style: FF.display(19)),
            ]),
            const SizedBox(height: 10),
            if (coachText.isEmpty && !coachBusy)
              const Muted('Get tips based on what you actually ate, trained and weighed this week.', size: 14)
            else if (coachBusy)
              const Muted('Reading your week…', size: 14)
            else
              Text(coachText, style: const TextStyle(height: 1.5)),
            if (coachError != null) ...[
              const SizedBox(height: 8),
              Text(coachError!, style: const TextStyle(color: FF.burn)),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: coachBusy ? null : _coach,
              child: Text(coachBusy ? 'Thinking…' : (coachText.isEmpty ? 'Coach me' : 'Ask again')),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _tile(String label, String value) => Panel(
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Muted(label, size: 12),
          Text(value, style: FF.display(22)),
        ]),
      );

  Widget _weightChart(List<double> vals, String firstDate, String lastDate) {
    final minY = vals.reduce((a, b) => a < b ? a : b) - 0.5;
    final maxY = vals.reduce((a, b) => a > b ? a : b) + 0.5;
    final df = DateFormat('d MMM');
    return LineChart(LineChartData(
      minY: minY,
      maxY: maxY,
      gridData: FlGridData(
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => const FlLine(color: FF.line, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            getTitlesWidget: (v, meta) => Text(one(v), style: const TextStyle(color: FF.muted, fontSize: 10)),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: (v, meta) {
              final i = v.round();
              if (i == 0) return Text(df.format(fromKey(firstDate)), style: const TextStyle(color: FF.muted, fontSize: 10));
              if (i == vals.length - 1) return Text(df.format(fromKey(lastDate)), style: const TextStyle(color: FF.muted, fontSize: 10));
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: [for (var i = 0; i < vals.length; i++) FlSpot(i.toDouble(), vals[i])],
          isCurved: true,
          color: FF.accent,
          barWidth: 3,
          dotData: FlDotData(checkToShowDot: (spot, _) => spot.x == vals.length - 1),
          belowBarData: BarAreaData(show: true, color: const Color(0x1FC6F432)),
        ),
      ],
    ));
  }

  Widget _weekChart(List<(String, DayLog)> week, int goal) {
    final today = todayKey();
    final values = [for (final e in week) e.$2.kcal];
    final maxY = [goal * 1.2, ...values].reduce((a, b) => a > b ? a : b);
    return BarChart(BarChartData(
      maxY: maxY,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      extraLinesData: ExtraLinesData(horizontalLines: [
        HorizontalLine(
          y: goal.toDouble(),
          color: FF.muted,
          dashArray: [4, 4],
          label: HorizontalLineLabel(
            show: true,
            alignment: Alignment.topRight,
            style: const TextStyle(color: FF.muted, fontSize: 10),
            labelResolver: (_) => 'goal ${fmt(goal)}',
          ),
        ),
      ]),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, meta) => Text(
              DateFormat('E').format(fromKey(week[v.toInt()].$1)).substring(0, 1),
              style: const TextStyle(color: FF.muted, fontSize: 11),
            ),
          ),
        ),
      ),
      barGroups: [
        for (var i = 0; i < week.length; i++)
          BarChartGroupData(x: i, barRods: [
            BarChartRodData(
              toY: values[i],
              width: 22,
              borderRadius: BorderRadius.circular(6),
              color: values[i] > goal ? FF.burn : (week[i].$1 == today ? FF.accent : FF.surface2),
            ),
          ]),
      ],
    ));
  }
}
