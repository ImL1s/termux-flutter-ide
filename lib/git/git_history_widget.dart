import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'git_service.dart';
import 'git_graph_logic.dart';
import 'package:intl/intl.dart';

class GitHistoryWidget extends ConsumerWidget {
  const GitHistoryWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(gitHistoryProvider);

    return historyAsync.when(
      data: (commits) {
        if (commits.isEmpty) {
          return const Center(child: Text('No commit history found'));
        }

        final graphNodes = GitGraphLayouter.layout(commits);

        return ListView.builder(
          itemCount: graphNodes.length,
          itemBuilder: (context, index) {
            return _GitCommitRow(
              node: graphNodes[index],
              // Pass context for successor info if needed for drawing lines to next row
              isLast: index == graphNodes.length - 1,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, stack) => Center(child: Text('Error: $e')),
    );
  }
}

class _GitCommitRow extends StatelessWidget {
  final GitGraphNode node;
  final bool isLast;

  const _GitCommitRow({
    required this.node,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final commit = node.commit;
    final date = DateTime.fromMillisecondsSinceEpoch(commit.timestamp * 1000);
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(date);

    return InkWell(
      onTap: () {
        // TODO: Show commit details or diff
      },
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            // Graph Area
            SizedBox(
              width: 60,
              child: CustomPaint(
                painter: GitGraphPainter(
                  lane: node.lane,
                  connections: node.connections,
                ),
                child: Container(),
              ),
            ),
            const SizedBox(width: 8),
            // Commit Info
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          commit.message,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (commit.refs.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        _buildRefsBadge(commit.refs),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        commit.shortHash,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade300,
                          fontFamily: 'JetBrains Mono',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        commit.author,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefsBadge(String refs) {
    // Refs format: (HEAD -> main, origin/main)
    final cleanRefs = refs.replaceAll('(', '').replaceAll(')', '');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.yellow.withOpacity(0.2),
        border: Border.all(color: Colors.yellow.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        cleanRefs,
        style: const TextStyle(fontSize: 9, color: Colors.yellow),
      ),
    );
  }
}

class GitGraphPainter extends CustomPainter {
  final int lane;
  final List<GitConnection> connections;

  GitGraphPainter({
    required this.lane,
    required this.connections,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const laneWidth = 12.0;
    const dotRadius = 4.0;
    final centerY = size.height / 2;

    // 1. Draw connections
    for (final conn in connections) {
      final paint = Paint()
        ..color = GitGraphLayouter.getLaneColor(conn.fromLane)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      final startX = 10.0 + conn.fromLane * laneWidth;
      final endX = 10.0 + conn.toLane * laneWidth;

      if (conn.type == ConnectionType.straight) {
        // Vertical line through this cell
        canvas.drawLine(Offset(startX, 0), Offset(startX, size.height), paint);
      } else if (conn.type == ConnectionType.split) {
        // Line splitting off to a new lane below
        final path = Path();
        path.moveTo(startX, centerY);
        path.quadraticBezierTo(startX, size.height, endX, size.height);
        canvas.drawPath(path, paint);
      }
    }

    // 2. Draw the commit dot
    final dotPaint = Paint()
      ..color = GitGraphLayouter.getLaneColor(lane)
      ..style = PaintingStyle.fill;

    final dotX = 10.0 + lane * laneWidth;
    canvas.drawCircle(Offset(dotX, centerY), dotRadius, dotPaint);

    // Border for dot
    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(dotX, centerY), dotRadius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
