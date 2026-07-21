/// The [Hero] tag shared between a memory card's cover and its title card in
/// the player, so opening a memory visibly expands into the story instead of
/// a plain cut. Namespaced (`memory-`) so it can never collide with the
/// asset Hero (`asset-$id`, see `lib/widgets/asset_hero_tag.dart`).
String memoryHeroTag(int memoryId) => 'memory-$memoryId';
