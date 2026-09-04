import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/consent_provider.dart' show searchEnabledProvider;
import 'domain/search_date.dart' show MediaTypeFilter;
import 'search_providers.dart';
import 'widgets/filter_bar.dart';
import 'widgets/idle_body.dart';
import 'widgets/results_body.dart';
import 'widgets/search_field.dart';

/// Metadata + content search (`/search`, the second bottom-nav tab). Searches
/// the library by capture date ("June 2026", "2026"), media type, favorites,
/// album name, and — when content search is enabled — on-device ML labels.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Restore a query that outlived this State (a fresh branch build, or a chip
    // set while the tab was away) so the field matches what's being searched.
    _controller.text = ref.read(searchQueryProvider);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Debounces text edits so the date parse / album match only run once typing
  /// settles.
  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      ref.read(searchQueryProvider.notifier).set(value);
    });
  }

  /// A browse chip commits its label immediately (no debounce) and mirrors it
  /// into the field so the two never diverge.
  void _search(String value) {
    _debounce?.cancel();
    _controller.text = value;
    ref.read(searchQueryProvider.notifier).set(value);
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    ref.read(searchQueryProvider.notifier).set('');
  }

  @override
  Widget build(BuildContext context) {
    // Keep the keyboard from lingering over another branch when the user
    // leaves Search; do not auto-focus on entry so the idle screen opens calm.
    ref.listen<bool>(searchTabActiveProvider, (_, active) {
      if (!active) _focusNode.unfocus();
    });

    final query = ref.watch(searchQueryProvider);
    final type = ref.watch(searchTypeProvider);
    final favoritesOnly = ref.watch(searchFavoritesOnlyProvider);
    final albums = ref.watch(searchAlbumsProvider);
    final people = ref.watch(searchPeopleProvider);

    final idle =
        query.trim().isEmpty && type == MediaTypeFilter.all && !favoritesOnly;

    // The field mirrors the query through its controller, so it doesn't
    // rebuild on every keystroke — only the hint depends on a provider,
    // and only on whether content search is enabled. Watch that one
    // provider in a Consumer scoped to the field so a keystroke (which
    // ticks searchQueryProvider) doesn't rebuild it.
    final searchField = Consumer(
      builder: (context, ref, _) => SearchField(
        controller: _controller,
        focusNode: _focusNode,
        onChanged: _onChanged,
        onClear: _clear,
        // The hint only promises content matching when the user has
        // actually enabled it — otherwise typing "dog" would silently
        // return nothing after the field invited it.
        hintText: ref.watch(searchEnabledProvider).value ?? false
            ? 'Photos, places, people, text…'
            : 'Dates, albums, media type…',
      ),
    );

    final filterBar = FilterBar(type: type, favoritesOnly: favoritesOnly);

    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: idle
          ? IdleBody(
              searchField: searchField,
              filterBar: filterBar,
              onBrowseLabel: _search,
            )
          : ResultsBody(
              searchField: searchField,
              filterBar: filterBar,
              albums: albums,
              people: people,
            ),
    );
  }
}
