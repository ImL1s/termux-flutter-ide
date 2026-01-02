import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'analyzer_service.dart';
import 'analyzer_models.dart';
import '../theme/app_theme.dart';

class AnalysisDashboard extends ConsumerWidget {
  const AnalysisDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(analysisReportProvider);

    return Container(
      color: AppTheme.surface,
      child: Column(
        children: [
          _buildHeader(ref),
          Expanded(
            child: reportAsync.when(
              data: (report) =>
                  report == null ? _buildNoProject() : _buildContent(report),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.surfaceVariant)),
      ),
      child: Row(
        children: [
          const Icon(Icons.analytics_outlined,
              color: AppTheme.secondary, size: 20),
          const SizedBox(width: 8),
          const Text(
            'PROJECT HEALTH',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: AppTheme.textSecondary,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: () => ref.invalidate(analysisReportProvider),
            tooltip: 'Refresh Analysis',
          ),
        ],
      ),
    );
  }

  Widget _buildNoProject() {
    return const Center(
      child: Text('Open a project to see analysis',
          style: TextStyle(color: Colors.grey)),
    );
  }

  Widget _buildContent(AnalysisReport report) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildScoreCard(report.maintainabilityScore),
        const SizedBox(height: 16),
        _buildSummaryGrid(report),
        const SizedBox(height: 24),
        const Text(
          'Complex Files (Refactor Candidates)',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.secondary),
        ),
        const SizedBox(height: 12),
        ...report.topComplexFiles.map((f) => _buildFileMetric(f)),
      ],
    );
  }

  Widget _buildScoreCard(double score) {
    final color = score > 80
        ? Colors.green
        : score > 60
            ? Colors.orange
            : Colors.red;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Text('Maintainability Score',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          Text(
            '${score.round()}%',
            style: TextStyle(
                fontSize: 48, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: score / 100,
            backgroundColor: Colors.grey.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(AnalysisReport report) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.8,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _buildSummaryItem(
            'Total LOC', report.totalLoc.toString(), Icons.line_weight),
        _buildSummaryItem('TODOs', report.totalTodos.toString(), Icons.task_alt,
            color: report.totalTodos > 0 ? AppTheme.tertiary : Colors.grey),
        _buildSummaryItem('Files', report.topComplexFiles.length.toString(),
            Icons.insert_drive_file),
        _buildSummaryItem(
            'Warnings', report.totalWarnings.toString(), Icons.warning_amber,
            color: report.totalWarnings > 0 ? Colors.orange : Colors.grey),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon,
      {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color ?? Colors.grey),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFileMetric(FileMetric metric) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.code, size: 16, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.path.split('/').last,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  metric.path,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'C: ${metric.averageComplexity}',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: metric.averageComplexity > 10
                        ? Colors.orange
                        : Colors.grey),
              ),
              Text('${metric.loc} lines',
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}
