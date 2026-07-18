// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $FavoritesTable extends Favorites
    with TableInfo<$FavoritesTable, Favorite> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoritesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
    'asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _favoritedAtMeta = const VerificationMeta(
    'favoritedAt',
  );
  @override
  late final GeneratedColumn<DateTime> favoritedAt = GeneratedColumn<DateTime>(
    'favorited_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [assetId, favoritedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorites';
  @override
  VerificationContext validateIntegrity(
    Insertable<Favorite> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('favorited_at')) {
      context.handle(
        _favoritedAtMeta,
        favoritedAt.isAcceptableOrUnknown(
          data['favorited_at']!,
          _favoritedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_favoritedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {assetId};
  @override
  Favorite map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Favorite(
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_id'],
      )!,
      favoritedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}favorited_at'],
      )!,
    );
  }

  @override
  $FavoritesTable createAlias(String alias) {
    return $FavoritesTable(attachedDatabase, alias);
  }
}

class Favorite extends DataClass implements Insertable<Favorite> {
  /// `photo_manager` asset id.
  final String assetId;
  final DateTime favoritedAt;
  const Favorite({required this.assetId, required this.favoritedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['asset_id'] = Variable<String>(assetId);
    map['favorited_at'] = Variable<DateTime>(favoritedAt);
    return map;
  }

  FavoritesCompanion toCompanion(bool nullToAbsent) {
    return FavoritesCompanion(
      assetId: Value(assetId),
      favoritedAt: Value(favoritedAt),
    );
  }

  factory Favorite.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Favorite(
      assetId: serializer.fromJson<String>(json['assetId']),
      favoritedAt: serializer.fromJson<DateTime>(json['favoritedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'assetId': serializer.toJson<String>(assetId),
      'favoritedAt': serializer.toJson<DateTime>(favoritedAt),
    };
  }

  Favorite copyWith({String? assetId, DateTime? favoritedAt}) => Favorite(
    assetId: assetId ?? this.assetId,
    favoritedAt: favoritedAt ?? this.favoritedAt,
  );
  Favorite copyWithCompanion(FavoritesCompanion data) {
    return Favorite(
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      favoritedAt: data.favoritedAt.present
          ? data.favoritedAt.value
          : this.favoritedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Favorite(')
          ..write('assetId: $assetId, ')
          ..write('favoritedAt: $favoritedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(assetId, favoritedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Favorite &&
          other.assetId == this.assetId &&
          other.favoritedAt == this.favoritedAt);
}

class FavoritesCompanion extends UpdateCompanion<Favorite> {
  final Value<String> assetId;
  final Value<DateTime> favoritedAt;
  final Value<int> rowid;
  const FavoritesCompanion({
    this.assetId = const Value.absent(),
    this.favoritedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FavoritesCompanion.insert({
    required String assetId,
    required DateTime favoritedAt,
    this.rowid = const Value.absent(),
  }) : assetId = Value(assetId),
       favoritedAt = Value(favoritedAt);
  static Insertable<Favorite> custom({
    Expression<String>? assetId,
    Expression<DateTime>? favoritedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (assetId != null) 'asset_id': assetId,
      if (favoritedAt != null) 'favorited_at': favoritedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FavoritesCompanion copyWith({
    Value<String>? assetId,
    Value<DateTime>? favoritedAt,
    Value<int>? rowid,
  }) {
    return FavoritesCompanion(
      assetId: assetId ?? this.assetId,
      favoritedAt: favoritedAt ?? this.favoritedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (favoritedAt.present) {
      map['favorited_at'] = Variable<DateTime>(favoritedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoritesCompanion(')
          ..write('assetId: $assetId, ')
          ..write('favoritedAt: $favoritedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AlbumsTable extends Albums with TableInfo<$AlbumsTable, Album> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AlbumsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coverAssetIdMeta = const VerificationMeta(
    'coverAssetId',
  );
  @override
  late final GeneratedColumn<String> coverAssetId = GeneratedColumn<String>(
    'cover_asset_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortIndexMeta = const VerificationMeta(
    'sortIndex',
  );
  @override
  late final GeneratedColumn<int> sortIndex = GeneratedColumn<int>(
    'sort_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    coverAssetId,
    createdAt,
    sortIndex,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'albums';
  @override
  VerificationContext validateIntegrity(
    Insertable<Album> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('cover_asset_id')) {
      context.handle(
        _coverAssetIdMeta,
        coverAssetId.isAcceptableOrUnknown(
          data['cover_asset_id']!,
          _coverAssetIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('sort_index')) {
      context.handle(
        _sortIndexMeta,
        sortIndex.isAcceptableOrUnknown(data['sort_index']!, _sortIndexMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Album map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Album(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      coverAssetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_asset_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      sortIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_index'],
      )!,
    );
  }

  @override
  $AlbumsTable createAlias(String alias) {
    return $AlbumsTable(attachedDatabase, alias);
  }
}

class Album extends DataClass implements Insertable<Album> {
  final int id;
  final String name;

  /// Optional cover; a `photo_manager` asset id.
  final String? coverAssetId;
  final DateTime createdAt;
  final int sortIndex;
  const Album({
    required this.id,
    required this.name,
    this.coverAssetId,
    required this.createdAt,
    required this.sortIndex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || coverAssetId != null) {
      map['cover_asset_id'] = Variable<String>(coverAssetId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['sort_index'] = Variable<int>(sortIndex);
    return map;
  }

  AlbumsCompanion toCompanion(bool nullToAbsent) {
    return AlbumsCompanion(
      id: Value(id),
      name: Value(name),
      coverAssetId: coverAssetId == null && nullToAbsent
          ? const Value.absent()
          : Value(coverAssetId),
      createdAt: Value(createdAt),
      sortIndex: Value(sortIndex),
    );
  }

  factory Album.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Album(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      coverAssetId: serializer.fromJson<String?>(json['coverAssetId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      sortIndex: serializer.fromJson<int>(json['sortIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'coverAssetId': serializer.toJson<String?>(coverAssetId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'sortIndex': serializer.toJson<int>(sortIndex),
    };
  }

  Album copyWith({
    int? id,
    String? name,
    Value<String?> coverAssetId = const Value.absent(),
    DateTime? createdAt,
    int? sortIndex,
  }) => Album(
    id: id ?? this.id,
    name: name ?? this.name,
    coverAssetId: coverAssetId.present ? coverAssetId.value : this.coverAssetId,
    createdAt: createdAt ?? this.createdAt,
    sortIndex: sortIndex ?? this.sortIndex,
  );
  Album copyWithCompanion(AlbumsCompanion data) {
    return Album(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      coverAssetId: data.coverAssetId.present
          ? data.coverAssetId.value
          : this.coverAssetId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      sortIndex: data.sortIndex.present ? data.sortIndex.value : this.sortIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Album(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('coverAssetId: $coverAssetId, ')
          ..write('createdAt: $createdAt, ')
          ..write('sortIndex: $sortIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, coverAssetId, createdAt, sortIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Album &&
          other.id == this.id &&
          other.name == this.name &&
          other.coverAssetId == this.coverAssetId &&
          other.createdAt == this.createdAt &&
          other.sortIndex == this.sortIndex);
}

class AlbumsCompanion extends UpdateCompanion<Album> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> coverAssetId;
  final Value<DateTime> createdAt;
  final Value<int> sortIndex;
  const AlbumsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.coverAssetId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.sortIndex = const Value.absent(),
  });
  AlbumsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.coverAssetId = const Value.absent(),
    required DateTime createdAt,
    this.sortIndex = const Value.absent(),
  }) : name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<Album> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? coverAssetId,
    Expression<DateTime>? createdAt,
    Expression<int>? sortIndex,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (coverAssetId != null) 'cover_asset_id': coverAssetId,
      if (createdAt != null) 'created_at': createdAt,
      if (sortIndex != null) 'sort_index': sortIndex,
    });
  }

  AlbumsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? coverAssetId,
    Value<DateTime>? createdAt,
    Value<int>? sortIndex,
  }) {
    return AlbumsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      coverAssetId: coverAssetId ?? this.coverAssetId,
      createdAt: createdAt ?? this.createdAt,
      sortIndex: sortIndex ?? this.sortIndex,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (coverAssetId.present) {
      map['cover_asset_id'] = Variable<String>(coverAssetId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (sortIndex.present) {
      map['sort_index'] = Variable<int>(sortIndex.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AlbumsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('coverAssetId: $coverAssetId, ')
          ..write('createdAt: $createdAt, ')
          ..write('sortIndex: $sortIndex')
          ..write(')'))
        .toString();
  }
}

class $AlbumEntriesTable extends AlbumEntries
    with TableInfo<$AlbumEntriesTable, AlbumEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AlbumEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _albumIdMeta = const VerificationMeta(
    'albumId',
  );
  @override
  late final GeneratedColumn<int> albumId = GeneratedColumn<int>(
    'album_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES albums (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
    'asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, albumId, assetId, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'album_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<AlbumEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('album_id')) {
      context.handle(
        _albumIdMeta,
        albumId.isAcceptableOrUnknown(data['album_id']!, _albumIdMeta),
      );
    } else if (isInserting) {
      context.missing(_albumIdMeta);
    }
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {albumId, assetId},
  ];
  @override
  AlbumEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AlbumEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      albumId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}album_id'],
      )!,
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_id'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $AlbumEntriesTable createAlias(String alias) {
    return $AlbumEntriesTable(attachedDatabase, alias);
  }
}

class AlbumEntry extends DataClass implements Insertable<AlbumEntry> {
  final int id;
  final int albumId;

  /// `photo_manager` asset id.
  final String assetId;
  final DateTime addedAt;
  const AlbumEntry({
    required this.id,
    required this.albumId,
    required this.assetId,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['album_id'] = Variable<int>(albumId);
    map['asset_id'] = Variable<String>(assetId);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  AlbumEntriesCompanion toCompanion(bool nullToAbsent) {
    return AlbumEntriesCompanion(
      id: Value(id),
      albumId: Value(albumId),
      assetId: Value(assetId),
      addedAt: Value(addedAt),
    );
  }

  factory AlbumEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AlbumEntry(
      id: serializer.fromJson<int>(json['id']),
      albumId: serializer.fromJson<int>(json['albumId']),
      assetId: serializer.fromJson<String>(json['assetId']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'albumId': serializer.toJson<int>(albumId),
      'assetId': serializer.toJson<String>(assetId),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  AlbumEntry copyWith({
    int? id,
    int? albumId,
    String? assetId,
    DateTime? addedAt,
  }) => AlbumEntry(
    id: id ?? this.id,
    albumId: albumId ?? this.albumId,
    assetId: assetId ?? this.assetId,
    addedAt: addedAt ?? this.addedAt,
  );
  AlbumEntry copyWithCompanion(AlbumEntriesCompanion data) {
    return AlbumEntry(
      id: data.id.present ? data.id.value : this.id,
      albumId: data.albumId.present ? data.albumId.value : this.albumId,
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AlbumEntry(')
          ..write('id: $id, ')
          ..write('albumId: $albumId, ')
          ..write('assetId: $assetId, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, albumId, assetId, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AlbumEntry &&
          other.id == this.id &&
          other.albumId == this.albumId &&
          other.assetId == this.assetId &&
          other.addedAt == this.addedAt);
}

class AlbumEntriesCompanion extends UpdateCompanion<AlbumEntry> {
  final Value<int> id;
  final Value<int> albumId;
  final Value<String> assetId;
  final Value<DateTime> addedAt;
  const AlbumEntriesCompanion({
    this.id = const Value.absent(),
    this.albumId = const Value.absent(),
    this.assetId = const Value.absent(),
    this.addedAt = const Value.absent(),
  });
  AlbumEntriesCompanion.insert({
    this.id = const Value.absent(),
    required int albumId,
    required String assetId,
    required DateTime addedAt,
  }) : albumId = Value(albumId),
       assetId = Value(assetId),
       addedAt = Value(addedAt);
  static Insertable<AlbumEntry> custom({
    Expression<int>? id,
    Expression<int>? albumId,
    Expression<String>? assetId,
    Expression<DateTime>? addedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (albumId != null) 'album_id': albumId,
      if (assetId != null) 'asset_id': assetId,
      if (addedAt != null) 'added_at': addedAt,
    });
  }

  AlbumEntriesCompanion copyWith({
    Value<int>? id,
    Value<int>? albumId,
    Value<String>? assetId,
    Value<DateTime>? addedAt,
  }) {
    return AlbumEntriesCompanion(
      id: id ?? this.id,
      albumId: albumId ?? this.albumId,
      assetId: assetId ?? this.assetId,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (albumId.present) {
      map['album_id'] = Variable<int>(albumId.value);
    }
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AlbumEntriesCompanion(')
          ..write('id: $id, ')
          ..write('albumId: $albumId, ')
          ..write('assetId: $assetId, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }
}

class $EditInstructionsTable extends EditInstructions
    with TableInfo<$EditInstructionsTable, EditInstruction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EditInstructionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
    'asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _instructionsJsonMeta = const VerificationMeta(
    'instructionsJson',
  );
  @override
  late final GeneratedColumn<String> instructionsJson = GeneratedColumn<String>(
    'instructions_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [assetId, instructionsJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'edit_instructions';
  @override
  VerificationContext validateIntegrity(
    Insertable<EditInstruction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('instructions_json')) {
      context.handle(
        _instructionsJsonMeta,
        instructionsJson.isAcceptableOrUnknown(
          data['instructions_json']!,
          _instructionsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_instructionsJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {assetId};
  @override
  EditInstruction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EditInstruction(
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_id'],
      )!,
      instructionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}instructions_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $EditInstructionsTable createAlias(String alias) {
    return $EditInstructionsTable(attachedDatabase, alias);
  }
}

class EditInstruction extends DataClass implements Insertable<EditInstruction> {
  /// `photo_manager` asset id.
  final String assetId;

  /// Serialized edit instruction document.
  final String instructionsJson;
  final DateTime updatedAt;
  const EditInstruction({
    required this.assetId,
    required this.instructionsJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['asset_id'] = Variable<String>(assetId);
    map['instructions_json'] = Variable<String>(instructionsJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  EditInstructionsCompanion toCompanion(bool nullToAbsent) {
    return EditInstructionsCompanion(
      assetId: Value(assetId),
      instructionsJson: Value(instructionsJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory EditInstruction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EditInstruction(
      assetId: serializer.fromJson<String>(json['assetId']),
      instructionsJson: serializer.fromJson<String>(json['instructionsJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'assetId': serializer.toJson<String>(assetId),
      'instructionsJson': serializer.toJson<String>(instructionsJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  EditInstruction copyWith({
    String? assetId,
    String? instructionsJson,
    DateTime? updatedAt,
  }) => EditInstruction(
    assetId: assetId ?? this.assetId,
    instructionsJson: instructionsJson ?? this.instructionsJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  EditInstruction copyWithCompanion(EditInstructionsCompanion data) {
    return EditInstruction(
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      instructionsJson: data.instructionsJson.present
          ? data.instructionsJson.value
          : this.instructionsJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EditInstruction(')
          ..write('assetId: $assetId, ')
          ..write('instructionsJson: $instructionsJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(assetId, instructionsJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EditInstruction &&
          other.assetId == this.assetId &&
          other.instructionsJson == this.instructionsJson &&
          other.updatedAt == this.updatedAt);
}

class EditInstructionsCompanion extends UpdateCompanion<EditInstruction> {
  final Value<String> assetId;
  final Value<String> instructionsJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const EditInstructionsCompanion({
    this.assetId = const Value.absent(),
    this.instructionsJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EditInstructionsCompanion.insert({
    required String assetId,
    required String instructionsJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : assetId = Value(assetId),
       instructionsJson = Value(instructionsJson),
       updatedAt = Value(updatedAt);
  static Insertable<EditInstruction> custom({
    Expression<String>? assetId,
    Expression<String>? instructionsJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (assetId != null) 'asset_id': assetId,
      if (instructionsJson != null) 'instructions_json': instructionsJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EditInstructionsCompanion copyWith({
    Value<String>? assetId,
    Value<String>? instructionsJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return EditInstructionsCompanion(
      assetId: assetId ?? this.assetId,
      instructionsJson: instructionsJson ?? this.instructionsJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (instructionsJson.present) {
      map['instructions_json'] = Variable<String>(instructionsJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EditInstructionsCompanion(')
          ..write('assetId: $assetId, ')
          ..write('instructionsJson: $instructionsJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PhotoAssetsTable extends PhotoAssets
    with TableInfo<$PhotoAssetsTable, PhotoAsset> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhotoAssetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
    'asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isVideoMeta = const VerificationMeta(
    'isVideo',
  );
  @override
  late final GeneratedColumn<bool> isVideo = GeneratedColumn<bool>(
    'is_video',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_video" IN (0, 1))',
    ),
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _indexedAtMeta = const VerificationMeta(
    'indexedAt',
  );
  @override
  late final GeneratedColumn<DateTime> indexedAt = GeneratedColumn<DateTime>(
    'indexed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    assetId,
    createdAt,
    isVideo,
    width,
    height,
    indexedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'photo_assets';
  @override
  VerificationContext validateIntegrity(
    Insertable<PhotoAsset> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('is_video')) {
      context.handle(
        _isVideoMeta,
        isVideo.isAcceptableOrUnknown(data['is_video']!, _isVideoMeta),
      );
    } else if (isInserting) {
      context.missing(_isVideoMeta);
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    } else if (isInserting) {
      context.missing(_widthMeta);
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    } else if (isInserting) {
      context.missing(_heightMeta);
    }
    if (data.containsKey('indexed_at')) {
      context.handle(
        _indexedAtMeta,
        indexedAt.isAcceptableOrUnknown(data['indexed_at']!, _indexedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_indexedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {assetId};
  @override
  PhotoAsset map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PhotoAsset(
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      isVideo: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_video'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      )!,
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      )!,
      indexedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}indexed_at'],
      )!,
    );
  }

  @override
  $PhotoAssetsTable createAlias(String alias) {
    return $PhotoAssetsTable(attachedDatabase, alias);
  }
}

class PhotoAsset extends DataClass implements Insertable<PhotoAsset> {
  /// `photo_manager` asset id.
  final String assetId;

  /// Capture date (the axis the grid orders/groups by); mirrors
  /// `AssetRef.createdAt`.
  final DateTime createdAt;
  final bool isVideo;
  final int width;
  final int height;

  /// When indexing last completed for this asset.
  final DateTime indexedAt;
  const PhotoAsset({
    required this.assetId,
    required this.createdAt,
    required this.isVideo,
    required this.width,
    required this.height,
    required this.indexedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['asset_id'] = Variable<String>(assetId);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['is_video'] = Variable<bool>(isVideo);
    map['width'] = Variable<int>(width);
    map['height'] = Variable<int>(height);
    map['indexed_at'] = Variable<DateTime>(indexedAt);
    return map;
  }

  PhotoAssetsCompanion toCompanion(bool nullToAbsent) {
    return PhotoAssetsCompanion(
      assetId: Value(assetId),
      createdAt: Value(createdAt),
      isVideo: Value(isVideo),
      width: Value(width),
      height: Value(height),
      indexedAt: Value(indexedAt),
    );
  }

  factory PhotoAsset.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PhotoAsset(
      assetId: serializer.fromJson<String>(json['assetId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      isVideo: serializer.fromJson<bool>(json['isVideo']),
      width: serializer.fromJson<int>(json['width']),
      height: serializer.fromJson<int>(json['height']),
      indexedAt: serializer.fromJson<DateTime>(json['indexedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'assetId': serializer.toJson<String>(assetId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'isVideo': serializer.toJson<bool>(isVideo),
      'width': serializer.toJson<int>(width),
      'height': serializer.toJson<int>(height),
      'indexedAt': serializer.toJson<DateTime>(indexedAt),
    };
  }

  PhotoAsset copyWith({
    String? assetId,
    DateTime? createdAt,
    bool? isVideo,
    int? width,
    int? height,
    DateTime? indexedAt,
  }) => PhotoAsset(
    assetId: assetId ?? this.assetId,
    createdAt: createdAt ?? this.createdAt,
    isVideo: isVideo ?? this.isVideo,
    width: width ?? this.width,
    height: height ?? this.height,
    indexedAt: indexedAt ?? this.indexedAt,
  );
  PhotoAsset copyWithCompanion(PhotoAssetsCompanion data) {
    return PhotoAsset(
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      isVideo: data.isVideo.present ? data.isVideo.value : this.isVideo,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      indexedAt: data.indexedAt.present ? data.indexedAt.value : this.indexedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PhotoAsset(')
          ..write('assetId: $assetId, ')
          ..write('createdAt: $createdAt, ')
          ..write('isVideo: $isVideo, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('indexedAt: $indexedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(assetId, createdAt, isVideo, width, height, indexedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PhotoAsset &&
          other.assetId == this.assetId &&
          other.createdAt == this.createdAt &&
          other.isVideo == this.isVideo &&
          other.width == this.width &&
          other.height == this.height &&
          other.indexedAt == this.indexedAt);
}

class PhotoAssetsCompanion extends UpdateCompanion<PhotoAsset> {
  final Value<String> assetId;
  final Value<DateTime> createdAt;
  final Value<bool> isVideo;
  final Value<int> width;
  final Value<int> height;
  final Value<DateTime> indexedAt;
  final Value<int> rowid;
  const PhotoAssetsCompanion({
    this.assetId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isVideo = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.indexedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PhotoAssetsCompanion.insert({
    required String assetId,
    required DateTime createdAt,
    required bool isVideo,
    required int width,
    required int height,
    required DateTime indexedAt,
    this.rowid = const Value.absent(),
  }) : assetId = Value(assetId),
       createdAt = Value(createdAt),
       isVideo = Value(isVideo),
       width = Value(width),
       height = Value(height),
       indexedAt = Value(indexedAt);
  static Insertable<PhotoAsset> custom({
    Expression<String>? assetId,
    Expression<DateTime>? createdAt,
    Expression<bool>? isVideo,
    Expression<int>? width,
    Expression<int>? height,
    Expression<DateTime>? indexedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (assetId != null) 'asset_id': assetId,
      if (createdAt != null) 'created_at': createdAt,
      if (isVideo != null) 'is_video': isVideo,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (indexedAt != null) 'indexed_at': indexedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PhotoAssetsCompanion copyWith({
    Value<String>? assetId,
    Value<DateTime>? createdAt,
    Value<bool>? isVideo,
    Value<int>? width,
    Value<int>? height,
    Value<DateTime>? indexedAt,
    Value<int>? rowid,
  }) {
    return PhotoAssetsCompanion(
      assetId: assetId ?? this.assetId,
      createdAt: createdAt ?? this.createdAt,
      isVideo: isVideo ?? this.isVideo,
      width: width ?? this.width,
      height: height ?? this.height,
      indexedAt: indexedAt ?? this.indexedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (isVideo.present) {
      map['is_video'] = Variable<bool>(isVideo.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (indexedAt.present) {
      map['indexed_at'] = Variable<DateTime>(indexedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhotoAssetsCompanion(')
          ..write('assetId: $assetId, ')
          ..write('createdAt: $createdAt, ')
          ..write('isVideo: $isVideo, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('indexedAt: $indexedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PhotoLabelsTable extends PhotoLabels
    with TableInfo<$PhotoLabelsTable, PhotoLabel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhotoLabelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
    'asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES photo_assets (asset_id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, assetId, label, confidence];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'photo_labels';
  @override
  VerificationContext validateIntegrity(
    Insertable<PhotoLabel> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    } else if (isInserting) {
      context.missing(_confidenceMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PhotoLabel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PhotoLabel(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      )!,
    );
  }

  @override
  $PhotoLabelsTable createAlias(String alias) {
    return $PhotoLabelsTable(attachedDatabase, alias);
  }
}

class PhotoLabel extends DataClass implements Insertable<PhotoLabel> {
  final int id;

  /// `photo_manager` asset id; cascades from [PhotoAssets].
  final String assetId;

  /// The ML Kit label text (e.g. "Dog"), stored as returned.
  final String label;

  /// Model confidence in `[0, 1]`.
  final double confidence;
  const PhotoLabel({
    required this.id,
    required this.assetId,
    required this.label,
    required this.confidence,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['asset_id'] = Variable<String>(assetId);
    map['label'] = Variable<String>(label);
    map['confidence'] = Variable<double>(confidence);
    return map;
  }

  PhotoLabelsCompanion toCompanion(bool nullToAbsent) {
    return PhotoLabelsCompanion(
      id: Value(id),
      assetId: Value(assetId),
      label: Value(label),
      confidence: Value(confidence),
    );
  }

  factory PhotoLabel.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PhotoLabel(
      id: serializer.fromJson<int>(json['id']),
      assetId: serializer.fromJson<String>(json['assetId']),
      label: serializer.fromJson<String>(json['label']),
      confidence: serializer.fromJson<double>(json['confidence']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'assetId': serializer.toJson<String>(assetId),
      'label': serializer.toJson<String>(label),
      'confidence': serializer.toJson<double>(confidence),
    };
  }

  PhotoLabel copyWith({
    int? id,
    String? assetId,
    String? label,
    double? confidence,
  }) => PhotoLabel(
    id: id ?? this.id,
    assetId: assetId ?? this.assetId,
    label: label ?? this.label,
    confidence: confidence ?? this.confidence,
  );
  PhotoLabel copyWithCompanion(PhotoLabelsCompanion data) {
    return PhotoLabel(
      id: data.id.present ? data.id.value : this.id,
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      label: data.label.present ? data.label.value : this.label,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PhotoLabel(')
          ..write('id: $id, ')
          ..write('assetId: $assetId, ')
          ..write('label: $label, ')
          ..write('confidence: $confidence')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, assetId, label, confidence);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PhotoLabel &&
          other.id == this.id &&
          other.assetId == this.assetId &&
          other.label == this.label &&
          other.confidence == this.confidence);
}

class PhotoLabelsCompanion extends UpdateCompanion<PhotoLabel> {
  final Value<int> id;
  final Value<String> assetId;
  final Value<String> label;
  final Value<double> confidence;
  const PhotoLabelsCompanion({
    this.id = const Value.absent(),
    this.assetId = const Value.absent(),
    this.label = const Value.absent(),
    this.confidence = const Value.absent(),
  });
  PhotoLabelsCompanion.insert({
    this.id = const Value.absent(),
    required String assetId,
    required String label,
    required double confidence,
  }) : assetId = Value(assetId),
       label = Value(label),
       confidence = Value(confidence);
  static Insertable<PhotoLabel> custom({
    Expression<int>? id,
    Expression<String>? assetId,
    Expression<String>? label,
    Expression<double>? confidence,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (assetId != null) 'asset_id': assetId,
      if (label != null) 'label': label,
      if (confidence != null) 'confidence': confidence,
    });
  }

  PhotoLabelsCompanion copyWith({
    Value<int>? id,
    Value<String>? assetId,
    Value<String>? label,
    Value<double>? confidence,
  }) {
    return PhotoLabelsCompanion(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      label: label ?? this.label,
      confidence: confidence ?? this.confidence,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhotoLabelsCompanion(')
          ..write('id: $id, ')
          ..write('assetId: $assetId, ')
          ..write('label: $label, ')
          ..write('confidence: $confidence')
          ..write(')'))
        .toString();
  }
}

class $PhotoTextsTable extends PhotoTexts
    with TableInfo<$PhotoTextsTable, PhotoText> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhotoTextsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
    'asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES photo_assets (asset_id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [assetId, content];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'photo_texts';
  @override
  VerificationContext validateIntegrity(
    Insertable<PhotoText> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {assetId};
  @override
  PhotoText map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PhotoText(
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_id'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
    );
  }

  @override
  $PhotoTextsTable createAlias(String alias) {
    return $PhotoTextsTable(attachedDatabase, alias);
  }
}

class PhotoText extends DataClass implements Insertable<PhotoText> {
  /// `photo_manager` asset id; cascades from [PhotoAssets].
  final String assetId;

  /// The recognized text, newlines collapsed to spaces. Named `content` (not
  /// `text`) — a drift column can't reuse the `text()` builder name.
  final String content;
  const PhotoText({required this.assetId, required this.content});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['asset_id'] = Variable<String>(assetId);
    map['content'] = Variable<String>(content);
    return map;
  }

  PhotoTextsCompanion toCompanion(bool nullToAbsent) {
    return PhotoTextsCompanion(
      assetId: Value(assetId),
      content: Value(content),
    );
  }

  factory PhotoText.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PhotoText(
      assetId: serializer.fromJson<String>(json['assetId']),
      content: serializer.fromJson<String>(json['content']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'assetId': serializer.toJson<String>(assetId),
      'content': serializer.toJson<String>(content),
    };
  }

  PhotoText copyWith({String? assetId, String? content}) => PhotoText(
    assetId: assetId ?? this.assetId,
    content: content ?? this.content,
  );
  PhotoText copyWithCompanion(PhotoTextsCompanion data) {
    return PhotoText(
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      content: data.content.present ? data.content.value : this.content,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PhotoText(')
          ..write('assetId: $assetId, ')
          ..write('content: $content')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(assetId, content);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PhotoText &&
          other.assetId == this.assetId &&
          other.content == this.content);
}

class PhotoTextsCompanion extends UpdateCompanion<PhotoText> {
  final Value<String> assetId;
  final Value<String> content;
  final Value<int> rowid;
  const PhotoTextsCompanion({
    this.assetId = const Value.absent(),
    this.content = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PhotoTextsCompanion.insert({
    required String assetId,
    required String content,
    this.rowid = const Value.absent(),
  }) : assetId = Value(assetId),
       content = Value(content);
  static Insertable<PhotoText> custom({
    Expression<String>? assetId,
    Expression<String>? content,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (assetId != null) 'asset_id': assetId,
      if (content != null) 'content': content,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PhotoTextsCompanion copyWith({
    Value<String>? assetId,
    Value<String>? content,
    Value<int>? rowid,
  }) {
    return PhotoTextsCompanion(
      assetId: assetId ?? this.assetId,
      content: content ?? this.content,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhotoTextsCompanion(')
          ..write('assetId: $assetId, ')
          ..write('content: $content, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PersonsTable extends Persons with TableInfo<$PersonsTable, Person> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PersonsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverAssetIdMeta = const VerificationMeta(
    'coverAssetId',
  );
  @override
  late final GeneratedColumn<String> coverAssetId = GeneratedColumn<String>(
    'cover_asset_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    displayName,
    coverAssetId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'persons';
  @override
  VerificationContext validateIntegrity(
    Insertable<Person> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('cover_asset_id')) {
      context.handle(
        _coverAssetIdMeta,
        coverAssetId.isAcceptableOrUnknown(
          data['cover_asset_id']!,
          _coverAssetIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Person map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Person(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      coverAssetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_asset_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PersonsTable createAlias(String alias) {
    return $PersonsTable(attachedDatabase, alias);
  }
}

class Person extends DataClass implements Insertable<Person> {
  final int id;
  final String? displayName;

  /// A `photo_manager` asset id used for the person's cover/avatar.
  final String? coverAssetId;
  final DateTime createdAt;
  const Person({
    required this.id,
    this.displayName,
    this.coverAssetId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    if (!nullToAbsent || coverAssetId != null) {
      map['cover_asset_id'] = Variable<String>(coverAssetId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PersonsCompanion toCompanion(bool nullToAbsent) {
    return PersonsCompanion(
      id: Value(id),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      coverAssetId: coverAssetId == null && nullToAbsent
          ? const Value.absent()
          : Value(coverAssetId),
      createdAt: Value(createdAt),
    );
  }

  factory Person.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Person(
      id: serializer.fromJson<int>(json['id']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      coverAssetId: serializer.fromJson<String?>(json['coverAssetId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'displayName': serializer.toJson<String?>(displayName),
      'coverAssetId': serializer.toJson<String?>(coverAssetId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Person copyWith({
    int? id,
    Value<String?> displayName = const Value.absent(),
    Value<String?> coverAssetId = const Value.absent(),
    DateTime? createdAt,
  }) => Person(
    id: id ?? this.id,
    displayName: displayName.present ? displayName.value : this.displayName,
    coverAssetId: coverAssetId.present ? coverAssetId.value : this.coverAssetId,
    createdAt: createdAt ?? this.createdAt,
  );
  Person copyWithCompanion(PersonsCompanion data) {
    return Person(
      id: data.id.present ? data.id.value : this.id,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      coverAssetId: data.coverAssetId.present
          ? data.coverAssetId.value
          : this.coverAssetId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Person(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('coverAssetId: $coverAssetId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, displayName, coverAssetId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Person &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.coverAssetId == this.coverAssetId &&
          other.createdAt == this.createdAt);
}

class PersonsCompanion extends UpdateCompanion<Person> {
  final Value<int> id;
  final Value<String?> displayName;
  final Value<String?> coverAssetId;
  final Value<DateTime> createdAt;
  const PersonsCompanion({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.coverAssetId = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PersonsCompanion.insert({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.coverAssetId = const Value.absent(),
    required DateTime createdAt,
  }) : createdAt = Value(createdAt);
  static Insertable<Person> custom({
    Expression<int>? id,
    Expression<String>? displayName,
    Expression<String>? coverAssetId,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (coverAssetId != null) 'cover_asset_id': coverAssetId,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PersonsCompanion copyWith({
    Value<int>? id,
    Value<String?>? displayName,
    Value<String?>? coverAssetId,
    Value<DateTime>? createdAt,
  }) {
    return PersonsCompanion(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      coverAssetId: coverAssetId ?? this.coverAssetId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (coverAssetId.present) {
      map['cover_asset_id'] = Variable<String>(coverAssetId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PersonsCompanion(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('coverAssetId: $coverAssetId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $FaceEmbeddingsTable extends FaceEmbeddings
    with TableInfo<$FaceEmbeddingsTable, FaceEmbedding> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FaceEmbeddingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
    'asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES photo_assets (asset_id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _personIdMeta = const VerificationMeta(
    'personId',
  );
  @override
  late final GeneratedColumn<int> personId = GeneratedColumn<int>(
    'person_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES persons (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _embeddingMeta = const VerificationMeta(
    'embedding',
  );
  @override
  late final GeneratedColumn<Uint8List> embedding = GeneratedColumn<Uint8List>(
    'embedding',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _leftMeta = const VerificationMeta('left');
  @override
  late final GeneratedColumn<int> left = GeneratedColumn<int>(
    'left',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _topMeta = const VerificationMeta('top');
  @override
  late final GeneratedColumn<int> top = GeneratedColumn<int>(
    'top',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rightMeta = const VerificationMeta('right');
  @override
  late final GeneratedColumn<int> right = GeneratedColumn<int>(
    'right',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bottomMeta = const VerificationMeta('bottom');
  @override
  late final GeneratedColumn<int> bottom = GeneratedColumn<int>(
    'bottom',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    assetId,
    personId,
    embedding,
    left,
    top,
    right,
    bottom,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'face_embeddings';
  @override
  VerificationContext validateIntegrity(
    Insertable<FaceEmbedding> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('person_id')) {
      context.handle(
        _personIdMeta,
        personId.isAcceptableOrUnknown(data['person_id']!, _personIdMeta),
      );
    }
    if (data.containsKey('embedding')) {
      context.handle(
        _embeddingMeta,
        embedding.isAcceptableOrUnknown(data['embedding']!, _embeddingMeta),
      );
    } else if (isInserting) {
      context.missing(_embeddingMeta);
    }
    if (data.containsKey('left')) {
      context.handle(
        _leftMeta,
        left.isAcceptableOrUnknown(data['left']!, _leftMeta),
      );
    } else if (isInserting) {
      context.missing(_leftMeta);
    }
    if (data.containsKey('top')) {
      context.handle(
        _topMeta,
        top.isAcceptableOrUnknown(data['top']!, _topMeta),
      );
    } else if (isInserting) {
      context.missing(_topMeta);
    }
    if (data.containsKey('right')) {
      context.handle(
        _rightMeta,
        right.isAcceptableOrUnknown(data['right']!, _rightMeta),
      );
    } else if (isInserting) {
      context.missing(_rightMeta);
    }
    if (data.containsKey('bottom')) {
      context.handle(
        _bottomMeta,
        bottom.isAcceptableOrUnknown(data['bottom']!, _bottomMeta),
      );
    } else if (isInserting) {
      context.missing(_bottomMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FaceEmbedding map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FaceEmbedding(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_id'],
      )!,
      personId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}person_id'],
      ),
      embedding: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}embedding'],
      )!,
      left: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}left'],
      )!,
      top: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}top'],
      )!,
      right: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}right'],
      )!,
      bottom: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bottom'],
      )!,
    );
  }

  @override
  $FaceEmbeddingsTable createAlias(String alias) {
    return $FaceEmbeddingsTable(attachedDatabase, alias);
  }
}

class FaceEmbedding extends DataClass implements Insertable<FaceEmbedding> {
  final int id;

  /// `photo_manager` asset id; cascades from [PhotoAssets].
  final String assetId;
  final int? personId;

  /// The face-embedding vector, `Float32List` bytes (little-endian).
  final Uint8List embedding;
  final int left;
  final int top;
  final int right;
  final int bottom;
  const FaceEmbedding({
    required this.id,
    required this.assetId,
    this.personId,
    required this.embedding,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['asset_id'] = Variable<String>(assetId);
    if (!nullToAbsent || personId != null) {
      map['person_id'] = Variable<int>(personId);
    }
    map['embedding'] = Variable<Uint8List>(embedding);
    map['left'] = Variable<int>(left);
    map['top'] = Variable<int>(top);
    map['right'] = Variable<int>(right);
    map['bottom'] = Variable<int>(bottom);
    return map;
  }

  FaceEmbeddingsCompanion toCompanion(bool nullToAbsent) {
    return FaceEmbeddingsCompanion(
      id: Value(id),
      assetId: Value(assetId),
      personId: personId == null && nullToAbsent
          ? const Value.absent()
          : Value(personId),
      embedding: Value(embedding),
      left: Value(left),
      top: Value(top),
      right: Value(right),
      bottom: Value(bottom),
    );
  }

  factory FaceEmbedding.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FaceEmbedding(
      id: serializer.fromJson<int>(json['id']),
      assetId: serializer.fromJson<String>(json['assetId']),
      personId: serializer.fromJson<int?>(json['personId']),
      embedding: serializer.fromJson<Uint8List>(json['embedding']),
      left: serializer.fromJson<int>(json['left']),
      top: serializer.fromJson<int>(json['top']),
      right: serializer.fromJson<int>(json['right']),
      bottom: serializer.fromJson<int>(json['bottom']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'assetId': serializer.toJson<String>(assetId),
      'personId': serializer.toJson<int?>(personId),
      'embedding': serializer.toJson<Uint8List>(embedding),
      'left': serializer.toJson<int>(left),
      'top': serializer.toJson<int>(top),
      'right': serializer.toJson<int>(right),
      'bottom': serializer.toJson<int>(bottom),
    };
  }

  FaceEmbedding copyWith({
    int? id,
    String? assetId,
    Value<int?> personId = const Value.absent(),
    Uint8List? embedding,
    int? left,
    int? top,
    int? right,
    int? bottom,
  }) => FaceEmbedding(
    id: id ?? this.id,
    assetId: assetId ?? this.assetId,
    personId: personId.present ? personId.value : this.personId,
    embedding: embedding ?? this.embedding,
    left: left ?? this.left,
    top: top ?? this.top,
    right: right ?? this.right,
    bottom: bottom ?? this.bottom,
  );
  FaceEmbedding copyWithCompanion(FaceEmbeddingsCompanion data) {
    return FaceEmbedding(
      id: data.id.present ? data.id.value : this.id,
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      personId: data.personId.present ? data.personId.value : this.personId,
      embedding: data.embedding.present ? data.embedding.value : this.embedding,
      left: data.left.present ? data.left.value : this.left,
      top: data.top.present ? data.top.value : this.top,
      right: data.right.present ? data.right.value : this.right,
      bottom: data.bottom.present ? data.bottom.value : this.bottom,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FaceEmbedding(')
          ..write('id: $id, ')
          ..write('assetId: $assetId, ')
          ..write('personId: $personId, ')
          ..write('embedding: $embedding, ')
          ..write('left: $left, ')
          ..write('top: $top, ')
          ..write('right: $right, ')
          ..write('bottom: $bottom')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    assetId,
    personId,
    $driftBlobEquality.hash(embedding),
    left,
    top,
    right,
    bottom,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FaceEmbedding &&
          other.id == this.id &&
          other.assetId == this.assetId &&
          other.personId == this.personId &&
          $driftBlobEquality.equals(other.embedding, this.embedding) &&
          other.left == this.left &&
          other.top == this.top &&
          other.right == this.right &&
          other.bottom == this.bottom);
}

class FaceEmbeddingsCompanion extends UpdateCompanion<FaceEmbedding> {
  final Value<int> id;
  final Value<String> assetId;
  final Value<int?> personId;
  final Value<Uint8List> embedding;
  final Value<int> left;
  final Value<int> top;
  final Value<int> right;
  final Value<int> bottom;
  const FaceEmbeddingsCompanion({
    this.id = const Value.absent(),
    this.assetId = const Value.absent(),
    this.personId = const Value.absent(),
    this.embedding = const Value.absent(),
    this.left = const Value.absent(),
    this.top = const Value.absent(),
    this.right = const Value.absent(),
    this.bottom = const Value.absent(),
  });
  FaceEmbeddingsCompanion.insert({
    this.id = const Value.absent(),
    required String assetId,
    this.personId = const Value.absent(),
    required Uint8List embedding,
    required int left,
    required int top,
    required int right,
    required int bottom,
  }) : assetId = Value(assetId),
       embedding = Value(embedding),
       left = Value(left),
       top = Value(top),
       right = Value(right),
       bottom = Value(bottom);
  static Insertable<FaceEmbedding> custom({
    Expression<int>? id,
    Expression<String>? assetId,
    Expression<int>? personId,
    Expression<Uint8List>? embedding,
    Expression<int>? left,
    Expression<int>? top,
    Expression<int>? right,
    Expression<int>? bottom,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (assetId != null) 'asset_id': assetId,
      if (personId != null) 'person_id': personId,
      if (embedding != null) 'embedding': embedding,
      if (left != null) 'left': left,
      if (top != null) 'top': top,
      if (right != null) 'right': right,
      if (bottom != null) 'bottom': bottom,
    });
  }

  FaceEmbeddingsCompanion copyWith({
    Value<int>? id,
    Value<String>? assetId,
    Value<int?>? personId,
    Value<Uint8List>? embedding,
    Value<int>? left,
    Value<int>? top,
    Value<int>? right,
    Value<int>? bottom,
  }) {
    return FaceEmbeddingsCompanion(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      personId: personId ?? this.personId,
      embedding: embedding ?? this.embedding,
      left: left ?? this.left,
      top: top ?? this.top,
      right: right ?? this.right,
      bottom: bottom ?? this.bottom,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (personId.present) {
      map['person_id'] = Variable<int>(personId.value);
    }
    if (embedding.present) {
      map['embedding'] = Variable<Uint8List>(embedding.value);
    }
    if (left.present) {
      map['left'] = Variable<int>(left.value);
    }
    if (top.present) {
      map['top'] = Variable<int>(top.value);
    }
    if (right.present) {
      map['right'] = Variable<int>(right.value);
    }
    if (bottom.present) {
      map['bottom'] = Variable<int>(bottom.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FaceEmbeddingsCompanion(')
          ..write('id: $id, ')
          ..write('assetId: $assetId, ')
          ..write('personId: $personId, ')
          ..write('embedding: $embedding, ')
          ..write('left: $left, ')
          ..write('top: $top, ')
          ..write('right: $right, ')
          ..write('bottom: $bottom')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $FavoritesTable favorites = $FavoritesTable(this);
  late final $AlbumsTable albums = $AlbumsTable(this);
  late final $AlbumEntriesTable albumEntries = $AlbumEntriesTable(this);
  late final $EditInstructionsTable editInstructions = $EditInstructionsTable(
    this,
  );
  late final $PhotoAssetsTable photoAssets = $PhotoAssetsTable(this);
  late final $PhotoLabelsTable photoLabels = $PhotoLabelsTable(this);
  late final $PhotoTextsTable photoTexts = $PhotoTextsTable(this);
  late final $PersonsTable persons = $PersonsTable(this);
  late final $FaceEmbeddingsTable faceEmbeddings = $FaceEmbeddingsTable(this);
  late final Index photoLabelAsset = Index(
    'photo_label_asset',
    'CREATE INDEX photo_label_asset ON photo_labels (asset_id)',
  );
  late final Index photoLabelLabel = Index(
    'photo_label_label',
    'CREATE INDEX photo_label_label ON photo_labels (label)',
  );
  late final Index faceAsset = Index(
    'face_asset',
    'CREATE INDEX face_asset ON face_embeddings (asset_id)',
  );
  late final Index facePerson = Index(
    'face_person',
    'CREATE INDEX face_person ON face_embeddings (person_id)',
  );
  late final FavoritesDao favoritesDao = FavoritesDao(this as AppDatabase);
  late final AlbumsDao albumsDao = AlbumsDao(this as AppDatabase);
  late final EditInstructionsDao editInstructionsDao = EditInstructionsDao(
    this as AppDatabase,
  );
  late final IndexDao indexDao = IndexDao(this as AppDatabase);
  late final FacesDao facesDao = FacesDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    favorites,
    albums,
    albumEntries,
    editInstructions,
    photoAssets,
    photoLabels,
    photoTexts,
    persons,
    faceEmbeddings,
    photoLabelAsset,
    photoLabelLabel,
    faceAsset,
    facePerson,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'albums',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('album_entries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'photo_assets',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('photo_labels', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'photo_assets',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('photo_texts', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'photo_assets',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('face_embeddings', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'persons',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('face_embeddings', kind: UpdateKind.update)],
    ),
  ]);
}

typedef $$FavoritesTableCreateCompanionBuilder =
    FavoritesCompanion Function({
      required String assetId,
      required DateTime favoritedAt,
      Value<int> rowid,
    });
typedef $$FavoritesTableUpdateCompanionBuilder =
    FavoritesCompanion Function({
      Value<String> assetId,
      Value<DateTime> favoritedAt,
      Value<int> rowid,
    });

class $$FavoritesTableFilterComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get favoritedAt => $composableBuilder(
    column: $table.favoritedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FavoritesTableOrderingComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get favoritedAt => $composableBuilder(
    column: $table.favoritedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FavoritesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get assetId =>
      $composableBuilder(column: $table.assetId, builder: (column) => column);

  GeneratedColumn<DateTime> get favoritedAt => $composableBuilder(
    column: $table.favoritedAt,
    builder: (column) => column,
  );
}

class $$FavoritesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FavoritesTable,
          Favorite,
          $$FavoritesTableFilterComposer,
          $$FavoritesTableOrderingComposer,
          $$FavoritesTableAnnotationComposer,
          $$FavoritesTableCreateCompanionBuilder,
          $$FavoritesTableUpdateCompanionBuilder,
          (Favorite, BaseReferences<_$AppDatabase, $FavoritesTable, Favorite>),
          Favorite,
          PrefetchHooks Function()
        > {
  $$FavoritesTableTableManager(_$AppDatabase db, $FavoritesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoritesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoritesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavoritesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> assetId = const Value.absent(),
                Value<DateTime> favoritedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FavoritesCompanion(
                assetId: assetId,
                favoritedAt: favoritedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String assetId,
                required DateTime favoritedAt,
                Value<int> rowid = const Value.absent(),
              }) => FavoritesCompanion.insert(
                assetId: assetId,
                favoritedAt: favoritedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FavoritesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FavoritesTable,
      Favorite,
      $$FavoritesTableFilterComposer,
      $$FavoritesTableOrderingComposer,
      $$FavoritesTableAnnotationComposer,
      $$FavoritesTableCreateCompanionBuilder,
      $$FavoritesTableUpdateCompanionBuilder,
      (Favorite, BaseReferences<_$AppDatabase, $FavoritesTable, Favorite>),
      Favorite,
      PrefetchHooks Function()
    >;
typedef $$AlbumsTableCreateCompanionBuilder =
    AlbumsCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> coverAssetId,
      required DateTime createdAt,
      Value<int> sortIndex,
    });
typedef $$AlbumsTableUpdateCompanionBuilder =
    AlbumsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> coverAssetId,
      Value<DateTime> createdAt,
      Value<int> sortIndex,
    });

final class $$AlbumsTableReferences
    extends BaseReferences<_$AppDatabase, $AlbumsTable, Album> {
  $$AlbumsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$AlbumEntriesTable, List<AlbumEntry>>
  _albumEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.albumEntries,
    aliasName: 'albums__id__album_entries__album_id',
  );

  $$AlbumEntriesTableProcessedTableManager get albumEntriesRefs {
    final manager = $$AlbumEntriesTableTableManager(
      $_db,
      $_db.albumEntries,
    ).filter((f) => f.albumId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_albumEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AlbumsTableFilterComposer
    extends Composer<_$AppDatabase, $AlbumsTable> {
  $$AlbumsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverAssetId => $composableBuilder(
    column: $table.coverAssetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> albumEntriesRefs(
    Expression<bool> Function($$AlbumEntriesTableFilterComposer f) f,
  ) {
    final $$AlbumEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.albumEntries,
      getReferencedColumn: (t) => t.albumId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlbumEntriesTableFilterComposer(
            $db: $db,
            $table: $db.albumEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AlbumsTableOrderingComposer
    extends Composer<_$AppDatabase, $AlbumsTable> {
  $$AlbumsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverAssetId => $composableBuilder(
    column: $table.coverAssetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AlbumsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AlbumsTable> {
  $$AlbumsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get coverAssetId => $composableBuilder(
    column: $table.coverAssetId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get sortIndex =>
      $composableBuilder(column: $table.sortIndex, builder: (column) => column);

  Expression<T> albumEntriesRefs<T extends Object>(
    Expression<T> Function($$AlbumEntriesTableAnnotationComposer a) f,
  ) {
    final $$AlbumEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.albumEntries,
      getReferencedColumn: (t) => t.albumId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlbumEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.albumEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AlbumsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AlbumsTable,
          Album,
          $$AlbumsTableFilterComposer,
          $$AlbumsTableOrderingComposer,
          $$AlbumsTableAnnotationComposer,
          $$AlbumsTableCreateCompanionBuilder,
          $$AlbumsTableUpdateCompanionBuilder,
          (Album, $$AlbumsTableReferences),
          Album,
          PrefetchHooks Function({bool albumEntriesRefs})
        > {
  $$AlbumsTableTableManager(_$AppDatabase db, $AlbumsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AlbumsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AlbumsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AlbumsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> coverAssetId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
              }) => AlbumsCompanion(
                id: id,
                name: name,
                coverAssetId: coverAssetId,
                createdAt: createdAt,
                sortIndex: sortIndex,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> coverAssetId = const Value.absent(),
                required DateTime createdAt,
                Value<int> sortIndex = const Value.absent(),
              }) => AlbumsCompanion.insert(
                id: id,
                name: name,
                coverAssetId: coverAssetId,
                createdAt: createdAt,
                sortIndex: sortIndex,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$AlbumsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({albumEntriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (albumEntriesRefs) db.albumEntries],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (albumEntriesRefs)
                    await $_getPrefetchedData<Album, $AlbumsTable, AlbumEntry>(
                      currentTable: table,
                      referencedTable: $$AlbumsTableReferences
                          ._albumEntriesRefsTable(db),
                      managerFromTypedResult: (p0) => $$AlbumsTableReferences(
                        db,
                        table,
                        p0,
                      ).albumEntriesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.albumId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$AlbumsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AlbumsTable,
      Album,
      $$AlbumsTableFilterComposer,
      $$AlbumsTableOrderingComposer,
      $$AlbumsTableAnnotationComposer,
      $$AlbumsTableCreateCompanionBuilder,
      $$AlbumsTableUpdateCompanionBuilder,
      (Album, $$AlbumsTableReferences),
      Album,
      PrefetchHooks Function({bool albumEntriesRefs})
    >;
typedef $$AlbumEntriesTableCreateCompanionBuilder =
    AlbumEntriesCompanion Function({
      Value<int> id,
      required int albumId,
      required String assetId,
      required DateTime addedAt,
    });
typedef $$AlbumEntriesTableUpdateCompanionBuilder =
    AlbumEntriesCompanion Function({
      Value<int> id,
      Value<int> albumId,
      Value<String> assetId,
      Value<DateTime> addedAt,
    });

final class $$AlbumEntriesTableReferences
    extends BaseReferences<_$AppDatabase, $AlbumEntriesTable, AlbumEntry> {
  $$AlbumEntriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AlbumsTable _albumIdTable(_$AppDatabase db) =>
      db.albums.createAlias('album_entries__album_id__albums__id');

  $$AlbumsTableProcessedTableManager get albumId {
    final $_column = $_itemColumn<int>('album_id')!;

    final manager = $$AlbumsTableTableManager(
      $_db,
      $_db.albums,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_albumIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AlbumEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $AlbumEntriesTable> {
  $$AlbumEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AlbumsTableFilterComposer get albumId {
    final $$AlbumsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.albumId,
      referencedTable: $db.albums,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlbumsTableFilterComposer(
            $db: $db,
            $table: $db.albums,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AlbumEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $AlbumEntriesTable> {
  $$AlbumEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AlbumsTableOrderingComposer get albumId {
    final $$AlbumsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.albumId,
      referencedTable: $db.albums,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlbumsTableOrderingComposer(
            $db: $db,
            $table: $db.albums,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AlbumEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AlbumEntriesTable> {
  $$AlbumEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get assetId =>
      $composableBuilder(column: $table.assetId, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$AlbumsTableAnnotationComposer get albumId {
    final $$AlbumsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.albumId,
      referencedTable: $db.albums,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlbumsTableAnnotationComposer(
            $db: $db,
            $table: $db.albums,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AlbumEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AlbumEntriesTable,
          AlbumEntry,
          $$AlbumEntriesTableFilterComposer,
          $$AlbumEntriesTableOrderingComposer,
          $$AlbumEntriesTableAnnotationComposer,
          $$AlbumEntriesTableCreateCompanionBuilder,
          $$AlbumEntriesTableUpdateCompanionBuilder,
          (AlbumEntry, $$AlbumEntriesTableReferences),
          AlbumEntry,
          PrefetchHooks Function({bool albumId})
        > {
  $$AlbumEntriesTableTableManager(_$AppDatabase db, $AlbumEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AlbumEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AlbumEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AlbumEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> albumId = const Value.absent(),
                Value<String> assetId = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
              }) => AlbumEntriesCompanion(
                id: id,
                albumId: albumId,
                assetId: assetId,
                addedAt: addedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int albumId,
                required String assetId,
                required DateTime addedAt,
              }) => AlbumEntriesCompanion.insert(
                id: id,
                albumId: albumId,
                assetId: assetId,
                addedAt: addedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AlbumEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({albumId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (albumId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.albumId,
                                referencedTable: $$AlbumEntriesTableReferences
                                    ._albumIdTable(db),
                                referencedColumn: $$AlbumEntriesTableReferences
                                    ._albumIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AlbumEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AlbumEntriesTable,
      AlbumEntry,
      $$AlbumEntriesTableFilterComposer,
      $$AlbumEntriesTableOrderingComposer,
      $$AlbumEntriesTableAnnotationComposer,
      $$AlbumEntriesTableCreateCompanionBuilder,
      $$AlbumEntriesTableUpdateCompanionBuilder,
      (AlbumEntry, $$AlbumEntriesTableReferences),
      AlbumEntry,
      PrefetchHooks Function({bool albumId})
    >;
typedef $$EditInstructionsTableCreateCompanionBuilder =
    EditInstructionsCompanion Function({
      required String assetId,
      required String instructionsJson,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$EditInstructionsTableUpdateCompanionBuilder =
    EditInstructionsCompanion Function({
      Value<String> assetId,
      Value<String> instructionsJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$EditInstructionsTableFilterComposer
    extends Composer<_$AppDatabase, $EditInstructionsTable> {
  $$EditInstructionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get instructionsJson => $composableBuilder(
    column: $table.instructionsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EditInstructionsTableOrderingComposer
    extends Composer<_$AppDatabase, $EditInstructionsTable> {
  $$EditInstructionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get instructionsJson => $composableBuilder(
    column: $table.instructionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EditInstructionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EditInstructionsTable> {
  $$EditInstructionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get assetId =>
      $composableBuilder(column: $table.assetId, builder: (column) => column);

  GeneratedColumn<String> get instructionsJson => $composableBuilder(
    column: $table.instructionsJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$EditInstructionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EditInstructionsTable,
          EditInstruction,
          $$EditInstructionsTableFilterComposer,
          $$EditInstructionsTableOrderingComposer,
          $$EditInstructionsTableAnnotationComposer,
          $$EditInstructionsTableCreateCompanionBuilder,
          $$EditInstructionsTableUpdateCompanionBuilder,
          (
            EditInstruction,
            BaseReferences<
              _$AppDatabase,
              $EditInstructionsTable,
              EditInstruction
            >,
          ),
          EditInstruction,
          PrefetchHooks Function()
        > {
  $$EditInstructionsTableTableManager(
    _$AppDatabase db,
    $EditInstructionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EditInstructionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EditInstructionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EditInstructionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> assetId = const Value.absent(),
                Value<String> instructionsJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EditInstructionsCompanion(
                assetId: assetId,
                instructionsJson: instructionsJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String assetId,
                required String instructionsJson,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => EditInstructionsCompanion.insert(
                assetId: assetId,
                instructionsJson: instructionsJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EditInstructionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EditInstructionsTable,
      EditInstruction,
      $$EditInstructionsTableFilterComposer,
      $$EditInstructionsTableOrderingComposer,
      $$EditInstructionsTableAnnotationComposer,
      $$EditInstructionsTableCreateCompanionBuilder,
      $$EditInstructionsTableUpdateCompanionBuilder,
      (
        EditInstruction,
        BaseReferences<_$AppDatabase, $EditInstructionsTable, EditInstruction>,
      ),
      EditInstruction,
      PrefetchHooks Function()
    >;
typedef $$PhotoAssetsTableCreateCompanionBuilder =
    PhotoAssetsCompanion Function({
      required String assetId,
      required DateTime createdAt,
      required bool isVideo,
      required int width,
      required int height,
      required DateTime indexedAt,
      Value<int> rowid,
    });
typedef $$PhotoAssetsTableUpdateCompanionBuilder =
    PhotoAssetsCompanion Function({
      Value<String> assetId,
      Value<DateTime> createdAt,
      Value<bool> isVideo,
      Value<int> width,
      Value<int> height,
      Value<DateTime> indexedAt,
      Value<int> rowid,
    });

final class $$PhotoAssetsTableReferences
    extends BaseReferences<_$AppDatabase, $PhotoAssetsTable, PhotoAsset> {
  $$PhotoAssetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PhotoLabelsTable, List<PhotoLabel>>
  _photoLabelsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.photoLabels,
    aliasName: 'photo_assets__asset_id__photo_labels__asset_id',
  );

  $$PhotoLabelsTableProcessedTableManager get photoLabelsRefs {
    final manager = $$PhotoLabelsTableTableManager($_db, $_db.photoLabels)
        .filter(
          (f) => f.assetId.assetId.sqlEquals($_itemColumn<String>('asset_id')!),
        );

    final cache = $_typedResult.readTableOrNull(_photoLabelsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PhotoTextsTable, List<PhotoText>>
  _photoTextsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.photoTexts,
    aliasName: 'photo_assets__asset_id__photo_texts__asset_id',
  );

  $$PhotoTextsTableProcessedTableManager get photoTextsRefs {
    final manager = $$PhotoTextsTableTableManager($_db, $_db.photoTexts).filter(
      (f) => f.assetId.assetId.sqlEquals($_itemColumn<String>('asset_id')!),
    );

    final cache = $_typedResult.readTableOrNull(_photoTextsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FaceEmbeddingsTable, List<FaceEmbedding>>
  _faceEmbeddingsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.faceEmbeddings,
    aliasName: 'photo_assets__asset_id__face_embeddings__asset_id',
  );

  $$FaceEmbeddingsTableProcessedTableManager get faceEmbeddingsRefs {
    final manager = $$FaceEmbeddingsTableTableManager($_db, $_db.faceEmbeddings)
        .filter(
          (f) => f.assetId.assetId.sqlEquals($_itemColumn<String>('asset_id')!),
        );

    final cache = $_typedResult.readTableOrNull(_faceEmbeddingsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PhotoAssetsTableFilterComposer
    extends Composer<_$AppDatabase, $PhotoAssetsTable> {
  $$PhotoAssetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isVideo => $composableBuilder(
    column: $table.isVideo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get indexedAt => $composableBuilder(
    column: $table.indexedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> photoLabelsRefs(
    Expression<bool> Function($$PhotoLabelsTableFilterComposer f) f,
  ) {
    final $$PhotoLabelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assetId,
      referencedTable: $db.photoLabels,
      getReferencedColumn: (t) => t.assetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotoLabelsTableFilterComposer(
            $db: $db,
            $table: $db.photoLabels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> photoTextsRefs(
    Expression<bool> Function($$PhotoTextsTableFilterComposer f) f,
  ) {
    final $$PhotoTextsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assetId,
      referencedTable: $db.photoTexts,
      getReferencedColumn: (t) => t.assetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotoTextsTableFilterComposer(
            $db: $db,
            $table: $db.photoTexts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> faceEmbeddingsRefs(
    Expression<bool> Function($$FaceEmbeddingsTableFilterComposer f) f,
  ) {
    final $$FaceEmbeddingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assetId,
      referencedTable: $db.faceEmbeddings,
      getReferencedColumn: (t) => t.assetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FaceEmbeddingsTableFilterComposer(
            $db: $db,
            $table: $db.faceEmbeddings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PhotoAssetsTableOrderingComposer
    extends Composer<_$AppDatabase, $PhotoAssetsTable> {
  $$PhotoAssetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isVideo => $composableBuilder(
    column: $table.isVideo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get indexedAt => $composableBuilder(
    column: $table.indexedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PhotoAssetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PhotoAssetsTable> {
  $$PhotoAssetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get assetId =>
      $composableBuilder(column: $table.assetId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get isVideo =>
      $composableBuilder(column: $table.isVideo, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<DateTime> get indexedAt =>
      $composableBuilder(column: $table.indexedAt, builder: (column) => column);

  Expression<T> photoLabelsRefs<T extends Object>(
    Expression<T> Function($$PhotoLabelsTableAnnotationComposer a) f,
  ) {
    final $$PhotoLabelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assetId,
      referencedTable: $db.photoLabels,
      getReferencedColumn: (t) => t.assetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotoLabelsTableAnnotationComposer(
            $db: $db,
            $table: $db.photoLabels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> photoTextsRefs<T extends Object>(
    Expression<T> Function($$PhotoTextsTableAnnotationComposer a) f,
  ) {
    final $$PhotoTextsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assetId,
      referencedTable: $db.photoTexts,
      getReferencedColumn: (t) => t.assetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotoTextsTableAnnotationComposer(
            $db: $db,
            $table: $db.photoTexts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> faceEmbeddingsRefs<T extends Object>(
    Expression<T> Function($$FaceEmbeddingsTableAnnotationComposer a) f,
  ) {
    final $$FaceEmbeddingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assetId,
      referencedTable: $db.faceEmbeddings,
      getReferencedColumn: (t) => t.assetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FaceEmbeddingsTableAnnotationComposer(
            $db: $db,
            $table: $db.faceEmbeddings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PhotoAssetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PhotoAssetsTable,
          PhotoAsset,
          $$PhotoAssetsTableFilterComposer,
          $$PhotoAssetsTableOrderingComposer,
          $$PhotoAssetsTableAnnotationComposer,
          $$PhotoAssetsTableCreateCompanionBuilder,
          $$PhotoAssetsTableUpdateCompanionBuilder,
          (PhotoAsset, $$PhotoAssetsTableReferences),
          PhotoAsset,
          PrefetchHooks Function({
            bool photoLabelsRefs,
            bool photoTextsRefs,
            bool faceEmbeddingsRefs,
          })
        > {
  $$PhotoAssetsTableTableManager(_$AppDatabase db, $PhotoAssetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PhotoAssetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PhotoAssetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PhotoAssetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> assetId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<bool> isVideo = const Value.absent(),
                Value<int> width = const Value.absent(),
                Value<int> height = const Value.absent(),
                Value<DateTime> indexedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PhotoAssetsCompanion(
                assetId: assetId,
                createdAt: createdAt,
                isVideo: isVideo,
                width: width,
                height: height,
                indexedAt: indexedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String assetId,
                required DateTime createdAt,
                required bool isVideo,
                required int width,
                required int height,
                required DateTime indexedAt,
                Value<int> rowid = const Value.absent(),
              }) => PhotoAssetsCompanion.insert(
                assetId: assetId,
                createdAt: createdAt,
                isVideo: isVideo,
                width: width,
                height: height,
                indexedAt: indexedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PhotoAssetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                photoLabelsRefs = false,
                photoTextsRefs = false,
                faceEmbeddingsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (photoLabelsRefs) db.photoLabels,
                    if (photoTextsRefs) db.photoTexts,
                    if (faceEmbeddingsRefs) db.faceEmbeddings,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (photoLabelsRefs)
                        await $_getPrefetchedData<
                          PhotoAsset,
                          $PhotoAssetsTable,
                          PhotoLabel
                        >(
                          currentTable: table,
                          referencedTable: $$PhotoAssetsTableReferences
                              ._photoLabelsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PhotoAssetsTableReferences(
                                db,
                                table,
                                p0,
                              ).photoLabelsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.assetId == item.assetId,
                              ),
                          typedResults: items,
                        ),
                      if (photoTextsRefs)
                        await $_getPrefetchedData<
                          PhotoAsset,
                          $PhotoAssetsTable,
                          PhotoText
                        >(
                          currentTable: table,
                          referencedTable: $$PhotoAssetsTableReferences
                              ._photoTextsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PhotoAssetsTableReferences(
                                db,
                                table,
                                p0,
                              ).photoTextsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.assetId == item.assetId,
                              ),
                          typedResults: items,
                        ),
                      if (faceEmbeddingsRefs)
                        await $_getPrefetchedData<
                          PhotoAsset,
                          $PhotoAssetsTable,
                          FaceEmbedding
                        >(
                          currentTable: table,
                          referencedTable: $$PhotoAssetsTableReferences
                              ._faceEmbeddingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PhotoAssetsTableReferences(
                                db,
                                table,
                                p0,
                              ).faceEmbeddingsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.assetId == item.assetId,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PhotoAssetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PhotoAssetsTable,
      PhotoAsset,
      $$PhotoAssetsTableFilterComposer,
      $$PhotoAssetsTableOrderingComposer,
      $$PhotoAssetsTableAnnotationComposer,
      $$PhotoAssetsTableCreateCompanionBuilder,
      $$PhotoAssetsTableUpdateCompanionBuilder,
      (PhotoAsset, $$PhotoAssetsTableReferences),
      PhotoAsset,
      PrefetchHooks Function({
        bool photoLabelsRefs,
        bool photoTextsRefs,
        bool faceEmbeddingsRefs,
      })
    >;
typedef $$PhotoLabelsTableCreateCompanionBuilder =
    PhotoLabelsCompanion Function({
      Value<int> id,
      required String assetId,
      required String label,
      required double confidence,
    });
typedef $$PhotoLabelsTableUpdateCompanionBuilder =
    PhotoLabelsCompanion Function({
      Value<int> id,
      Value<String> assetId,
      Value<String> label,
      Value<double> confidence,
    });

final class $$PhotoLabelsTableReferences
    extends BaseReferences<_$AppDatabase, $PhotoLabelsTable, PhotoLabel> {
  $$PhotoLabelsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PhotoAssetsTable _assetIdTable(_$AppDatabase db) => db.photoAssets
      .createAlias('photo_labels__asset_id__photo_assets__asset_id');

  $$PhotoAssetsTableProcessedTableManager get assetId {
    final $_column = $_itemColumn<String>('asset_id')!;

    final manager = $$PhotoAssetsTableTableManager(
      $_db,
      $_db.photoAssets,
    ).filter((f) => f.assetId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_assetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PhotoLabelsTableFilterComposer
    extends Composer<_$AppDatabase, $PhotoLabelsTable> {
  $$PhotoLabelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  $$PhotoAssetsTableFilterComposer get assetId {
    final $$PhotoAssetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assetId,
      referencedTable: $db.photoAssets,
      getReferencedColumn: (t) => t.assetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotoAssetsTableFilterComposer(
            $db: $db,
            $table: $db.photoAssets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PhotoLabelsTableOrderingComposer
    extends Composer<_$AppDatabase, $PhotoLabelsTable> {
  $$PhotoLabelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  $$PhotoAssetsTableOrderingComposer get assetId {
    final $$PhotoAssetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assetId,
      referencedTable: $db.photoAssets,
      getReferencedColumn: (t) => t.assetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotoAssetsTableOrderingComposer(
            $db: $db,
            $table: $db.photoAssets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PhotoLabelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PhotoLabelsTable> {
  $$PhotoLabelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  $$PhotoAssetsTableAnnotationComposer get assetId {
    final $$PhotoAssetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assetId,
      referencedTable: $db.photoAssets,
      getReferencedColumn: (t) => t.assetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotoAssetsTableAnnotationComposer(
            $db: $db,
            $table: $db.photoAssets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PhotoLabelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PhotoLabelsTable,
          PhotoLabel,
          $$PhotoLabelsTableFilterComposer,
          $$PhotoLabelsTableOrderingComposer,
          $$PhotoLabelsTableAnnotationComposer,
          $$PhotoLabelsTableCreateCompanionBuilder,
          $$PhotoLabelsTableUpdateCompanionBuilder,
          (PhotoLabel, $$PhotoLabelsTableReferences),
          PhotoLabel,
          PrefetchHooks Function({bool assetId})
        > {
  $$PhotoLabelsTableTableManager(_$AppDatabase db, $PhotoLabelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PhotoLabelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PhotoLabelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PhotoLabelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> assetId = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<double> confidence = const Value.absent(),
              }) => PhotoLabelsCompanion(
                id: id,
                assetId: assetId,
                label: label,
                confidence: confidence,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String assetId,
                required String label,
                required double confidence,
              }) => PhotoLabelsCompanion.insert(
                id: id,
                assetId: assetId,
                label: label,
                confidence: confidence,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PhotoLabelsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({assetId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (assetId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.assetId,
                                referencedTable: $$PhotoLabelsTableReferences
                                    ._assetIdTable(db),
                                referencedColumn: $$PhotoLabelsTableReferences
                                    ._assetIdTable(db)
                                    .assetId,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PhotoLabelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PhotoLabelsTable,
      PhotoLabel,
      $$PhotoLabelsTableFilterComposer,
      $$PhotoLabelsTableOrderingComposer,
      $$PhotoLabelsTableAnnotationComposer,
      $$PhotoLabelsTableCreateCompanionBuilder,
      $$PhotoLabelsTableUpdateCompanionBuilder,
      (PhotoLabel, $$PhotoLabelsTableReferences),
      PhotoLabel,
      PrefetchHooks Function({bool assetId})
    >;
typedef $$PhotoTextsTableCreateCompanionBuilder =
    PhotoTextsCompanion Function({
      required String assetId,
      required String content,
      Value<int> rowid,
    });
typedef $$PhotoTextsTableUpdateCompanionBuilder =
    PhotoTextsCompanion Function({
      Value<String> assetId,
      Value<String> content,
      Value<int> rowid,
    });

final class $$PhotoTextsTableReferences
    extends BaseReferences<_$AppDatabase, $PhotoTextsTable, PhotoText> {
  $$PhotoTextsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PhotoAssetsTable _assetIdTable(_$AppDatabase db) => db.photoAssets
      .createAlias('photo_texts__asset_id__photo_assets__asset_id');

  $$PhotoAssetsTableProcessedTableManager get assetId {
    final $_column = $_itemColumn<String>('asset_id')!;

    final manager = $$PhotoAssetsTableTableManager(
      $_db,
      $_db.photoAssets,
    ).filter((f) => f.assetId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_assetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PhotoTextsTableFilterComposer
    extends Composer<_$AppDatabase, $PhotoTextsTable> {
  $$PhotoTextsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  $$PhotoAssetsTableFilterComposer get assetId {
    final $$PhotoAssetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assetId,
      referencedTable: $db.photoAssets,
      getReferencedColumn: (t) => t.assetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotoAssetsTableFilterComposer(
            $db: $db,
            $table: $db.photoAssets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PhotoTextsTableOrderingComposer
    extends Composer<_$AppDatabase, $PhotoTextsTable> {
  $$PhotoTextsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  $$PhotoAssetsTableOrderingComposer get assetId {
    final $$PhotoAssetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assetId,
      referencedTable: $db.photoAssets,
      getReferencedColumn: (t) => t.assetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotoAssetsTableOrderingComposer(
            $db: $db,
            $table: $db.photoAssets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PhotoTextsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PhotoTextsTable> {
  $$PhotoTextsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  $$PhotoAssetsTableAnnotationComposer get assetId {
    final $$PhotoAssetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assetId,
      referencedTable: $db.photoAssets,
      getReferencedColumn: (t) => t.assetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotoAssetsTableAnnotationComposer(
            $db: $db,
            $table: $db.photoAssets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PhotoTextsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PhotoTextsTable,
          PhotoText,
          $$PhotoTextsTableFilterComposer,
          $$PhotoTextsTableOrderingComposer,
          $$PhotoTextsTableAnnotationComposer,
          $$PhotoTextsTableCreateCompanionBuilder,
          $$PhotoTextsTableUpdateCompanionBuilder,
          (PhotoText, $$PhotoTextsTableReferences),
          PhotoText,
          PrefetchHooks Function({bool assetId})
        > {
  $$PhotoTextsTableTableManager(_$AppDatabase db, $PhotoTextsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PhotoTextsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PhotoTextsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PhotoTextsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> assetId = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PhotoTextsCompanion(
                assetId: assetId,
                content: content,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String assetId,
                required String content,
                Value<int> rowid = const Value.absent(),
              }) => PhotoTextsCompanion.insert(
                assetId: assetId,
                content: content,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PhotoTextsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({assetId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (assetId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.assetId,
                                referencedTable: $$PhotoTextsTableReferences
                                    ._assetIdTable(db),
                                referencedColumn: $$PhotoTextsTableReferences
                                    ._assetIdTable(db)
                                    .assetId,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PhotoTextsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PhotoTextsTable,
      PhotoText,
      $$PhotoTextsTableFilterComposer,
      $$PhotoTextsTableOrderingComposer,
      $$PhotoTextsTableAnnotationComposer,
      $$PhotoTextsTableCreateCompanionBuilder,
      $$PhotoTextsTableUpdateCompanionBuilder,
      (PhotoText, $$PhotoTextsTableReferences),
      PhotoText,
      PrefetchHooks Function({bool assetId})
    >;
typedef $$PersonsTableCreateCompanionBuilder =
    PersonsCompanion Function({
      Value<int> id,
      Value<String?> displayName,
      Value<String?> coverAssetId,
      required DateTime createdAt,
    });
typedef $$PersonsTableUpdateCompanionBuilder =
    PersonsCompanion Function({
      Value<int> id,
      Value<String?> displayName,
      Value<String?> coverAssetId,
      Value<DateTime> createdAt,
    });

final class $$PersonsTableReferences
    extends BaseReferences<_$AppDatabase, $PersonsTable, Person> {
  $$PersonsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$FaceEmbeddingsTable, List<FaceEmbedding>>
  _faceEmbeddingsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.faceEmbeddings,
    aliasName: 'persons__id__face_embeddings__person_id',
  );

  $$FaceEmbeddingsTableProcessedTableManager get faceEmbeddingsRefs {
    final manager = $$FaceEmbeddingsTableTableManager(
      $_db,
      $_db.faceEmbeddings,
    ).filter((f) => f.personId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_faceEmbeddingsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PersonsTableFilterComposer
    extends Composer<_$AppDatabase, $PersonsTable> {
  $$PersonsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverAssetId => $composableBuilder(
    column: $table.coverAssetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> faceEmbeddingsRefs(
    Expression<bool> Function($$FaceEmbeddingsTableFilterComposer f) f,
  ) {
    final $$FaceEmbeddingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.faceEmbeddings,
      getReferencedColumn: (t) => t.personId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FaceEmbeddingsTableFilterComposer(
            $db: $db,
            $table: $db.faceEmbeddings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PersonsTableOrderingComposer
    extends Composer<_$AppDatabase, $PersonsTable> {
  $$PersonsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverAssetId => $composableBuilder(
    column: $table.coverAssetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PersonsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PersonsTable> {
  $$PersonsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverAssetId => $composableBuilder(
    column: $table.coverAssetId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> faceEmbeddingsRefs<T extends Object>(
    Expression<T> Function($$FaceEmbeddingsTableAnnotationComposer a) f,
  ) {
    final $$FaceEmbeddingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.faceEmbeddings,
      getReferencedColumn: (t) => t.personId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FaceEmbeddingsTableAnnotationComposer(
            $db: $db,
            $table: $db.faceEmbeddings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PersonsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PersonsTable,
          Person,
          $$PersonsTableFilterComposer,
          $$PersonsTableOrderingComposer,
          $$PersonsTableAnnotationComposer,
          $$PersonsTableCreateCompanionBuilder,
          $$PersonsTableUpdateCompanionBuilder,
          (Person, $$PersonsTableReferences),
          Person,
          PrefetchHooks Function({bool faceEmbeddingsRefs})
        > {
  $$PersonsTableTableManager(_$AppDatabase db, $PersonsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PersonsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PersonsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PersonsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<String?> coverAssetId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => PersonsCompanion(
                id: id,
                displayName: displayName,
                coverAssetId: coverAssetId,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<String?> coverAssetId = const Value.absent(),
                required DateTime createdAt,
              }) => PersonsCompanion.insert(
                id: id,
                displayName: displayName,
                coverAssetId: coverAssetId,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PersonsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({faceEmbeddingsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (faceEmbeddingsRefs) db.faceEmbeddings,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (faceEmbeddingsRefs)
                    await $_getPrefetchedData<
                      Person,
                      $PersonsTable,
                      FaceEmbedding
                    >(
                      currentTable: table,
                      referencedTable: $$PersonsTableReferences
                          ._faceEmbeddingsRefsTable(db),
                      managerFromTypedResult: (p0) => $$PersonsTableReferences(
                        db,
                        table,
                        p0,
                      ).faceEmbeddingsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.personId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PersonsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PersonsTable,
      Person,
      $$PersonsTableFilterComposer,
      $$PersonsTableOrderingComposer,
      $$PersonsTableAnnotationComposer,
      $$PersonsTableCreateCompanionBuilder,
      $$PersonsTableUpdateCompanionBuilder,
      (Person, $$PersonsTableReferences),
      Person,
      PrefetchHooks Function({bool faceEmbeddingsRefs})
    >;
typedef $$FaceEmbeddingsTableCreateCompanionBuilder =
    FaceEmbeddingsCompanion Function({
      Value<int> id,
      required String assetId,
      Value<int?> personId,
      required Uint8List embedding,
      required int left,
      required int top,
      required int right,
      required int bottom,
    });
typedef $$FaceEmbeddingsTableUpdateCompanionBuilder =
    FaceEmbeddingsCompanion Function({
      Value<int> id,
      Value<String> assetId,
      Value<int?> personId,
      Value<Uint8List> embedding,
      Value<int> left,
      Value<int> top,
      Value<int> right,
      Value<int> bottom,
    });

final class $$FaceEmbeddingsTableReferences
    extends BaseReferences<_$AppDatabase, $FaceEmbeddingsTable, FaceEmbedding> {
  $$FaceEmbeddingsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PhotoAssetsTable _assetIdTable(_$AppDatabase db) => db.photoAssets
      .createAlias('face_embeddings__asset_id__photo_assets__asset_id');

  $$PhotoAssetsTableProcessedTableManager get assetId {
    final $_column = $_itemColumn<String>('asset_id')!;

    final manager = $$PhotoAssetsTableTableManager(
      $_db,
      $_db.photoAssets,
    ).filter((f) => f.assetId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_assetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PersonsTable _personIdTable(_$AppDatabase db) =>
      db.persons.createAlias('face_embeddings__person_id__persons__id');

  $$PersonsTableProcessedTableManager? get personId {
    final $_column = $_itemColumn<int>('person_id');
    if ($_column == null) return null;
    final manager = $$PersonsTableTableManager(
      $_db,
      $_db.persons,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_personIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FaceEmbeddingsTableFilterComposer
    extends Composer<_$AppDatabase, $FaceEmbeddingsTable> {
  $$FaceEmbeddingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get left => $composableBuilder(
    column: $table.left,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get top => $composableBuilder(
    column: $table.top,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get right => $composableBuilder(
    column: $table.right,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bottom => $composableBuilder(
    column: $table.bottom,
    builder: (column) => ColumnFilters(column),
  );

  $$PhotoAssetsTableFilterComposer get assetId {
    final $$PhotoAssetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assetId,
      referencedTable: $db.photoAssets,
      getReferencedColumn: (t) => t.assetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotoAssetsTableFilterComposer(
            $db: $db,
            $table: $db.photoAssets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PersonsTableFilterComposer get personId {
    final $$PersonsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.persons,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PersonsTableFilterComposer(
            $db: $db,
            $table: $db.persons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FaceEmbeddingsTableOrderingComposer
    extends Composer<_$AppDatabase, $FaceEmbeddingsTable> {
  $$FaceEmbeddingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get left => $composableBuilder(
    column: $table.left,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get top => $composableBuilder(
    column: $table.top,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get right => $composableBuilder(
    column: $table.right,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bottom => $composableBuilder(
    column: $table.bottom,
    builder: (column) => ColumnOrderings(column),
  );

  $$PhotoAssetsTableOrderingComposer get assetId {
    final $$PhotoAssetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assetId,
      referencedTable: $db.photoAssets,
      getReferencedColumn: (t) => t.assetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotoAssetsTableOrderingComposer(
            $db: $db,
            $table: $db.photoAssets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PersonsTableOrderingComposer get personId {
    final $$PersonsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.persons,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PersonsTableOrderingComposer(
            $db: $db,
            $table: $db.persons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FaceEmbeddingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FaceEmbeddingsTable> {
  $$FaceEmbeddingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<Uint8List> get embedding =>
      $composableBuilder(column: $table.embedding, builder: (column) => column);

  GeneratedColumn<int> get left =>
      $composableBuilder(column: $table.left, builder: (column) => column);

  GeneratedColumn<int> get top =>
      $composableBuilder(column: $table.top, builder: (column) => column);

  GeneratedColumn<int> get right =>
      $composableBuilder(column: $table.right, builder: (column) => column);

  GeneratedColumn<int> get bottom =>
      $composableBuilder(column: $table.bottom, builder: (column) => column);

  $$PhotoAssetsTableAnnotationComposer get assetId {
    final $$PhotoAssetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.assetId,
      referencedTable: $db.photoAssets,
      getReferencedColumn: (t) => t.assetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotoAssetsTableAnnotationComposer(
            $db: $db,
            $table: $db.photoAssets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PersonsTableAnnotationComposer get personId {
    final $$PersonsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.persons,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PersonsTableAnnotationComposer(
            $db: $db,
            $table: $db.persons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FaceEmbeddingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FaceEmbeddingsTable,
          FaceEmbedding,
          $$FaceEmbeddingsTableFilterComposer,
          $$FaceEmbeddingsTableOrderingComposer,
          $$FaceEmbeddingsTableAnnotationComposer,
          $$FaceEmbeddingsTableCreateCompanionBuilder,
          $$FaceEmbeddingsTableUpdateCompanionBuilder,
          (FaceEmbedding, $$FaceEmbeddingsTableReferences),
          FaceEmbedding,
          PrefetchHooks Function({bool assetId, bool personId})
        > {
  $$FaceEmbeddingsTableTableManager(
    _$AppDatabase db,
    $FaceEmbeddingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FaceEmbeddingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FaceEmbeddingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FaceEmbeddingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> assetId = const Value.absent(),
                Value<int?> personId = const Value.absent(),
                Value<Uint8List> embedding = const Value.absent(),
                Value<int> left = const Value.absent(),
                Value<int> top = const Value.absent(),
                Value<int> right = const Value.absent(),
                Value<int> bottom = const Value.absent(),
              }) => FaceEmbeddingsCompanion(
                id: id,
                assetId: assetId,
                personId: personId,
                embedding: embedding,
                left: left,
                top: top,
                right: right,
                bottom: bottom,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String assetId,
                Value<int?> personId = const Value.absent(),
                required Uint8List embedding,
                required int left,
                required int top,
                required int right,
                required int bottom,
              }) => FaceEmbeddingsCompanion.insert(
                id: id,
                assetId: assetId,
                personId: personId,
                embedding: embedding,
                left: left,
                top: top,
                right: right,
                bottom: bottom,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FaceEmbeddingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({assetId = false, personId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (assetId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.assetId,
                                referencedTable: $$FaceEmbeddingsTableReferences
                                    ._assetIdTable(db),
                                referencedColumn:
                                    $$FaceEmbeddingsTableReferences
                                        ._assetIdTable(db)
                                        .assetId,
                              )
                              as T;
                    }
                    if (personId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.personId,
                                referencedTable: $$FaceEmbeddingsTableReferences
                                    ._personIdTable(db),
                                referencedColumn:
                                    $$FaceEmbeddingsTableReferences
                                        ._personIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FaceEmbeddingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FaceEmbeddingsTable,
      FaceEmbedding,
      $$FaceEmbeddingsTableFilterComposer,
      $$FaceEmbeddingsTableOrderingComposer,
      $$FaceEmbeddingsTableAnnotationComposer,
      $$FaceEmbeddingsTableCreateCompanionBuilder,
      $$FaceEmbeddingsTableUpdateCompanionBuilder,
      (FaceEmbedding, $$FaceEmbeddingsTableReferences),
      FaceEmbedding,
      PrefetchHooks Function({bool assetId, bool personId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$FavoritesTableTableManager get favorites =>
      $$FavoritesTableTableManager(_db, _db.favorites);
  $$AlbumsTableTableManager get albums =>
      $$AlbumsTableTableManager(_db, _db.albums);
  $$AlbumEntriesTableTableManager get albumEntries =>
      $$AlbumEntriesTableTableManager(_db, _db.albumEntries);
  $$EditInstructionsTableTableManager get editInstructions =>
      $$EditInstructionsTableTableManager(_db, _db.editInstructions);
  $$PhotoAssetsTableTableManager get photoAssets =>
      $$PhotoAssetsTableTableManager(_db, _db.photoAssets);
  $$PhotoLabelsTableTableManager get photoLabels =>
      $$PhotoLabelsTableTableManager(_db, _db.photoLabels);
  $$PhotoTextsTableTableManager get photoTexts =>
      $$PhotoTextsTableTableManager(_db, _db.photoTexts);
  $$PersonsTableTableManager get persons =>
      $$PersonsTableTableManager(_db, _db.persons);
  $$FaceEmbeddingsTableTableManager get faceEmbeddings =>
      $$FaceEmbeddingsTableTableManager(_db, _db.faceEmbeddings);
}
