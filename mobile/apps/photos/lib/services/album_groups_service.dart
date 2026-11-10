import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AlbumGroup {
  const AlbumGroup({
    required this.id,
    required this.name,
    required this.collectionIDs,
  });

  final String id;
  final String name;
  final Set<int> collectionIDs;

  AlbumGroup copyWith({String? name, Set<int>? collectionIDs}) => AlbumGroup(
    id: id,
    name: name ?? this.name,
    collectionIDs: collectionIDs ?? this.collectionIDs,
  );
}

/// Device-local grouping metadata. Ente's server collection API has no
/// parent/group relation, so this stays isolated from account sync metadata.
class AlbumGroupsService {
  AlbumGroupsService._();

  static final AlbumGroupsService instance = AlbumGroupsService._();
  static const _storageKey = 'ente_gallery.album_groups.v1';

  Future<List<AlbumGroup>> getGroups() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((value) {
        final map = value as Map<String, dynamic>;
        return AlbumGroup(
          id: map['id'] as String,
          name: map['name'] as String,
          collectionIDs: (map['collectionIDs'] as List<dynamic>)
              .map((id) => id as int)
              .toSet(),
        );
      }).toList();
    } on Object {
      // A malformed local preference should not prevent the gallery opening.
      return const [];
    }
  }

  Future<void> saveGroup(AlbumGroup group) async {
    final groups = (await getGroups()).toList();
    final index = groups.indexWhere((item) => item.id == group.id);
    if (index == -1) {
      groups.add(group);
    } else {
      groups[index] = group;
    }
    await _write(groups);
  }

  Future<void> deleteGroup(String groupID) async {
    final groups = (await getGroups())
        .where((group) => group.id != groupID)
        .toList();
    await _write(groups);
  }

  Future<void> _write(List<AlbumGroup> groups) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(
        groups
            .map(
              (group) => {
                'id': group.id,
                'name': group.name,
                'collectionIDs': group.collectionIDs.toList()..sort(),
              },
            )
            .toList(),
      ),
    );
  }
}
