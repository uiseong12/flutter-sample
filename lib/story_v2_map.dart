import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class StoryMapNode {
  final String id;
  final int chapter;
  final double x;
  final double y;
  final String type;
  final String file;

  StoryMapNode({
    required this.id,
    required this.chapter,
    required this.x,
    required this.y,
    required this.type,
    required this.file,
  });

  factory StoryMapNode.fromJson(Map<String, dynamic> j) => StoryMapNode(
        id: j['id'] as String,
        chapter: j['chapter'] as int,
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        type: j['type'] as String,
        file: (j['file'] ?? '') as String,
      );
}

class StoryMapEdge {
  final String from;
  final String to;
  final String choiceId;
  final String label;

  StoryMapEdge({
    required this.from,
    required this.to,
    required this.choiceId,
    required this.label,
  });

  factory StoryMapEdge.fromJson(Map<String, dynamic> j) => StoryMapEdge(
        from: j['from'] as String,
        to: j['to'] as String,
        choiceId: j['choiceId'] as String,
        label: (j['label'] ?? '') as String,
      );
}

class StoryMapData {
  final String title;
  final List<StoryMapNode> nodes;
  final List<StoryMapEdge> edges;
  final Map<String, String> routeNodesAtCh26;

  StoryMapData({
    required this.title,
    required this.nodes,
    required this.edges,
    required this.routeNodesAtCh26,
  });

  factory StoryMapData.fromJson(Map<String, dynamic> j) => StoryMapData(
        title: j['title'] as String,
        nodes: (j['nodes'] as List)
            .map((e) => StoryMapNode.fromJson(e as Map<String, dynamic>))
            .toList(),
        edges: (j['edges'] as List)
            .map((e) => StoryMapEdge.fromJson(e as Map<String, dynamic>))
            .toList(),
        routeNodesAtCh26:
            (j['routeNodesAtCh26'] as Map<String, dynamic>? ?? {})
                .map((k, v) => MapEntry(k, v.toString())),
      );
}

class StoryV2MapRepository {
  static const _mapPath = 'assets/story_v2/story_map_layout.json';
  static const _chapterIndexPath = 'assets/story_v2/chapter_node_index.json';

  Future<StoryMapData> loadMap() async {
    final raw = await rootBundle.loadString(_mapPath);
    return StoryMapData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> loadChapterIndex() async {
    final raw = await rootBundle.loadString(_chapterIndexPath);
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}
