/// The [Hero] tag shared between an asset's grid-cell thumbnail and its page
/// in the detail viewer, so tapping a cell flies the photo into place
/// instead of a plain cut, and dismissing flies it back. Namespaced
/// (`asset-`) so it can never collide with the memories cover Hero
/// (`memory-$id`).
String assetHeroTag(String assetId) => 'asset-$assetId';
