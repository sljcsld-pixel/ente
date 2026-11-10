import 'dart:async';

import 'package:flutter/material.dart';
import 'package:photos/core/configuration.dart';
import 'package:photos/core/event_bus.dart';
import 'package:photos/events/account_configured_event.dart';
import 'package:photos/events/collection_updated_event.dart';
import 'package:photos/events/user_logged_out_event.dart';
import 'package:photos/models/collection/collection.dart';
import 'package:photos/models/collection/collection_items.dart';
import 'package:photos/services/favorites_service.dart';
import 'package:photos/ui/viewer/gallery/collection_page.dart';
import 'package:photos/ui/viewer/gallery/empty_state.dart';

/// A dedicated tab for the account's existing, synced Favorites collection.
class FavoritesTab extends StatefulWidget {
  const FavoritesTab({super.key});

  @override
  State<FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends State<FavoritesTab>
    with AutomaticKeepAliveClientMixin {
  late StreamSubscription<CollectionUpdatedEvent> _collectionUpdates;
  late StreamSubscription<UserLoggedOutEvent> _loggedOut;
  late StreamSubscription<AccountConfiguredEvent> _accountConfigured;
  Future<Collection?>? _favorites;
  int? _favoritesCollectionID;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _collectionUpdates = Bus.instance.on<CollectionUpdatedEvent>().listen((
      event,
    ) {
      if (_favoritesCollectionID == null ||
          event.collectionID == null ||
          event.collectionID == _favoritesCollectionID) {
        _loadFavorites();
      }
    });
    _loggedOut = Bus.instance.on<UserLoggedOutEvent>().listen((_) {
      if (mounted) setState(() => _favorites = null);
    });
    _accountConfigured = Bus.instance.on<AccountConfiguredEvent>().listen((_) {
      _loadFavorites();
    });
  }

  void _loadFavorites() {
    if (!Configuration.instance.hasConfiguredAccount()) return;
    setState(() {
      _favorites = FavoritesService.instance.getFavoritesCollection().then((
        collection,
      ) {
        _favoritesCollectionID = collection?.id;
        return collection;
      });
    });
  }

  @override
  void dispose() {
    _collectionUpdates.cancel();
    _loggedOut.cancel();
    _accountConfigured.cancel();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!Configuration.instance.hasConfiguredAccount()) {
      return const Scaffold(
        body: EmptyState(text: 'Sign in to view favorites'),
      );
    }
    return FutureBuilder<Collection?>(
      future: _favorites,
      builder: (context, snapshot) {
        final collection = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (collection == null) {
          return const Scaffold(body: EmptyState(text: 'No favorites yet'));
        }
        return CollectionPage(CollectionWithThumbnail(collection, null));
      },
    );
  }
}
