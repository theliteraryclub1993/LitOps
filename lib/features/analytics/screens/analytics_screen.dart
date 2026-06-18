import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Analytics',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            color: const Color(0xFFF3ECE2),
          ),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildRegistrationTrendChart(context),
            const SizedBox(height: 24),
            _buildCategoryParticipationChart(),
            const SizedBox(height: 24),
            _buildInsightCard(),
          ],
        ),
      ),
    );
  }

  // ── Line chart: registrations over the last 7 days ───────────────────────
  Widget _buildRegistrationTrendChart(BuildContext context) {
    const List<FlSpot> spots = [
      FlSpot(0, 12),
      FlSpot(1, 19),
      FlSpot(2, 7),
      FlSpot(3, 15),
      FlSpot(4, 22),
      FlSpot(5, 18),
      FlSpot(6, 25),
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Registration Trend',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFF3ECE2),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: 5,
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: Color(0xFF8C857C),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= days.length) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            days[idx],
                            style: const TextStyle(
                              color: Color(0xFF8C857C),
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Theme.of(context).colorScheme.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Pie chart: category participation ────────────────────────────────────
  Widget _buildCategoryParticipationChart() {
    const dataMap = {
      'Poetry': 35.0,
      'Storytelling': 25.0,
      'Debate': 20.0,
      'Workshop': 12.0,
      'Others': 8.0,
    };

    final sections = dataMap.entries.map((e) {
      return PieChartSectionData(
        value: e.value,
        title: '${e.value.toInt()}%',
        color: _categoryColor(e.key),
        radius: 60,
        titleStyle: const TextStyle(
          color: Color(0xFF1A0D05),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      );
    }).toList();

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Category Participation',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFF3ECE2),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 30,
                sections: sections,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: dataMap.entries.map((e) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _categoryColor(e.key),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    e.key,
                    style: const TextStyle(color: Color(0xFF8C857C), fontSize: 12),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── AI insight card ───────────────────────────────────────────────────────
  Widget _buildInsightCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6A2C), Color(0xFFFFB14D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6A2C).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Color(0xFF1A0D05), size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Insight',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF1A0D05),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Poetry events saw a 22% increase in registrations this month, while debate sessions maintain steady engagement.',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF1A0D05).withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Glassmorphism card helper ─────────────────────────────────────────────
  Widget _glassCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1A18),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF262220), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  // ── Color map for categories ──────────────────────────────────────────────
  Color _categoryColor(String category) {
    switch (category) {
      case 'Poetry':
        return const Color(0xFFFF6A2C); // Ember
      case 'Storytelling':
        return const Color(0xFFFFB14D); // Amber
      case 'Debate':
        return const Color(0xFFEC4899); // Pink
      case 'Workshop':
        return const Color(0xFF6FAE8F); // Moss
      default:
        return const Color(0xFF8C857C); // Ash
    }
  }
}
