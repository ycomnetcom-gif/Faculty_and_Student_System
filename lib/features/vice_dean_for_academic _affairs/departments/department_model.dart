import 'dart:convert';

class Department {
  final int? id;
  final String? firestoreId;
  final String name;
  final String headId;
  final String headName;
  final int sync;
  final String? createdAt; // ISO-8601 creation timestamp
  final int levelsCount;
  final bool hasTracks;
  final List<String> tracks;
  final int? startLevelForTracks;

  Department({
    this.id,
    this.firestoreId,
    required this.name,
    required this.headId,
    required this.headName,
    required this.sync,
    this.createdAt,
    this.levelsCount = 4,
    this.hasTracks = false,
    this.tracks = const [],
    this.startLevelForTracks,
  });

  // تحويل الكائن إلى Map لتخزينه في SQLite
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (firestoreId != null) 'firestore_id': firestoreId,
      'name': name,
      'head_id': headId,
      'head_name': headName,
      'sync': sync,
      if (createdAt != null) 'created_at': createdAt,
      'levels_count': levelsCount,
      'has_tracks': hasTracks ? 1 : 0,
      'tracks': jsonEncode(tracks),
      'start_level_for_tracks': startLevelForTracks,
    };
  }

  // إنشاء كائن من Map مسترجع من SQLite
  factory Department.fromMap(Map<String, dynamic> map) {
    List<String> parseTracks(dynamic tracksVal) {
      if (tracksVal == null) return [];
      if (tracksVal is List) return tracksVal.cast<String>();
      if (tracksVal is String) {
        if (tracksVal.trim().isEmpty) return [];
        try {
          final decoded = jsonDecode(tracksVal);
          if (decoded is List) return decoded.cast<String>();
        } catch (_) {
          return tracksVal.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
        }
      }
      return [];
    }

    return Department(
      id: map['id'] as int?,
      firestoreId: map['firestore_id'] as String?,
      name: map['name'] as String? ?? '',
      headId: map['head_id'] as String? ?? '',
      headName: map['head_name'] as String? ?? '',
      sync: map['sync'] as int? ?? 0,
      createdAt: map['created_at'] as String?,
      levelsCount: map['levels_count'] as int? ?? 4,
      hasTracks: (map['has_tracks'] as int? ?? 0) == 1,
      tracks: parseTracks(map['tracks']),
      startLevelForTracks: map['start_level_for_tracks'] as int?,
    );
  }
}

