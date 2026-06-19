import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/enums/enums.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/theme/theme.dart';
import '../providers/analytics_providers.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: LitColors.void_,
      appBar: const LitLifeAppBar(title: 'Analytics & Insights', showBack: true),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(analyticsSummaryProvider);
          ref.invalidate(categoryParticipationProvider);
          ref.invalidate(registrationTrendProvider);
          ref.invalidate(branchParticipationProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCards(ref),
              const SizedBox(height: 24),
              _buildRegistrationTrendChart(ref),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildCategoryParticipationChart(ref)),
                ],
              ),
              const SizedBox(height: 24),
              _buildBranchStandingsChart(ref),
              const SizedBox(height: 24),
              _buildInsightCard(ref),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(WidgetRef ref) {
    final summaryAsync = ref.watch(analyticsSummaryProvider);
    
    return summaryAsync.when(
      data: (stats) => Row(
        children: [
          Expanded(
            child: StatCard(
              title: 'Total Regs',
              value: stats['totalRegistrations'].toString(),
              icon: Icons.people_outline,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatCard(
              title: 'Attendance',
              value: '${stats['attendanceRate']}%',
              icon: Icons.check_circle_outline,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatCard(
              title: 'Live Events',
              value: stats['totalEvents'].toString(),
              icon: Icons.event_available,
            ),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator(color: LitColors.ember)),
      error: (_, __) => const SizedBox(),
    );
  }

  Widget _buildRegistrationTrendChart(WidgetRef ref) {
    final trendAsync = ref.watch(registrationTrendProvider);

    return ClayCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Registration Trend',
            style: GoogleFonts.fredoka(
              color: LitColors.bone,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: trendAsync.when(
              data: (trend) {
                if (trend.isEmpty) {
                  return const Center(child: Text('No trend data available', style: TextStyle(color: LitColors.ash)));
                }
                
                final spots = List.generate(trend.length, (i) {
                  return FlSpot(i.toDouble(), (trend[i]['count'] as int).toDouble());
                });

                return LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) => Text(
                            value.toInt().toString(),
                            style: const TextStyle(color: LitColors.ash, fontSize: 10),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= trend.length) return const SizedBox.shrink();
                            final date = DateTime.parse(trend[idx]['date'] as String);
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat('dd/MM').format(date),
                                style: const TextStyle(color: LitColors.ash, fontSize: 9),
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
                        color: LitColors.ember,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              LitColors.ember.withOpacity(0.2),
                              LitColors.ember.withOpacity(0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: LitColors.ember)),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryParticipationChart(WidgetRef ref) {
    final categoryAsync = ref.watch(categoryParticipationProvider);

    return ClayCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Category Distribution',
            style: GoogleFonts.fredoka(
              color: LitColors.bone,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          categoryAsync.when(
            data: (counts) {
              if (counts.isEmpty) {
                return const Center(child: Text('No category data', style: TextStyle(color: LitColors.ash)));
              }

              final total = counts.values.fold<int>(0, (sum, val) => sum + val);
              
              return Row(
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 4,
                        centerSpaceRadius: 35,
                        sections: counts.entries.map((e) {
                          return PieChartSectionData(
                            value: e.value.toDouble(),
                            title: '${(e.value / total * 100).toStringAsFixed(0)}%',
                            color: AppTheme.getCategoryColor(e.key.value),
                            radius: 40,
                            titleStyle: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A0D05),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: counts.entries.map((e) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: AppTheme.getCategoryColor(e.key.value),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  e.key.label,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: LitColors.ash,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              Text(
                                e.value.toString(),
                                style: GoogleFonts.jetBrainsMono(
                                  color: LitColors.bone,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              );
            },
            loading: () => const SizedBox(height: 140, child: Center(child: CircularProgressIndicator(color: LitColors.ember))),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchStandingsChart(WidgetRef ref) {
    final branchAsync = ref.watch(branchParticipationProvider);

    return ClayCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Branch Engagement (Top 5)',
            style: GoogleFonts.fredoka(
              color: LitColors.bone,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: branchAsync.when(
              data: (data) {
                if (data.isEmpty) return const Center(child: Text('No branch data'));
                
                final maxVal = data.values.fold<int>(0, (m, v) => v > m ? v : m).toDouble();
                final entries = data.entries.toList();

                return BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxVal * 1.2,
                    barTouchData: BarTouchData(enabled: true),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= entries.length) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                entries[idx].key,
                                style: const TextStyle(color: LitColors.ash, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(entries.length, (i) {
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: entries[i].value.toDouble(),
                            gradient: const LinearGradient(
                              colors: [LitColors.ember, LitColors.amber],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            width: 20,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          ),
                        ],
                        showingTooltipIndicators: [0],
                      );
                    }),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: LitColors.ember)),
              error: (e, _) => Text('Error: $e'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(WidgetRef ref) {
    final categoryAsync = ref.watch(categoryParticipationProvider);
    final summaryAsync = ref.watch(analyticsSummaryProvider);

    return categoryAsync.when(
      data: (counts) {
        if (counts.isEmpty) return const SizedBox();
        
        final topCategory = counts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        
        final mostPopular = topCategory.first;
        final stats = summaryAsync.value;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [LitColors.ember, LitColors.amber],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: LitColors.ember.withOpacity(0.3),
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
                      'System Insight',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF1A0D05),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${mostPopular.key.label} is currently the most popular category with ${mostPopular.value} registrations. ${stats != null ? "Overall attendance is healthy at ${stats['attendanceRate']}%." : ""}',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF1A0D05).withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }
}
