import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/enums/enums.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/enums/enums.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/theme/theme.dart';
import '../providers/analytics_providers.dart';
import '../../../core/utils/responsive.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
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
          padding: EdgeInsets.only(
            left: r.pagePadding,
            right: r.pagePadding,
            top: r.h(16),
            bottom: r.listBottomPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCards(context, ref),
              SizedBox(height: r.h(24)),
              _buildRegistrationTrendChart(context, ref),
              SizedBox(height: r.h(24)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildCategoryParticipationChart(context, ref)),
                ],
              ),
              SizedBox(height: r.h(24)),
              _buildBranchStandingsChart(context, ref),
              SizedBox(height: r.h(24)),
              _buildInsightCard(context, ref),
              SizedBox(height: r.h(24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(analyticsSummaryProvider);
    final r = context.r;
    
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
          SizedBox(width: r.w(12)),
          Expanded(
            child: StatCard(
              title: 'Attendance',
              value: '${stats['attendanceRate']}%',
              icon: Icons.check_circle_outline,
            ),
          ),
          SizedBox(width: r.w(12)),
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

  Widget _buildRegistrationTrendChart(BuildContext context, WidgetRef ref) {
    final trendAsync = ref.watch(registrationTrendProvider);
    final r = context.r;

    return ClayCard(
      padding: EdgeInsets.all(r.w(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Registration Trend',
            style: GoogleFonts.fredoka(
              color: LitColors.bone,
              fontSize: r.sp(16),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: r.h(20)),
          SizedBox(
            height: r.h(200),
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
                          reservedSize: r.w(30),
                          getTitlesWidget: (value, meta) => Text(
                            value.toInt().toString(),
                            style: TextStyle(color: LitColors.ash, fontSize: r.sp(10)),
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
                              padding: EdgeInsets.only(top: r.h(8.0)),
                              child: Text(
                                DateFormat('dd/MM').format(date),
                                style: TextStyle(color: LitColors.ash, fontSize: r.sp(9)),
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
                              LitColors.ember.withValues(alpha: 0.2),
                              LitColors.ember.withValues(alpha: 0.0),
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

  Widget _buildCategoryParticipationChart(BuildContext context, WidgetRef ref) {
    final categoryAsync = ref.watch(categoryParticipationProvider);
    final r = context.r;

    return ClayCard(
      padding: EdgeInsets.all(r.w(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Category Distribution',
            style: GoogleFonts.fredoka(
              color: LitColors.bone,
              fontSize: r.sp(16),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: r.h(20)),
          categoryAsync.when(
            data: (counts) {
              if (counts.isEmpty) {
                return const Center(child: Text('No category data', style: TextStyle(color: LitColors.ash)));
              }

              final total = counts.values.fold<int>(0, (sum, val) => sum + val);
              
              return Row(
                children: [
                  SizedBox(
                    width: r.w(140),
                    height: r.w(140),
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 4,
                        centerSpaceRadius: r.w(35),
                        sections: counts.entries.map((e) {
                          return PieChartSectionData(
                            value: e.value.toDouble(),
                            title: '${(e.value / total * 100).toStringAsFixed(0)}%',
                            color: AppTheme.getCategoryColor(e.key.value),
                            radius: r.w(40),
                            titleStyle: TextStyle(
                              fontSize: r.sp(10),
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A0D05),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  SizedBox(width: r.w(20)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: counts.entries.map((e) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: r.h(8.0)),
                          child: Row(
                            children: [
                              Container(
                                width: r.w(10),
                                height: r.w(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.getCategoryColor(e.key.value),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: r.w(8)),
                              Expanded(
                                child: Text(
                                  e.key.label,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: LitColors.ash,
                                    fontSize: r.sp(11),
                                  ),
                                ),
                              ),
                              Text(
                                e.value.toString(),
                                style: GoogleFonts.jetBrainsMono(
                                  color: LitColors.bone,
                                  fontSize: r.sp(11),
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
            loading: () => SizedBox(height: r.h(140), child: const Center(child: CircularProgressIndicator(color: LitColors.ember))),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchStandingsChart(BuildContext context, WidgetRef ref) {
    final branchAsync = ref.watch(branchParticipationProvider);
    final r = context.r;

    return ClayCard(
      padding: EdgeInsets.all(r.w(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Branch Engagement (Top 5)',
            style: GoogleFonts.fredoka(
              color: LitColors.bone,
              fontSize: r.sp(16),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: r.h(24)),
          SizedBox(
            height: r.h(180),
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
                              padding: EdgeInsets.only(top: r.h(8.0)),
                              child: Text(
                                entries[idx].key,
                                style: TextStyle(color: LitColors.ash, fontSize: r.sp(10), fontWeight: FontWeight.bold),
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
                            width: r.w(20),
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

  Widget _buildInsightCard(BuildContext context, WidgetRef ref) {
    final categoryAsync = ref.watch(categoryParticipationProvider);
    final summaryAsync = ref.watch(analyticsSummaryProvider);
    final r = context.r;

    return categoryAsync.when(
      data: (counts) {
        if (counts.isEmpty) return const SizedBox();
        
        final topCategory = counts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        
        final mostPopular = topCategory.first;
        final stats = summaryAsync.value;

        return Container(
          padding: EdgeInsets.all(r.w(20)),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [LitColors.ember, LitColors.amber],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(r.radius(24)),
            boxShadow: [
              BoxShadow(
                color: LitColors.ember.withValues(alpha: 0.3),
                blurRadius: r.radius(16),
                offset: Offset(0, r.h(8)),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, color: const Color(0xFF1A0D05), size: r.icon(32)),
              SizedBox(width: r.w(16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'System Insight',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF1A0D05),
                        fontWeight: FontWeight.bold,
                        fontSize: r.sp(16),
                      ),
                    ),
                    SizedBox(height: r.h(6)),
                    Text(
                      '${mostPopular.key.label} is currently the most popular category with ${mostPopular.value} registrations. ${stats != null ? "Overall attendance is healthy at ${stats['attendanceRate']}%." : ""}',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF1A0D05).withValues(alpha: 0.8),
                        fontSize: r.sp(13),
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
