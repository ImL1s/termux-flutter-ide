import 'package:flutter/material.dart';
import 'git_service.dart';

/// Represents a node in the visual Git graph
class GitGraphNode {
  final GitCommit commit;
  final int lane;
  final List<GitConnection> connections;

  GitGraphNode({
    required this.commit,
    required this.lane,
    required this.connections,
  });
}

/// Represents a line connection between nodes in the graph
class GitConnection {
  final int fromLane;
  final int toLane;
  final ConnectionType type;

  GitConnection({
    required this.fromLane,
    required this.toLane,
    required this.type,
  });
}

enum ConnectionType {
  straight, // Vertical line in same lane
  join, // Moving from another lane to this one (merge)
  split, // Moving from this lane to another (branch)
}

class GitGraphLayouter {
  /// Processes raw commits into graph nodes with lane information
  static List<GitGraphNode> layout(List<GitCommit> commits) {
    if (commits.isEmpty) return [];

    final List<GitGraphNode> nodes = [];
    final List<String?> currentLanes =
        []; // index -> hash (waiting for this hash)

    for (int i = 0; i < commits.length; i++) {
      final commit = commits[i];
      int nodeLane = -1;

      // 1. Find if this commit belongs to an existing lane
      for (int l = 0; l < currentLanes.length; l++) {
        if (currentLanes[l] == commit.hash) {
          nodeLane = l;
          currentLanes[l] = null; // Consume this lane entry
          break;
        }
      }

      // 2. If not found, it's a new "head" (like a new remote branch or detached head)
      if (nodeLane == -1) {
        // Find first empty lane or append
        nodeLane = currentLanes.indexOf(null);
        if (nodeLane == -1) {
          nodeLane = currentLanes.length;
          currentLanes.add(null);
        }
      }

      final connections = <GitConnection>[];

      // 3. Handle parents and connections
      if (commit.parents.isNotEmpty) {
        // First parent stays in the current lane (or follows it)
        final firstParent = commit.parents[0];
        currentLanes[nodeLane] = firstParent;
        connections.add(GitConnection(
          fromLane: nodeLane,
          toLane: nodeLane,
          type: ConnectionType.straight,
        ));

        // Additional parents (merges)
        for (int p = 1; p < commit.parents.length; p++) {
          final parentHash = commit.parents[p];

          // Find or create a lane for this branch
          int parentLane = currentLanes.indexOf(null);
          if (parentLane == -1) {
            parentLane = currentLanes.length;
            currentLanes.add(null);
          }
          currentLanes[parentLane] = parentHash;

          connections.add(GitConnection(
            fromLane: nodeLane,
            toLane: parentLane,
            type: ConnectionType.split,
          ));
        }
      }

      nodes.add(GitGraphNode(
        commit: commit,
        lane: nodeLane,
        connections: connections,
      ));
    }

    return nodes;
  }

  /// Helper to get a consistent color for a lane index
  static Color getLaneColor(int laneIndex) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.cyan,
      Colors.amber,
    ];
    return colors[laneIndex % colors.length];
  }
}
