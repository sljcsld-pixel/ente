import 'package:flutter/material.dart';
import 'package:photos/models/collection/collection.dart';
import 'package:photos/services/album_groups_service.dart';
import 'package:photos/settings/local_settings.dart';
import 'package:photos/ui/collections/flex_grid_view.dart';
import 'package:uuid/uuid.dart';

class AlbumGroupsPage extends StatefulWidget {
  const AlbumGroupsPage({required this.collections, super.key});

  final List<Collection> collections;

  @override
  State<AlbumGroupsPage> createState() => _AlbumGroupsPageState();
}

class _AlbumGroupsPageState extends State<AlbumGroupsPage> {
  late Future<List<AlbumGroup>> _groups;

  List<Collection> get _albums => widget.collections
      .where(
        (collection) =>
            collection.type == CollectionType.album && !collection.isDeleted,
      )
      .toList();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _groups = AlbumGroupsService.instance.getGroups();
    if (mounted) setState(() {});
  }

  Future<void> _createGroup() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New album group'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Group name'),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    final group = AlbumGroup(
      id: const Uuid().v4(),
      name: name.trim(),
      collectionIDs: <int>{},
    );
    await AlbumGroupsService.instance.saveGroup(group);
    _reload();
  }

  Future<void> _openGroup(AlbumGroup group) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _AlbumGroupDetailPage(group: group, albums: _albums),
      ),
    );
    _reload();
  }

  Future<void> _deleteGroup(AlbumGroup group) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete “${group.name}”?'),
        content: const Text('Albums will stay in your library.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;
    await AlbumGroupsService.instance.deleteGroup(group.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Album groups'),
      actions: [
        IconButton(
          tooltip: 'Create group',
          onPressed: _createGroup,
          icon: const Icon(Icons.create_new_folder_outlined),
        ),
      ],
    ),
    body: FutureBuilder<List<AlbumGroup>>(
      future: _groups,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final groups = snapshot.data ?? const <AlbumGroup>[];
        if (groups.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.folder_copy_outlined, size: 48),
                const SizedBox(height: 12),
                const Text('Create groups to organize your albums'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _createGroup,
                  icon: const Icon(Icons.add),
                  label: const Text('Create group'),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            final count = group.collectionIDs
                .where((id) => _albums.any((album) => album.id == id))
                .length;
            return ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(group.name),
              subtitle: Text('$count albums'),
              onTap: () => _openGroup(group),
              trailing: IconButton(
                tooltip: 'Delete group',
                onPressed: () => _deleteGroup(group),
                icon: const Icon(Icons.delete_outline),
              ),
            );
          },
        );
      },
    ),
  );
}

class _AlbumGroupDetailPage extends StatefulWidget {
  const _AlbumGroupDetailPage({required this.group, required this.albums});

  final AlbumGroup group;
  final List<Collection> albums;

  @override
  State<_AlbumGroupDetailPage> createState() => _AlbumGroupDetailPageState();
}

class _AlbumGroupDetailPageState extends State<_AlbumGroupDetailPage> {
  late AlbumGroup _group;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
  }

  Future<void> _manageAlbums() async {
    final updated = await Navigator.of(context).push<AlbumGroup>(
      MaterialPageRoute(
        builder: (_) =>
            _AlbumGroupEditorPage(group: _group, albums: widget.albums),
      ),
    );
    if (updated == null) return;
    await AlbumGroupsService.instance.saveGroup(updated);
    if (mounted) setState(() => _group = updated);
  }

  @override
  Widget build(BuildContext context) {
    final groupedAlbums = widget.albums
        .where((album) => _group.collectionIDs.contains(album.id))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(_group.name),
        actions: [
          IconButton(
            tooltip: 'Manage albums',
            onPressed: _manageAlbums,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: groupedAlbums.isEmpty
          ? const Center(child: Text('Add albums to this group'))
          : CollectionsFlexiGridViewWidget(
              groupedAlbums,
              albumViewType: AlbumViewType.grid,
              bottomPadding: 24,
            ),
    );
  }
}

class _AlbumGroupEditorPage extends StatefulWidget {
  const _AlbumGroupEditorPage({required this.group, required this.albums});

  final AlbumGroup group;
  final List<Collection> albums;

  @override
  State<_AlbumGroupEditorPage> createState() => _AlbumGroupEditorPageState();
}

class _AlbumGroupEditorPageState extends State<_AlbumGroupEditorPage> {
  late final Set<int> _selected = {...widget.group.collectionIDs};

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Choose albums'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            widget.group.copyWith(collectionIDs: _selected),
          ),
          child: const Text('Done'),
        ),
      ],
    ),
    body: ListView.builder(
      itemCount: widget.albums.length,
      itemBuilder: (context, index) {
        final album = widget.albums[index];
        return CheckboxListTile(
          value: _selected.contains(album.id),
          title: Text(album.displayName),
          onChanged: (selected) => setState(() {
            if (selected == true) {
              _selected.add(album.id);
            } else {
              _selected.remove(album.id);
            }
          }),
        );
      },
    ),
  );
}
