// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CategoriesTable extends Categories with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 80),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorArgbMeta = const VerificationMeta('colorArgb');
  @override
  late final GeneratedColumn<int> colorArgb = GeneratedColumn<int>(
    'color_argb',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0xFF7F8C8D),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, colorArgb, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(Insertable<Category> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color_argb')) {
      context.handle(_colorArgbMeta, colorArgb.isAcceptableOrUnknown(data['color_argb']!, _colorArgbMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta, sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      colorArgb: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}color_argb'])!,
      sortOrder: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class Category extends DataClass implements Insertable<Category> {
  final int id;
  final String name;

  /// Packed ARGB color (unsigned, e.g. 0xFF2980B9).
  final int colorArgb;
  final int sortOrder;
  const Category({required this.id, required this.name, required this.colorArgb, required this.sortOrder});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['color_argb'] = Variable<int>(colorArgb);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(id: Value(id), name: Value(name), colorArgb: Value(colorArgb), sortOrder: Value(sortOrder));
  }

  factory Category.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      colorArgb: serializer.fromJson<int>(json['colorArgb']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'colorArgb': serializer.toJson<int>(colorArgb),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  Category copyWith({int? id, String? name, int? colorArgb, int? sortOrder}) => Category(
    id: id ?? this.id,
    name: name ?? this.name,
    colorArgb: colorArgb ?? this.colorArgb,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      colorArgb: data.colorArgb.present ? data.colorArgb.value : this.colorArgb,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorArgb: $colorArgb, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, colorArgb, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == this.id &&
          other.name == this.name &&
          other.colorArgb == this.colorArgb &&
          other.sortOrder == this.sortOrder);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> colorArgb;
  final Value<int> sortOrder;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.colorArgb = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  CategoriesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.colorArgb = const Value.absent(),
    this.sortOrder = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Category> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? colorArgb,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (colorArgb != null) 'color_argb': colorArgb,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  CategoriesCompanion copyWith({Value<int>? id, Value<String>? name, Value<int>? colorArgb, Value<int>? sortOrder}) {
    return CategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      colorArgb: colorArgb ?? this.colorArgb,
      sortOrder: sortOrder ?? this.sortOrder,
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
    if (colorArgb.present) {
      map['color_argb'] = Variable<int>(colorArgb.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorArgb: $colorArgb, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

class $ExercisesTable extends Exercises with TableInfo<$ExercisesTable, Exercise> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExercisesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 120),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('REFERENCES categories (id)'),
  );
  @override
  late final GeneratedColumnWithTypeConverter<ExerciseType, int> type = GeneratedColumn<int>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  ).withConverter<ExerciseType>($ExercisesTable.$convertertype);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _defaultRestTimeSecondsMeta = const VerificationMeta('defaultRestTimeSeconds');
  @override
  late final GeneratedColumn<int> defaultRestTimeSeconds = GeneratedColumn<int>(
    'default_rest_time_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isFavouriteMeta = const VerificationMeta('isFavourite');
  @override
  late final GeneratedColumn<bool> isFavourite = GeneratedColumn<bool>(
    'is_favourite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("is_favourite" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta('archived');
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("archived" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _weightIncrementMeta = const VerificationMeta('weightIncrement');
  @override
  late final GeneratedColumn<double> weightIncrement = GeneratedColumn<double>(
    'weight_increment',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    categoryId,
    type,
    notes,
    defaultRestTimeSeconds,
    isFavourite,
    archived,
    sortOrder,
    weightIncrement,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercises';
  @override
  VerificationContext validateIntegrity(Insertable<Exercise> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(_categoryIdMeta, categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta));
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(_notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('default_rest_time_seconds')) {
      context.handle(
        _defaultRestTimeSecondsMeta,
        defaultRestTimeSeconds.isAcceptableOrUnknown(data['default_rest_time_seconds']!, _defaultRestTimeSecondsMeta),
      );
    }
    if (data.containsKey('is_favourite')) {
      context.handle(_isFavouriteMeta, isFavourite.isAcceptableOrUnknown(data['is_favourite']!, _isFavouriteMeta));
    }
    if (data.containsKey('archived')) {
      context.handle(_archivedMeta, archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta, sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('weight_increment')) {
      context.handle(
        _weightIncrementMeta,
        weightIncrement.isAcceptableOrUnknown(data['weight_increment']!, _weightIncrementMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Exercise map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Exercise(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      categoryId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}category_id'])!,
      type: $ExercisesTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}type'])!,
      ),
      notes: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}notes']),
      defaultRestTimeSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}default_rest_time_seconds'],
      ),
      isFavourite: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}is_favourite'])!,
      archived: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}archived'])!,
      sortOrder: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      weightIncrement: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}weight_increment']),
    );
  }

  @override
  $ExercisesTable createAlias(String alias) {
    return $ExercisesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ExerciseType, int, int> $convertertype = const EnumIndexConverter<ExerciseType>(ExerciseType.values);
}

class Exercise extends DataClass implements Insertable<Exercise> {
  final int id;
  final String name;
  final int categoryId;
  final ExerciseType type;
  final String? notes;
  final int? defaultRestTimeSeconds;
  final bool isFavourite;
  final bool archived;
  final int sortOrder;
  final double? weightIncrement;
  const Exercise({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.type,
    this.notes,
    this.defaultRestTimeSeconds,
    required this.isFavourite,
    required this.archived,
    required this.sortOrder,
    this.weightIncrement,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['category_id'] = Variable<int>(categoryId);
    {
      map['type'] = Variable<int>($ExercisesTable.$convertertype.toSql(type));
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || defaultRestTimeSeconds != null) {
      map['default_rest_time_seconds'] = Variable<int>(defaultRestTimeSeconds);
    }
    map['is_favourite'] = Variable<bool>(isFavourite);
    map['archived'] = Variable<bool>(archived);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || weightIncrement != null) {
      map['weight_increment'] = Variable<double>(weightIncrement);
    }
    return map;
  }

  ExercisesCompanion toCompanion(bool nullToAbsent) {
    return ExercisesCompanion(
      id: Value(id),
      name: Value(name),
      categoryId: Value(categoryId),
      type: Value(type),
      notes: notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      defaultRestTimeSeconds: defaultRestTimeSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultRestTimeSeconds),
      isFavourite: Value(isFavourite),
      archived: Value(archived),
      sortOrder: Value(sortOrder),
      weightIncrement: weightIncrement == null && nullToAbsent ? const Value.absent() : Value(weightIncrement),
    );
  }

  factory Exercise.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Exercise(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      categoryId: serializer.fromJson<int>(json['categoryId']),
      type: $ExercisesTable.$convertertype.fromJson(serializer.fromJson<int>(json['type'])),
      notes: serializer.fromJson<String?>(json['notes']),
      defaultRestTimeSeconds: serializer.fromJson<int?>(json['defaultRestTimeSeconds']),
      isFavourite: serializer.fromJson<bool>(json['isFavourite']),
      archived: serializer.fromJson<bool>(json['archived']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      weightIncrement: serializer.fromJson<double?>(json['weightIncrement']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'categoryId': serializer.toJson<int>(categoryId),
      'type': serializer.toJson<int>($ExercisesTable.$convertertype.toJson(type)),
      'notes': serializer.toJson<String?>(notes),
      'defaultRestTimeSeconds': serializer.toJson<int?>(defaultRestTimeSeconds),
      'isFavourite': serializer.toJson<bool>(isFavourite),
      'archived': serializer.toJson<bool>(archived),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'weightIncrement': serializer.toJson<double?>(weightIncrement),
    };
  }

  Exercise copyWith({
    int? id,
    String? name,
    int? categoryId,
    ExerciseType? type,
    Value<String?> notes = const Value.absent(),
    Value<int?> defaultRestTimeSeconds = const Value.absent(),
    bool? isFavourite,
    bool? archived,
    int? sortOrder,
    Value<double?> weightIncrement = const Value.absent(),
  }) => Exercise(
    id: id ?? this.id,
    name: name ?? this.name,
    categoryId: categoryId ?? this.categoryId,
    type: type ?? this.type,
    notes: notes.present ? notes.value : this.notes,
    defaultRestTimeSeconds: defaultRestTimeSeconds.present ? defaultRestTimeSeconds.value : this.defaultRestTimeSeconds,
    isFavourite: isFavourite ?? this.isFavourite,
    archived: archived ?? this.archived,
    sortOrder: sortOrder ?? this.sortOrder,
    weightIncrement: weightIncrement.present ? weightIncrement.value : this.weightIncrement,
  );
  Exercise copyWithCompanion(ExercisesCompanion data) {
    return Exercise(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      categoryId: data.categoryId.present ? data.categoryId.value : this.categoryId,
      type: data.type.present ? data.type.value : this.type,
      notes: data.notes.present ? data.notes.value : this.notes,
      defaultRestTimeSeconds: data.defaultRestTimeSeconds.present
          ? data.defaultRestTimeSeconds.value
          : this.defaultRestTimeSeconds,
      isFavourite: data.isFavourite.present ? data.isFavourite.value : this.isFavourite,
      archived: data.archived.present ? data.archived.value : this.archived,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      weightIncrement: data.weightIncrement.present ? data.weightIncrement.value : this.weightIncrement,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Exercise(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('categoryId: $categoryId, ')
          ..write('type: $type, ')
          ..write('notes: $notes, ')
          ..write('defaultRestTimeSeconds: $defaultRestTimeSeconds, ')
          ..write('isFavourite: $isFavourite, ')
          ..write('archived: $archived, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('weightIncrement: $weightIncrement')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, categoryId, type, notes, defaultRestTimeSeconds, isFavourite, archived, sortOrder, weightIncrement);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Exercise &&
          other.id == this.id &&
          other.name == this.name &&
          other.categoryId == this.categoryId &&
          other.type == this.type &&
          other.notes == this.notes &&
          other.defaultRestTimeSeconds == this.defaultRestTimeSeconds &&
          other.isFavourite == this.isFavourite &&
          other.archived == this.archived &&
          other.sortOrder == this.sortOrder &&
          other.weightIncrement == this.weightIncrement);
}

class ExercisesCompanion extends UpdateCompanion<Exercise> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> categoryId;
  final Value<ExerciseType> type;
  final Value<String?> notes;
  final Value<int?> defaultRestTimeSeconds;
  final Value<bool> isFavourite;
  final Value<bool> archived;
  final Value<int> sortOrder;
  final Value<double?> weightIncrement;
  const ExercisesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.type = const Value.absent(),
    this.notes = const Value.absent(),
    this.defaultRestTimeSeconds = const Value.absent(),
    this.isFavourite = const Value.absent(),
    this.archived = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.weightIncrement = const Value.absent(),
  });
  ExercisesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required int categoryId,
    this.type = const Value.absent(),
    this.notes = const Value.absent(),
    this.defaultRestTimeSeconds = const Value.absent(),
    this.isFavourite = const Value.absent(),
    this.archived = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.weightIncrement = const Value.absent(),
  }) : name = Value(name),
       categoryId = Value(categoryId);
  static Insertable<Exercise> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? categoryId,
    Expression<int>? type,
    Expression<String>? notes,
    Expression<int>? defaultRestTimeSeconds,
    Expression<bool>? isFavourite,
    Expression<bool>? archived,
    Expression<int>? sortOrder,
    Expression<double>? weightIncrement,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (categoryId != null) 'category_id': categoryId,
      if (type != null) 'type': type,
      if (notes != null) 'notes': notes,
      if (defaultRestTimeSeconds != null) 'default_rest_time_seconds': defaultRestTimeSeconds,
      if (isFavourite != null) 'is_favourite': isFavourite,
      if (archived != null) 'archived': archived,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (weightIncrement != null) 'weight_increment': weightIncrement,
    });
  }

  ExercisesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? categoryId,
    Value<ExerciseType>? type,
    Value<String?>? notes,
    Value<int?>? defaultRestTimeSeconds,
    Value<bool>? isFavourite,
    Value<bool>? archived,
    Value<int>? sortOrder,
    Value<double?>? weightIncrement,
  }) {
    return ExercisesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      type: type ?? this.type,
      notes: notes ?? this.notes,
      defaultRestTimeSeconds: defaultRestTimeSeconds ?? this.defaultRestTimeSeconds,
      isFavourite: isFavourite ?? this.isFavourite,
      archived: archived ?? this.archived,
      sortOrder: sortOrder ?? this.sortOrder,
      weightIncrement: weightIncrement ?? this.weightIncrement,
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
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (type.present) {
      map['type'] = Variable<int>($ExercisesTable.$convertertype.toSql(type.value));
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (defaultRestTimeSeconds.present) {
      map['default_rest_time_seconds'] = Variable<int>(defaultRestTimeSeconds.value);
    }
    if (isFavourite.present) {
      map['is_favourite'] = Variable<bool>(isFavourite.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (weightIncrement.present) {
      map['weight_increment'] = Variable<double>(weightIncrement.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExercisesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('categoryId: $categoryId, ')
          ..write('type: $type, ')
          ..write('notes: $notes, ')
          ..write('defaultRestTimeSeconds: $defaultRestTimeSeconds, ')
          ..write('isFavourite: $isFavourite, ')
          ..write('archived: $archived, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('weightIncrement: $weightIncrement')
          ..write(')'))
        .toString();
  }
}

class $ExerciseMultipliersTable extends ExerciseMultipliers with TableInfo<$ExerciseMultipliersTable, ExerciseMultiplier> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExerciseMultipliersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta('exerciseId');
  @override
  late final GeneratedColumn<int> exerciseId = GeneratedColumn<int>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('REFERENCES exercises (id)'),
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
  static const VerificationMeta _factorMeta = const VerificationMeta('factor');
  @override
  late final GeneratedColumn<double> factor = GeneratedColumn<double>(
    'factor',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.0),
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta('enabled');
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("enabled" IN (0, 1))'),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, exerciseId, label, factor, enabled, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercise_multipliers';
  @override
  VerificationContext validateIntegrity(Insertable<ExerciseMultiplier> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('exercise_id')) {
      context.handle(_exerciseIdMeta, exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta));
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(_labelMeta, label.isAcceptableOrUnknown(data['label']!, _labelMeta));
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('factor')) {
      context.handle(_factorMeta, factor.isAcceptableOrUnknown(data['factor']!, _factorMeta));
    }
    if (data.containsKey('enabled')) {
      context.handle(_enabledMeta, enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta, sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExerciseMultiplier map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExerciseMultiplier(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      exerciseId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}exercise_id'])!,
      label: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}label'])!,
      factor: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}factor'])!,
      enabled: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}enabled'])!,
      sortOrder: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
    );
  }

  @override
  $ExerciseMultipliersTable createAlias(String alias) {
    return $ExerciseMultipliersTable(attachedDatabase, alias);
  }
}

class ExerciseMultiplier extends DataClass implements Insertable<ExerciseMultiplier> {
  final int id;
  final int exerciseId;
  final String label;
  final double factor;
  final bool enabled;
  final int sortOrder;
  const ExerciseMultiplier({
    required this.id,
    required this.exerciseId,
    required this.label,
    required this.factor,
    required this.enabled,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['exercise_id'] = Variable<int>(exerciseId);
    map['label'] = Variable<String>(label);
    map['factor'] = Variable<double>(factor);
    map['enabled'] = Variable<bool>(enabled);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  ExerciseMultipliersCompanion toCompanion(bool nullToAbsent) {
    return ExerciseMultipliersCompanion(
      id: Value(id),
      exerciseId: Value(exerciseId),
      label: Value(label),
      factor: Value(factor),
      enabled: Value(enabled),
      sortOrder: Value(sortOrder),
    );
  }

  factory ExerciseMultiplier.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExerciseMultiplier(
      id: serializer.fromJson<int>(json['id']),
      exerciseId: serializer.fromJson<int>(json['exerciseId']),
      label: serializer.fromJson<String>(json['label']),
      factor: serializer.fromJson<double>(json['factor']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'exerciseId': serializer.toJson<int>(exerciseId),
      'label': serializer.toJson<String>(label),
      'factor': serializer.toJson<double>(factor),
      'enabled': serializer.toJson<bool>(enabled),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  ExerciseMultiplier copyWith({int? id, int? exerciseId, String? label, double? factor, bool? enabled, int? sortOrder}) =>
      ExerciseMultiplier(
        id: id ?? this.id,
        exerciseId: exerciseId ?? this.exerciseId,
        label: label ?? this.label,
        factor: factor ?? this.factor,
        enabled: enabled ?? this.enabled,
        sortOrder: sortOrder ?? this.sortOrder,
      );
  ExerciseMultiplier copyWithCompanion(ExerciseMultipliersCompanion data) {
    return ExerciseMultiplier(
      id: data.id.present ? data.id.value : this.id,
      exerciseId: data.exerciseId.present ? data.exerciseId.value : this.exerciseId,
      label: data.label.present ? data.label.value : this.label,
      factor: data.factor.present ? data.factor.value : this.factor,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseMultiplier(')
          ..write('id: $id, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('label: $label, ')
          ..write('factor: $factor, ')
          ..write('enabled: $enabled, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, exerciseId, label, factor, enabled, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExerciseMultiplier &&
          other.id == this.id &&
          other.exerciseId == this.exerciseId &&
          other.label == this.label &&
          other.factor == this.factor &&
          other.enabled == this.enabled &&
          other.sortOrder == this.sortOrder);
}

class ExerciseMultipliersCompanion extends UpdateCompanion<ExerciseMultiplier> {
  final Value<int> id;
  final Value<int> exerciseId;
  final Value<String> label;
  final Value<double> factor;
  final Value<bool> enabled;
  final Value<int> sortOrder;
  const ExerciseMultipliersCompanion({
    this.id = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.label = const Value.absent(),
    this.factor = const Value.absent(),
    this.enabled = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  ExerciseMultipliersCompanion.insert({
    this.id = const Value.absent(),
    required int exerciseId,
    required String label,
    this.factor = const Value.absent(),
    this.enabled = const Value.absent(),
    this.sortOrder = const Value.absent(),
  }) : exerciseId = Value(exerciseId),
       label = Value(label);
  static Insertable<ExerciseMultiplier> custom({
    Expression<int>? id,
    Expression<int>? exerciseId,
    Expression<String>? label,
    Expression<double>? factor,
    Expression<bool>? enabled,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (label != null) 'label': label,
      if (factor != null) 'factor': factor,
      if (enabled != null) 'enabled': enabled,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  ExerciseMultipliersCompanion copyWith({
    Value<int>? id,
    Value<int>? exerciseId,
    Value<String>? label,
    Value<double>? factor,
    Value<bool>? enabled,
    Value<int>? sortOrder,
  }) {
    return ExerciseMultipliersCompanion(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      label: label ?? this.label,
      factor: factor ?? this.factor,
      enabled: enabled ?? this.enabled,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<int>(exerciseId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (factor.present) {
      map['factor'] = Variable<double>(factor.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseMultipliersCompanion(')
          ..write('id: $id, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('label: $label, ')
          ..write('factor: $factor, ')
          ..write('enabled: $enabled, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

class $WorkoutSetsTable extends WorkoutSets with TableInfo<$WorkoutSetsTable, WorkoutSet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutSetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta('exerciseId');
  @override
  late final GeneratedColumn<int> exerciseId = GeneratedColumn<int>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('REFERENCES exercises (id)'),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawWeightMeta = const VerificationMeta('rawWeight');
  @override
  late final GeneratedColumn<double> rawWeight = GeneratedColumn<double>(
    'raw_weight',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _weightMultiplierMeta = const VerificationMeta('weightMultiplier');
  @override
  late final GeneratedColumn<double> weightMultiplier = GeneratedColumn<double>(
    'weight_multiplier',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.0),
  );
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
    'reps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _distanceMeta = const VerificationMeta('distance');
  @override
  late final GeneratedColumn<double> distance = GeneratedColumn<double>(
    'distance',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta('durationSeconds');
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isCompleteMeta = const VerificationMeta('isComplete');
  @override
  late final GeneratedColumn<bool> isComplete = GeneratedColumn<bool>(
    'is_complete',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("is_complete" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceKeyMeta = const VerificationMeta('sourceKey');
  @override
  late final GeneratedColumn<String> sourceKey = GeneratedColumn<String>(
    'source_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isPlannedMeta = const VerificationMeta('isPlanned');
  @override
  late final GeneratedColumn<bool> isPlanned = GeneratedColumn<bool>(
    'is_planned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("is_planned" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _rpeMeta = const VerificationMeta('rpe');
  @override
  late final GeneratedColumn<double> rpe = GeneratedColumn<double>(
    'rpe',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _groupNameMeta = const VerificationMeta('groupName');
  @override
  late final GeneratedColumn<String> groupName = GeneratedColumn<String>(
    'group_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    exerciseId,
    date,
    rawWeight,
    weightMultiplier,
    reps,
    distance,
    durationSeconds,
    isComplete,
    note,
    createdAt,
    sourceKey,
    isPlanned,
    rpe,
    groupName,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_sets';
  @override
  VerificationContext validateIntegrity(Insertable<WorkoutSet> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('exercise_id')) {
      context.handle(_exerciseIdMeta, exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta));
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(_dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('raw_weight')) {
      context.handle(_rawWeightMeta, rawWeight.isAcceptableOrUnknown(data['raw_weight']!, _rawWeightMeta));
    }
    if (data.containsKey('weight_multiplier')) {
      context.handle(
        _weightMultiplierMeta,
        weightMultiplier.isAcceptableOrUnknown(data['weight_multiplier']!, _weightMultiplierMeta),
      );
    }
    if (data.containsKey('reps')) {
      context.handle(_repsMeta, reps.isAcceptableOrUnknown(data['reps']!, _repsMeta));
    }
    if (data.containsKey('distance')) {
      context.handle(_distanceMeta, distance.isAcceptableOrUnknown(data['distance']!, _distanceMeta));
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(data['duration_seconds']!, _durationSecondsMeta),
      );
    }
    if (data.containsKey('is_complete')) {
      context.handle(_isCompleteMeta, isComplete.isAcceptableOrUnknown(data['is_complete']!, _isCompleteMeta));
    }
    if (data.containsKey('note')) {
      context.handle(_noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('source_key')) {
      context.handle(_sourceKeyMeta, sourceKey.isAcceptableOrUnknown(data['source_key']!, _sourceKeyMeta));
    }
    if (data.containsKey('is_planned')) {
      context.handle(_isPlannedMeta, isPlanned.isAcceptableOrUnknown(data['is_planned']!, _isPlannedMeta));
    }
    if (data.containsKey('rpe')) {
      context.handle(_rpeMeta, rpe.isAcceptableOrUnknown(data['rpe']!, _rpeMeta));
    }
    if (data.containsKey('group_name')) {
      context.handle(_groupNameMeta, groupName.isAcceptableOrUnknown(data['group_name']!, _groupNameMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkoutSet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutSet(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      exerciseId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}exercise_id'])!,
      date: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}date'])!,
      rawWeight: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}raw_weight'])!,
      weightMultiplier: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}weight_multiplier'])!,
      reps: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}reps'])!,
      distance: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}distance'])!,
      durationSeconds: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}duration_seconds'])!,
      isComplete: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}is_complete'])!,
      note: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}note']),
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      sourceKey: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}source_key']),
      isPlanned: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}is_planned'])!,
      rpe: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}rpe']),
      groupName: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}group_name']),
    );
  }

  @override
  $WorkoutSetsTable createAlias(String alias) {
    return $WorkoutSetsTable(attachedDatabase, alias);
  }
}

class WorkoutSet extends DataClass implements Insertable<WorkoutSet> {
  final int id;
  final int exerciseId;

  /// Calendar day, `yyyy-MM-dd`.
  final String date;

  /// The number the user actually entered (before any multiplier).
  final double rawWeight;

  /// Product of enabled factors captured when the set was added.
  /// `effectiveWeight = rawWeight * weightMultiplier`.
  final double weightMultiplier;
  final int reps;
  final double distance;
  final int durationSeconds;
  final bool isComplete;
  final String? note;
  final DateTime createdAt;
  final String? sourceKey;
  final bool isPlanned;
  final double? rpe;
  final String? groupName;
  const WorkoutSet({
    required this.id,
    required this.exerciseId,
    required this.date,
    required this.rawWeight,
    required this.weightMultiplier,
    required this.reps,
    required this.distance,
    required this.durationSeconds,
    required this.isComplete,
    this.note,
    required this.createdAt,
    this.sourceKey,
    required this.isPlanned,
    this.rpe,
    this.groupName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['exercise_id'] = Variable<int>(exerciseId);
    map['date'] = Variable<String>(date);
    map['raw_weight'] = Variable<double>(rawWeight);
    map['weight_multiplier'] = Variable<double>(weightMultiplier);
    map['reps'] = Variable<int>(reps);
    map['distance'] = Variable<double>(distance);
    map['duration_seconds'] = Variable<int>(durationSeconds);
    map['is_complete'] = Variable<bool>(isComplete);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || sourceKey != null) {
      map['source_key'] = Variable<String>(sourceKey);
    }
    map['is_planned'] = Variable<bool>(isPlanned);
    if (!nullToAbsent || rpe != null) {
      map['rpe'] = Variable<double>(rpe);
    }
    if (!nullToAbsent || groupName != null) {
      map['group_name'] = Variable<String>(groupName);
    }
    return map;
  }

  WorkoutSetsCompanion toCompanion(bool nullToAbsent) {
    return WorkoutSetsCompanion(
      id: Value(id),
      exerciseId: Value(exerciseId),
      date: Value(date),
      rawWeight: Value(rawWeight),
      weightMultiplier: Value(weightMultiplier),
      reps: Value(reps),
      distance: Value(distance),
      durationSeconds: Value(durationSeconds),
      isComplete: Value(isComplete),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
      sourceKey: sourceKey == null && nullToAbsent ? const Value.absent() : Value(sourceKey),
      isPlanned: Value(isPlanned),
      rpe: rpe == null && nullToAbsent ? const Value.absent() : Value(rpe),
      groupName: groupName == null && nullToAbsent ? const Value.absent() : Value(groupName),
    );
  }

  factory WorkoutSet.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutSet(
      id: serializer.fromJson<int>(json['id']),
      exerciseId: serializer.fromJson<int>(json['exerciseId']),
      date: serializer.fromJson<String>(json['date']),
      rawWeight: serializer.fromJson<double>(json['rawWeight']),
      weightMultiplier: serializer.fromJson<double>(json['weightMultiplier']),
      reps: serializer.fromJson<int>(json['reps']),
      distance: serializer.fromJson<double>(json['distance']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
      isComplete: serializer.fromJson<bool>(json['isComplete']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      sourceKey: serializer.fromJson<String?>(json['sourceKey']),
      isPlanned: serializer.fromJson<bool>(json['isPlanned']),
      rpe: serializer.fromJson<double?>(json['rpe']),
      groupName: serializer.fromJson<String?>(json['groupName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'exerciseId': serializer.toJson<int>(exerciseId),
      'date': serializer.toJson<String>(date),
      'rawWeight': serializer.toJson<double>(rawWeight),
      'weightMultiplier': serializer.toJson<double>(weightMultiplier),
      'reps': serializer.toJson<int>(reps),
      'distance': serializer.toJson<double>(distance),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
      'isComplete': serializer.toJson<bool>(isComplete),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'sourceKey': serializer.toJson<String?>(sourceKey),
      'isPlanned': serializer.toJson<bool>(isPlanned),
      'rpe': serializer.toJson<double?>(rpe),
      'groupName': serializer.toJson<String?>(groupName),
    };
  }

  WorkoutSet copyWith({
    int? id,
    int? exerciseId,
    String? date,
    double? rawWeight,
    double? weightMultiplier,
    int? reps,
    double? distance,
    int? durationSeconds,
    bool? isComplete,
    Value<String?> note = const Value.absent(),
    DateTime? createdAt,
    Value<String?> sourceKey = const Value.absent(),
    bool? isPlanned,
    Value<double?> rpe = const Value.absent(),
    Value<String?> groupName = const Value.absent(),
  }) => WorkoutSet(
    id: id ?? this.id,
    exerciseId: exerciseId ?? this.exerciseId,
    date: date ?? this.date,
    rawWeight: rawWeight ?? this.rawWeight,
    weightMultiplier: weightMultiplier ?? this.weightMultiplier,
    reps: reps ?? this.reps,
    distance: distance ?? this.distance,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    isComplete: isComplete ?? this.isComplete,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
    sourceKey: sourceKey.present ? sourceKey.value : this.sourceKey,
    isPlanned: isPlanned ?? this.isPlanned,
    rpe: rpe.present ? rpe.value : this.rpe,
    groupName: groupName.present ? groupName.value : this.groupName,
  );
  WorkoutSet copyWithCompanion(WorkoutSetsCompanion data) {
    return WorkoutSet(
      id: data.id.present ? data.id.value : this.id,
      exerciseId: data.exerciseId.present ? data.exerciseId.value : this.exerciseId,
      date: data.date.present ? data.date.value : this.date,
      rawWeight: data.rawWeight.present ? data.rawWeight.value : this.rawWeight,
      weightMultiplier: data.weightMultiplier.present ? data.weightMultiplier.value : this.weightMultiplier,
      reps: data.reps.present ? data.reps.value : this.reps,
      distance: data.distance.present ? data.distance.value : this.distance,
      durationSeconds: data.durationSeconds.present ? data.durationSeconds.value : this.durationSeconds,
      isComplete: data.isComplete.present ? data.isComplete.value : this.isComplete,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      sourceKey: data.sourceKey.present ? data.sourceKey.value : this.sourceKey,
      isPlanned: data.isPlanned.present ? data.isPlanned.value : this.isPlanned,
      rpe: data.rpe.present ? data.rpe.value : this.rpe,
      groupName: data.groupName.present ? data.groupName.value : this.groupName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSet(')
          ..write('id: $id, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('date: $date, ')
          ..write('rawWeight: $rawWeight, ')
          ..write('weightMultiplier: $weightMultiplier, ')
          ..write('reps: $reps, ')
          ..write('distance: $distance, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('isComplete: $isComplete, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('sourceKey: $sourceKey, ')
          ..write('isPlanned: $isPlanned, ')
          ..write('rpe: $rpe, ')
          ..write('groupName: $groupName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    exerciseId,
    date,
    rawWeight,
    weightMultiplier,
    reps,
    distance,
    durationSeconds,
    isComplete,
    note,
    createdAt,
    sourceKey,
    isPlanned,
    rpe,
    groupName,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutSet &&
          other.id == this.id &&
          other.exerciseId == this.exerciseId &&
          other.date == this.date &&
          other.rawWeight == this.rawWeight &&
          other.weightMultiplier == this.weightMultiplier &&
          other.reps == this.reps &&
          other.distance == this.distance &&
          other.durationSeconds == this.durationSeconds &&
          other.isComplete == this.isComplete &&
          other.note == this.note &&
          other.createdAt == this.createdAt &&
          other.sourceKey == this.sourceKey &&
          other.isPlanned == this.isPlanned &&
          other.rpe == this.rpe &&
          other.groupName == this.groupName);
}

class WorkoutSetsCompanion extends UpdateCompanion<WorkoutSet> {
  final Value<int> id;
  final Value<int> exerciseId;
  final Value<String> date;
  final Value<double> rawWeight;
  final Value<double> weightMultiplier;
  final Value<int> reps;
  final Value<double> distance;
  final Value<int> durationSeconds;
  final Value<bool> isComplete;
  final Value<String?> note;
  final Value<DateTime> createdAt;
  final Value<String?> sourceKey;
  final Value<bool> isPlanned;
  final Value<double?> rpe;
  final Value<String?> groupName;
  const WorkoutSetsCompanion({
    this.id = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.date = const Value.absent(),
    this.rawWeight = const Value.absent(),
    this.weightMultiplier = const Value.absent(),
    this.reps = const Value.absent(),
    this.distance = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.isComplete = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.sourceKey = const Value.absent(),
    this.isPlanned = const Value.absent(),
    this.rpe = const Value.absent(),
    this.groupName = const Value.absent(),
  });
  WorkoutSetsCompanion.insert({
    this.id = const Value.absent(),
    required int exerciseId,
    required String date,
    this.rawWeight = const Value.absent(),
    this.weightMultiplier = const Value.absent(),
    this.reps = const Value.absent(),
    this.distance = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.isComplete = const Value.absent(),
    this.note = const Value.absent(),
    required DateTime createdAt,
    this.sourceKey = const Value.absent(),
    this.isPlanned = const Value.absent(),
    this.rpe = const Value.absent(),
    this.groupName = const Value.absent(),
  }) : exerciseId = Value(exerciseId),
       date = Value(date),
       createdAt = Value(createdAt);
  static Insertable<WorkoutSet> custom({
    Expression<int>? id,
    Expression<int>? exerciseId,
    Expression<String>? date,
    Expression<double>? rawWeight,
    Expression<double>? weightMultiplier,
    Expression<int>? reps,
    Expression<double>? distance,
    Expression<int>? durationSeconds,
    Expression<bool>? isComplete,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
    Expression<String>? sourceKey,
    Expression<bool>? isPlanned,
    Expression<double>? rpe,
    Expression<String>? groupName,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (date != null) 'date': date,
      if (rawWeight != null) 'raw_weight': rawWeight,
      if (weightMultiplier != null) 'weight_multiplier': weightMultiplier,
      if (reps != null) 'reps': reps,
      if (distance != null) 'distance': distance,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (isComplete != null) 'is_complete': isComplete,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (sourceKey != null) 'source_key': sourceKey,
      if (isPlanned != null) 'is_planned': isPlanned,
      if (rpe != null) 'rpe': rpe,
      if (groupName != null) 'group_name': groupName,
    });
  }

  WorkoutSetsCompanion copyWith({
    Value<int>? id,
    Value<int>? exerciseId,
    Value<String>? date,
    Value<double>? rawWeight,
    Value<double>? weightMultiplier,
    Value<int>? reps,
    Value<double>? distance,
    Value<int>? durationSeconds,
    Value<bool>? isComplete,
    Value<String?>? note,
    Value<DateTime>? createdAt,
    Value<String?>? sourceKey,
    Value<bool>? isPlanned,
    Value<double?>? rpe,
    Value<String?>? groupName,
  }) {
    return WorkoutSetsCompanion(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      date: date ?? this.date,
      rawWeight: rawWeight ?? this.rawWeight,
      weightMultiplier: weightMultiplier ?? this.weightMultiplier,
      reps: reps ?? this.reps,
      distance: distance ?? this.distance,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isComplete: isComplete ?? this.isComplete,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      sourceKey: sourceKey ?? this.sourceKey,
      isPlanned: isPlanned ?? this.isPlanned,
      rpe: rpe ?? this.rpe,
      groupName: groupName ?? this.groupName,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<int>(exerciseId.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (rawWeight.present) {
      map['raw_weight'] = Variable<double>(rawWeight.value);
    }
    if (weightMultiplier.present) {
      map['weight_multiplier'] = Variable<double>(weightMultiplier.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (distance.present) {
      map['distance'] = Variable<double>(distance.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (isComplete.present) {
      map['is_complete'] = Variable<bool>(isComplete.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (sourceKey.present) {
      map['source_key'] = Variable<String>(sourceKey.value);
    }
    if (isPlanned.present) {
      map['is_planned'] = Variable<bool>(isPlanned.value);
    }
    if (rpe.present) {
      map['rpe'] = Variable<double>(rpe.value);
    }
    if (groupName.present) {
      map['group_name'] = Variable<String>(groupName.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSetsCompanion(')
          ..write('id: $id, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('date: $date, ')
          ..write('rawWeight: $rawWeight, ')
          ..write('weightMultiplier: $weightMultiplier, ')
          ..write('reps: $reps, ')
          ..write('distance: $distance, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('isComplete: $isComplete, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('sourceKey: $sourceKey, ')
          ..write('isPlanned: $isPlanned, ')
          ..write('rpe: $rpe, ')
          ..write('groupName: $groupName')
          ..write(')'))
        .toString();
  }
}

class $WorkoutDayNotesTable extends WorkoutDayNotes with TableInfo<$WorkoutDayNotesTable, WorkoutDayNote> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutDayNotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _commentMeta = const VerificationMeta('comment');
  @override
  late final GeneratedColumn<String> comment = GeneratedColumn<String>(
    'comment',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, date, comment];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_day_notes';
  @override
  VerificationContext validateIntegrity(Insertable<WorkoutDayNote> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(_dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('comment')) {
      context.handle(_commentMeta, comment.isAcceptableOrUnknown(data['comment']!, _commentMeta));
    } else if (isInserting) {
      context.missing(_commentMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkoutDayNote map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutDayNote(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      date: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}date'])!,
      comment: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}comment'])!,
    );
  }

  @override
  $WorkoutDayNotesTable createAlias(String alias) {
    return $WorkoutDayNotesTable(attachedDatabase, alias);
  }
}

class WorkoutDayNote extends DataClass implements Insertable<WorkoutDayNote> {
  final int id;
  final String date;
  final String comment;
  const WorkoutDayNote({required this.id, required this.date, required this.comment});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<String>(date);
    map['comment'] = Variable<String>(comment);
    return map;
  }

  WorkoutDayNotesCompanion toCompanion(bool nullToAbsent) {
    return WorkoutDayNotesCompanion(id: Value(id), date: Value(date), comment: Value(comment));
  }

  factory WorkoutDayNote.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutDayNote(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<String>(json['date']),
      comment: serializer.fromJson<String>(json['comment']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<String>(date),
      'comment': serializer.toJson<String>(comment),
    };
  }

  WorkoutDayNote copyWith({int? id, String? date, String? comment}) =>
      WorkoutDayNote(id: id ?? this.id, date: date ?? this.date, comment: comment ?? this.comment);
  WorkoutDayNote copyWithCompanion(WorkoutDayNotesCompanion data) {
    return WorkoutDayNote(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      comment: data.comment.present ? data.comment.value : this.comment,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutDayNote(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('comment: $comment')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, date, comment);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutDayNote && other.id == this.id && other.date == this.date && other.comment == this.comment);
}

class WorkoutDayNotesCompanion extends UpdateCompanion<WorkoutDayNote> {
  final Value<int> id;
  final Value<String> date;
  final Value<String> comment;
  const WorkoutDayNotesCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.comment = const Value.absent(),
  });
  WorkoutDayNotesCompanion.insert({this.id = const Value.absent(), required String date, required String comment})
    : date = Value(date),
      comment = Value(comment);
  static Insertable<WorkoutDayNote> custom({Expression<int>? id, Expression<String>? date, Expression<String>? comment}) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (comment != null) 'comment': comment,
    });
  }

  WorkoutDayNotesCompanion copyWith({Value<int>? id, Value<String>? date, Value<String>? comment}) {
    return WorkoutDayNotesCompanion(id: id ?? this.id, date: date ?? this.date, comment: comment ?? this.comment);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (comment.present) {
      map['comment'] = Variable<String>(comment.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutDayNotesCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('comment: $comment')
          ..write(')'))
        .toString();
  }
}

class $PrResetMarkersTable extends PrResetMarkers with TableInfo<$PrResetMarkersTable, PrResetMarker> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PrResetMarkersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, date, note, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pr_reset_markers';
  @override
  VerificationContext validateIntegrity(Insertable<PrResetMarker> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(_dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('note')) {
      context.handle(_noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PrResetMarker map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PrResetMarker(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      date: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}date'])!,
      note: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}note']),
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $PrResetMarkersTable createAlias(String alias) {
    return $PrResetMarkersTable(attachedDatabase, alias);
  }
}

class PrResetMarker extends DataClass implements Insertable<PrResetMarker> {
  final int id;
  final String date;
  final String? note;
  final DateTime createdAt;
  const PrResetMarker({required this.id, required this.date, this.note, required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<String>(date);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PrResetMarkersCompanion toCompanion(bool nullToAbsent) {
    return PrResetMarkersCompanion(
      id: Value(id),
      date: Value(date),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
    );
  }

  factory PrResetMarker.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PrResetMarker(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<String>(json['date']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<String>(date),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PrResetMarker copyWith({int? id, String? date, Value<String?> note = const Value.absent(), DateTime? createdAt}) =>
      PrResetMarker(
        id: id ?? this.id,
        date: date ?? this.date,
        note: note.present ? note.value : this.note,
        createdAt: createdAt ?? this.createdAt,
      );
  PrResetMarker copyWithCompanion(PrResetMarkersCompanion data) {
    return PrResetMarker(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PrResetMarker(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, date, note, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrResetMarker &&
          other.id == this.id &&
          other.date == this.date &&
          other.note == this.note &&
          other.createdAt == this.createdAt);
}

class PrResetMarkersCompanion extends UpdateCompanion<PrResetMarker> {
  final Value<int> id;
  final Value<String> date;
  final Value<String?> note;
  final Value<DateTime> createdAt;
  const PrResetMarkersCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PrResetMarkersCompanion.insert({
    this.id = const Value.absent(),
    required String date,
    this.note = const Value.absent(),
    required DateTime createdAt,
  }) : date = Value(date),
       createdAt = Value(createdAt);
  static Insertable<PrResetMarker> custom({
    Expression<int>? id,
    Expression<String>? date,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PrResetMarkersCompanion copyWith({Value<int>? id, Value<String>? date, Value<String?>? note, Value<DateTime>? createdAt}) {
    return PrResetMarkersCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PrResetMarkersCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings with TableInfo<$AppSettingsTable, AppSettingsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _themeModeMeta = const VerificationMeta('themeMode');
  @override
  late final GeneratedColumn<int> themeMode = GeneratedColumn<int>(
    'theme_mode',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _firstDayOfWeekMeta = const VerificationMeta('firstDayOfWeek');
  @override
  late final GeneratedColumn<int> firstDayOfWeek = GeneratedColumn<int>(
    'first_day_of_week',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _defaultWeightIncrementMeta = const VerificationMeta('defaultWeightIncrement');
  @override
  late final GeneratedColumn<double> defaultWeightIncrement = GeneratedColumn<double>(
    'default_weight_increment',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(2.5),
  );
  static const VerificationMeta _restTimerSecondsMeta = const VerificationMeta('restTimerSeconds');
  @override
  late final GeneratedColumn<int> restTimerSeconds = GeneratedColumn<int>(
    'rest_timer_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(60),
  );
  static const VerificationMeta _restTimerVibrateMeta = const VerificationMeta('restTimerVibrate');
  @override
  late final GeneratedColumn<bool> restTimerVibrate = GeneratedColumn<bool>(
    'rest_timer_vibrate',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("rest_timer_vibrate" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _restTimerSoundMeta = const VerificationMeta('restTimerSound');
  @override
  late final GeneratedColumn<bool> restTimerSound = GeneratedColumn<bool>(
    'rest_timer_sound',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("rest_timer_sound" IN (0, 1))'),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _restTimerAutoStartMeta = const VerificationMeta('restTimerAutoStart');
  @override
  late final GeneratedColumn<bool> restTimerAutoStart = GeneratedColumn<bool>(
    'rest_timer_auto_start',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("rest_timer_auto_start" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _trackPersonalRecordsMeta = const VerificationMeta('trackPersonalRecords');
  @override
  late final GeneratedColumn<bool> trackPersonalRecords = GeneratedColumn<bool>(
    'track_personal_records',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("track_personal_records" IN (0, 1))'),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _markSetsCompleteMeta = const VerificationMeta('markSetsComplete');
  @override
  late final GeneratedColumn<bool> markSetsComplete = GeneratedColumn<bool>(
    'mark_sets_complete',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("mark_sets_complete" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _keepScreenOnMeta = const VerificationMeta('keepScreenOn');
  @override
  late final GeneratedColumn<bool> keepScreenOn = GeneratedColumn<bool>(
    'keep_screen_on',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("keep_screen_on" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _estimated1rmMaxRepsMeta = const VerificationMeta('estimated1rmMaxReps');
  @override
  late final GeneratedColumn<int> estimated1rmMaxReps = GeneratedColumn<int>(
    'estimated1rm_max_reps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _useImperialMeta = const VerificationMeta('useImperial');
  @override
  late final GeneratedColumn<bool> useImperial = GeneratedColumn<bool>(
    'use_imperial',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("use_imperial" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    themeMode,
    firstDayOfWeek,
    defaultWeightIncrement,
    restTimerSeconds,
    restTimerVibrate,
    restTimerSound,
    restTimerAutoStart,
    trackPersonalRecords,
    markSetsComplete,
    keepScreenOn,
    estimated1rmMaxReps,
    useImperial,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(Insertable<AppSettingsRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('theme_mode')) {
      context.handle(_themeModeMeta, themeMode.isAcceptableOrUnknown(data['theme_mode']!, _themeModeMeta));
    }
    if (data.containsKey('first_day_of_week')) {
      context.handle(_firstDayOfWeekMeta, firstDayOfWeek.isAcceptableOrUnknown(data['first_day_of_week']!, _firstDayOfWeekMeta));
    }
    if (data.containsKey('default_weight_increment')) {
      context.handle(
        _defaultWeightIncrementMeta,
        defaultWeightIncrement.isAcceptableOrUnknown(data['default_weight_increment']!, _defaultWeightIncrementMeta),
      );
    }
    if (data.containsKey('rest_timer_seconds')) {
      context.handle(
        _restTimerSecondsMeta,
        restTimerSeconds.isAcceptableOrUnknown(data['rest_timer_seconds']!, _restTimerSecondsMeta),
      );
    }
    if (data.containsKey('rest_timer_vibrate')) {
      context.handle(
        _restTimerVibrateMeta,
        restTimerVibrate.isAcceptableOrUnknown(data['rest_timer_vibrate']!, _restTimerVibrateMeta),
      );
    }
    if (data.containsKey('rest_timer_sound')) {
      context.handle(_restTimerSoundMeta, restTimerSound.isAcceptableOrUnknown(data['rest_timer_sound']!, _restTimerSoundMeta));
    }
    if (data.containsKey('rest_timer_auto_start')) {
      context.handle(
        _restTimerAutoStartMeta,
        restTimerAutoStart.isAcceptableOrUnknown(data['rest_timer_auto_start']!, _restTimerAutoStartMeta),
      );
    }
    if (data.containsKey('track_personal_records')) {
      context.handle(
        _trackPersonalRecordsMeta,
        trackPersonalRecords.isAcceptableOrUnknown(data['track_personal_records']!, _trackPersonalRecordsMeta),
      );
    }
    if (data.containsKey('mark_sets_complete')) {
      context.handle(
        _markSetsCompleteMeta,
        markSetsComplete.isAcceptableOrUnknown(data['mark_sets_complete']!, _markSetsCompleteMeta),
      );
    }
    if (data.containsKey('keep_screen_on')) {
      context.handle(_keepScreenOnMeta, keepScreenOn.isAcceptableOrUnknown(data['keep_screen_on']!, _keepScreenOnMeta));
    }
    if (data.containsKey('estimated1rm_max_reps')) {
      context.handle(
        _estimated1rmMaxRepsMeta,
        estimated1rmMaxReps.isAcceptableOrUnknown(data['estimated1rm_max_reps']!, _estimated1rmMaxRepsMeta),
      );
    }
    if (data.containsKey('use_imperial')) {
      context.handle(_useImperialMeta, useImperial.isAcceptableOrUnknown(data['use_imperial']!, _useImperialMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppSettingsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSettingsRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      themeMode: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}theme_mode'])!,
      firstDayOfWeek: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}first_day_of_week'])!,
      defaultWeightIncrement: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}default_weight_increment'],
      )!,
      restTimerSeconds: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}rest_timer_seconds'])!,
      restTimerVibrate: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}rest_timer_vibrate'])!,
      restTimerSound: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}rest_timer_sound'])!,
      restTimerAutoStart: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}rest_timer_auto_start'])!,
      trackPersonalRecords: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}track_personal_records'],
      )!,
      markSetsComplete: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}mark_sets_complete'])!,
      keepScreenOn: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}keep_screen_on'])!,
      estimated1rmMaxReps: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}estimated1rm_max_reps'])!,
      useImperial: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}use_imperial'])!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSettingsRow extends DataClass implements Insertable<AppSettingsRow> {
  final int id;
  final int themeMode;
  final int firstDayOfWeek;
  final double defaultWeightIncrement;
  final int restTimerSeconds;
  final bool restTimerVibrate;
  final bool restTimerSound;
  final bool restTimerAutoStart;
  final bool trackPersonalRecords;
  final bool markSetsComplete;
  final bool keepScreenOn;
  final int estimated1rmMaxReps;
  final bool useImperial;
  const AppSettingsRow({
    required this.id,
    required this.themeMode,
    required this.firstDayOfWeek,
    required this.defaultWeightIncrement,
    required this.restTimerSeconds,
    required this.restTimerVibrate,
    required this.restTimerSound,
    required this.restTimerAutoStart,
    required this.trackPersonalRecords,
    required this.markSetsComplete,
    required this.keepScreenOn,
    required this.estimated1rmMaxReps,
    required this.useImperial,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['theme_mode'] = Variable<int>(themeMode);
    map['first_day_of_week'] = Variable<int>(firstDayOfWeek);
    map['default_weight_increment'] = Variable<double>(defaultWeightIncrement);
    map['rest_timer_seconds'] = Variable<int>(restTimerSeconds);
    map['rest_timer_vibrate'] = Variable<bool>(restTimerVibrate);
    map['rest_timer_sound'] = Variable<bool>(restTimerSound);
    map['rest_timer_auto_start'] = Variable<bool>(restTimerAutoStart);
    map['track_personal_records'] = Variable<bool>(trackPersonalRecords);
    map['mark_sets_complete'] = Variable<bool>(markSetsComplete);
    map['keep_screen_on'] = Variable<bool>(keepScreenOn);
    map['estimated1rm_max_reps'] = Variable<int>(estimated1rmMaxReps);
    map['use_imperial'] = Variable<bool>(useImperial);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      id: Value(id),
      themeMode: Value(themeMode),
      firstDayOfWeek: Value(firstDayOfWeek),
      defaultWeightIncrement: Value(defaultWeightIncrement),
      restTimerSeconds: Value(restTimerSeconds),
      restTimerVibrate: Value(restTimerVibrate),
      restTimerSound: Value(restTimerSound),
      restTimerAutoStart: Value(restTimerAutoStart),
      trackPersonalRecords: Value(trackPersonalRecords),
      markSetsComplete: Value(markSetsComplete),
      keepScreenOn: Value(keepScreenOn),
      estimated1rmMaxReps: Value(estimated1rmMaxReps),
      useImperial: Value(useImperial),
    );
  }

  factory AppSettingsRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSettingsRow(
      id: serializer.fromJson<int>(json['id']),
      themeMode: serializer.fromJson<int>(json['themeMode']),
      firstDayOfWeek: serializer.fromJson<int>(json['firstDayOfWeek']),
      defaultWeightIncrement: serializer.fromJson<double>(json['defaultWeightIncrement']),
      restTimerSeconds: serializer.fromJson<int>(json['restTimerSeconds']),
      restTimerVibrate: serializer.fromJson<bool>(json['restTimerVibrate']),
      restTimerSound: serializer.fromJson<bool>(json['restTimerSound']),
      restTimerAutoStart: serializer.fromJson<bool>(json['restTimerAutoStart']),
      trackPersonalRecords: serializer.fromJson<bool>(json['trackPersonalRecords']),
      markSetsComplete: serializer.fromJson<bool>(json['markSetsComplete']),
      keepScreenOn: serializer.fromJson<bool>(json['keepScreenOn']),
      estimated1rmMaxReps: serializer.fromJson<int>(json['estimated1rmMaxReps']),
      useImperial: serializer.fromJson<bool>(json['useImperial']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'themeMode': serializer.toJson<int>(themeMode),
      'firstDayOfWeek': serializer.toJson<int>(firstDayOfWeek),
      'defaultWeightIncrement': serializer.toJson<double>(defaultWeightIncrement),
      'restTimerSeconds': serializer.toJson<int>(restTimerSeconds),
      'restTimerVibrate': serializer.toJson<bool>(restTimerVibrate),
      'restTimerSound': serializer.toJson<bool>(restTimerSound),
      'restTimerAutoStart': serializer.toJson<bool>(restTimerAutoStart),
      'trackPersonalRecords': serializer.toJson<bool>(trackPersonalRecords),
      'markSetsComplete': serializer.toJson<bool>(markSetsComplete),
      'keepScreenOn': serializer.toJson<bool>(keepScreenOn),
      'estimated1rmMaxReps': serializer.toJson<int>(estimated1rmMaxReps),
      'useImperial': serializer.toJson<bool>(useImperial),
    };
  }

  AppSettingsRow copyWith({
    int? id,
    int? themeMode,
    int? firstDayOfWeek,
    double? defaultWeightIncrement,
    int? restTimerSeconds,
    bool? restTimerVibrate,
    bool? restTimerSound,
    bool? restTimerAutoStart,
    bool? trackPersonalRecords,
    bool? markSetsComplete,
    bool? keepScreenOn,
    int? estimated1rmMaxReps,
    bool? useImperial,
  }) => AppSettingsRow(
    id: id ?? this.id,
    themeMode: themeMode ?? this.themeMode,
    firstDayOfWeek: firstDayOfWeek ?? this.firstDayOfWeek,
    defaultWeightIncrement: defaultWeightIncrement ?? this.defaultWeightIncrement,
    restTimerSeconds: restTimerSeconds ?? this.restTimerSeconds,
    restTimerVibrate: restTimerVibrate ?? this.restTimerVibrate,
    restTimerSound: restTimerSound ?? this.restTimerSound,
    restTimerAutoStart: restTimerAutoStart ?? this.restTimerAutoStart,
    trackPersonalRecords: trackPersonalRecords ?? this.trackPersonalRecords,
    markSetsComplete: markSetsComplete ?? this.markSetsComplete,
    keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    estimated1rmMaxReps: estimated1rmMaxReps ?? this.estimated1rmMaxReps,
    useImperial: useImperial ?? this.useImperial,
  );
  AppSettingsRow copyWithCompanion(AppSettingsCompanion data) {
    return AppSettingsRow(
      id: data.id.present ? data.id.value : this.id,
      themeMode: data.themeMode.present ? data.themeMode.value : this.themeMode,
      firstDayOfWeek: data.firstDayOfWeek.present ? data.firstDayOfWeek.value : this.firstDayOfWeek,
      defaultWeightIncrement: data.defaultWeightIncrement.present
          ? data.defaultWeightIncrement.value
          : this.defaultWeightIncrement,
      restTimerSeconds: data.restTimerSeconds.present ? data.restTimerSeconds.value : this.restTimerSeconds,
      restTimerVibrate: data.restTimerVibrate.present ? data.restTimerVibrate.value : this.restTimerVibrate,
      restTimerSound: data.restTimerSound.present ? data.restTimerSound.value : this.restTimerSound,
      restTimerAutoStart: data.restTimerAutoStart.present ? data.restTimerAutoStart.value : this.restTimerAutoStart,
      trackPersonalRecords: data.trackPersonalRecords.present ? data.trackPersonalRecords.value : this.trackPersonalRecords,
      markSetsComplete: data.markSetsComplete.present ? data.markSetsComplete.value : this.markSetsComplete,
      keepScreenOn: data.keepScreenOn.present ? data.keepScreenOn.value : this.keepScreenOn,
      estimated1rmMaxReps: data.estimated1rmMaxReps.present ? data.estimated1rmMaxReps.value : this.estimated1rmMaxReps,
      useImperial: data.useImperial.present ? data.useImperial.value : this.useImperial,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsRow(')
          ..write('id: $id, ')
          ..write('themeMode: $themeMode, ')
          ..write('firstDayOfWeek: $firstDayOfWeek, ')
          ..write('defaultWeightIncrement: $defaultWeightIncrement, ')
          ..write('restTimerSeconds: $restTimerSeconds, ')
          ..write('restTimerVibrate: $restTimerVibrate, ')
          ..write('restTimerSound: $restTimerSound, ')
          ..write('restTimerAutoStart: $restTimerAutoStart, ')
          ..write('trackPersonalRecords: $trackPersonalRecords, ')
          ..write('markSetsComplete: $markSetsComplete, ')
          ..write('keepScreenOn: $keepScreenOn, ')
          ..write('estimated1rmMaxReps: $estimated1rmMaxReps, ')
          ..write('useImperial: $useImperial')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    themeMode,
    firstDayOfWeek,
    defaultWeightIncrement,
    restTimerSeconds,
    restTimerVibrate,
    restTimerSound,
    restTimerAutoStart,
    trackPersonalRecords,
    markSetsComplete,
    keepScreenOn,
    estimated1rmMaxReps,
    useImperial,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSettingsRow &&
          other.id == this.id &&
          other.themeMode == this.themeMode &&
          other.firstDayOfWeek == this.firstDayOfWeek &&
          other.defaultWeightIncrement == this.defaultWeightIncrement &&
          other.restTimerSeconds == this.restTimerSeconds &&
          other.restTimerVibrate == this.restTimerVibrate &&
          other.restTimerSound == this.restTimerSound &&
          other.restTimerAutoStart == this.restTimerAutoStart &&
          other.trackPersonalRecords == this.trackPersonalRecords &&
          other.markSetsComplete == this.markSetsComplete &&
          other.keepScreenOn == this.keepScreenOn &&
          other.estimated1rmMaxReps == this.estimated1rmMaxReps &&
          other.useImperial == this.useImperial);
}

class AppSettingsCompanion extends UpdateCompanion<AppSettingsRow> {
  final Value<int> id;
  final Value<int> themeMode;
  final Value<int> firstDayOfWeek;
  final Value<double> defaultWeightIncrement;
  final Value<int> restTimerSeconds;
  final Value<bool> restTimerVibrate;
  final Value<bool> restTimerSound;
  final Value<bool> restTimerAutoStart;
  final Value<bool> trackPersonalRecords;
  final Value<bool> markSetsComplete;
  final Value<bool> keepScreenOn;
  final Value<int> estimated1rmMaxReps;
  final Value<bool> useImperial;
  const AppSettingsCompanion({
    this.id = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.firstDayOfWeek = const Value.absent(),
    this.defaultWeightIncrement = const Value.absent(),
    this.restTimerSeconds = const Value.absent(),
    this.restTimerVibrate = const Value.absent(),
    this.restTimerSound = const Value.absent(),
    this.restTimerAutoStart = const Value.absent(),
    this.trackPersonalRecords = const Value.absent(),
    this.markSetsComplete = const Value.absent(),
    this.keepScreenOn = const Value.absent(),
    this.estimated1rmMaxReps = const Value.absent(),
    this.useImperial = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.firstDayOfWeek = const Value.absent(),
    this.defaultWeightIncrement = const Value.absent(),
    this.restTimerSeconds = const Value.absent(),
    this.restTimerVibrate = const Value.absent(),
    this.restTimerSound = const Value.absent(),
    this.restTimerAutoStart = const Value.absent(),
    this.trackPersonalRecords = const Value.absent(),
    this.markSetsComplete = const Value.absent(),
    this.keepScreenOn = const Value.absent(),
    this.estimated1rmMaxReps = const Value.absent(),
    this.useImperial = const Value.absent(),
  });
  static Insertable<AppSettingsRow> custom({
    Expression<int>? id,
    Expression<int>? themeMode,
    Expression<int>? firstDayOfWeek,
    Expression<double>? defaultWeightIncrement,
    Expression<int>? restTimerSeconds,
    Expression<bool>? restTimerVibrate,
    Expression<bool>? restTimerSound,
    Expression<bool>? restTimerAutoStart,
    Expression<bool>? trackPersonalRecords,
    Expression<bool>? markSetsComplete,
    Expression<bool>? keepScreenOn,
    Expression<int>? estimated1rmMaxReps,
    Expression<bool>? useImperial,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (themeMode != null) 'theme_mode': themeMode,
      if (firstDayOfWeek != null) 'first_day_of_week': firstDayOfWeek,
      if (defaultWeightIncrement != null) 'default_weight_increment': defaultWeightIncrement,
      if (restTimerSeconds != null) 'rest_timer_seconds': restTimerSeconds,
      if (restTimerVibrate != null) 'rest_timer_vibrate': restTimerVibrate,
      if (restTimerSound != null) 'rest_timer_sound': restTimerSound,
      if (restTimerAutoStart != null) 'rest_timer_auto_start': restTimerAutoStart,
      if (trackPersonalRecords != null) 'track_personal_records': trackPersonalRecords,
      if (markSetsComplete != null) 'mark_sets_complete': markSetsComplete,
      if (keepScreenOn != null) 'keep_screen_on': keepScreenOn,
      if (estimated1rmMaxReps != null) 'estimated1rm_max_reps': estimated1rmMaxReps,
      if (useImperial != null) 'use_imperial': useImperial,
    });
  }

  AppSettingsCompanion copyWith({
    Value<int>? id,
    Value<int>? themeMode,
    Value<int>? firstDayOfWeek,
    Value<double>? defaultWeightIncrement,
    Value<int>? restTimerSeconds,
    Value<bool>? restTimerVibrate,
    Value<bool>? restTimerSound,
    Value<bool>? restTimerAutoStart,
    Value<bool>? trackPersonalRecords,
    Value<bool>? markSetsComplete,
    Value<bool>? keepScreenOn,
    Value<int>? estimated1rmMaxReps,
    Value<bool>? useImperial,
  }) {
    return AppSettingsCompanion(
      id: id ?? this.id,
      themeMode: themeMode ?? this.themeMode,
      firstDayOfWeek: firstDayOfWeek ?? this.firstDayOfWeek,
      defaultWeightIncrement: defaultWeightIncrement ?? this.defaultWeightIncrement,
      restTimerSeconds: restTimerSeconds ?? this.restTimerSeconds,
      restTimerVibrate: restTimerVibrate ?? this.restTimerVibrate,
      restTimerSound: restTimerSound ?? this.restTimerSound,
      restTimerAutoStart: restTimerAutoStart ?? this.restTimerAutoStart,
      trackPersonalRecords: trackPersonalRecords ?? this.trackPersonalRecords,
      markSetsComplete: markSetsComplete ?? this.markSetsComplete,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      estimated1rmMaxReps: estimated1rmMaxReps ?? this.estimated1rmMaxReps,
      useImperial: useImperial ?? this.useImperial,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (themeMode.present) {
      map['theme_mode'] = Variable<int>(themeMode.value);
    }
    if (firstDayOfWeek.present) {
      map['first_day_of_week'] = Variable<int>(firstDayOfWeek.value);
    }
    if (defaultWeightIncrement.present) {
      map['default_weight_increment'] = Variable<double>(defaultWeightIncrement.value);
    }
    if (restTimerSeconds.present) {
      map['rest_timer_seconds'] = Variable<int>(restTimerSeconds.value);
    }
    if (restTimerVibrate.present) {
      map['rest_timer_vibrate'] = Variable<bool>(restTimerVibrate.value);
    }
    if (restTimerSound.present) {
      map['rest_timer_sound'] = Variable<bool>(restTimerSound.value);
    }
    if (restTimerAutoStart.present) {
      map['rest_timer_auto_start'] = Variable<bool>(restTimerAutoStart.value);
    }
    if (trackPersonalRecords.present) {
      map['track_personal_records'] = Variable<bool>(trackPersonalRecords.value);
    }
    if (markSetsComplete.present) {
      map['mark_sets_complete'] = Variable<bool>(markSetsComplete.value);
    }
    if (keepScreenOn.present) {
      map['keep_screen_on'] = Variable<bool>(keepScreenOn.value);
    }
    if (estimated1rmMaxReps.present) {
      map['estimated1rm_max_reps'] = Variable<int>(estimated1rmMaxReps.value);
    }
    if (useImperial.present) {
      map['use_imperial'] = Variable<bool>(useImperial.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('id: $id, ')
          ..write('themeMode: $themeMode, ')
          ..write('firstDayOfWeek: $firstDayOfWeek, ')
          ..write('defaultWeightIncrement: $defaultWeightIncrement, ')
          ..write('restTimerSeconds: $restTimerSeconds, ')
          ..write('restTimerVibrate: $restTimerVibrate, ')
          ..write('restTimerSound: $restTimerSound, ')
          ..write('restTimerAutoStart: $restTimerAutoStart, ')
          ..write('trackPersonalRecords: $trackPersonalRecords, ')
          ..write('markSetsComplete: $markSetsComplete, ')
          ..write('keepScreenOn: $keepScreenOn, ')
          ..write('estimated1rmMaxReps: $estimated1rmMaxReps, ')
          ..write('useImperial: $useImperial')
          ..write(')'))
        .toString();
  }
}

class $RoutinesTable extends Routines with TableInfo<$RoutinesTable, Routine> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoutinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 100),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, notes];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'routines';
  @override
  VerificationContext validateIntegrity(Insertable<Routine> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(_notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Routine map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Routine(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      notes: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}notes'])!,
    );
  }

  @override
  $RoutinesTable createAlias(String alias) {
    return $RoutinesTable(attachedDatabase, alias);
  }
}

class Routine extends DataClass implements Insertable<Routine> {
  final int id;
  final String name;
  final String notes;
  const Routine({required this.id, required this.name, required this.notes});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['notes'] = Variable<String>(notes);
    return map;
  }

  RoutinesCompanion toCompanion(bool nullToAbsent) {
    return RoutinesCompanion(id: Value(id), name: Value(name), notes: Value(notes));
  }

  factory Routine.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Routine(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      notes: serializer.fromJson<String>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'notes': serializer.toJson<String>(notes),
    };
  }

  Routine copyWith({int? id, String? name, String? notes}) =>
      Routine(id: id ?? this.id, name: name ?? this.name, notes: notes ?? this.notes);
  Routine copyWithCompanion(RoutinesCompanion data) {
    return Routine(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Routine(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, notes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Routine && other.id == this.id && other.name == this.name && other.notes == this.notes);
}

class RoutinesCompanion extends UpdateCompanion<Routine> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> notes;
  const RoutinesCompanion({this.id = const Value.absent(), this.name = const Value.absent(), this.notes = const Value.absent()});
  RoutinesCompanion.insert({this.id = const Value.absent(), required String name, this.notes = const Value.absent()})
    : name = Value(name);
  static Insertable<Routine> custom({Expression<int>? id, Expression<String>? name, Expression<String>? notes}) {
    return RawValuesInsertable({if (id != null) 'id': id, if (name != null) 'name': name, if (notes != null) 'notes': notes});
  }

  RoutinesCompanion copyWith({Value<int>? id, Value<String>? name, Value<String>? notes}) {
    return RoutinesCompanion(id: id ?? this.id, name: name ?? this.name, notes: notes ?? this.notes);
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
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoutinesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

class $RoutineDaysTable extends RoutineDays with TableInfo<$RoutineDaysTable, RoutineDay> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoutineDaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _routineIdMeta = const VerificationMeta('routineId');
  @override
  late final GeneratedColumn<int> routineId = GeneratedColumn<int>(
    'routine_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('REFERENCES routines (id) ON DELETE CASCADE'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 100),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, routineId, name, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'routine_days';
  @override
  VerificationContext validateIntegrity(Insertable<RoutineDay> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('routine_id')) {
      context.handle(_routineIdMeta, routineId.isAcceptableOrUnknown(data['routine_id']!, _routineIdMeta));
    } else if (isInserting) {
      context.missing(_routineIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta, sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RoutineDay map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RoutineDay(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      routineId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}routine_id'])!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      sortOrder: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
    );
  }

  @override
  $RoutineDaysTable createAlias(String alias) {
    return $RoutineDaysTable(attachedDatabase, alias);
  }
}

class RoutineDay extends DataClass implements Insertable<RoutineDay> {
  final int id;
  final int routineId;
  final String name;
  final int sortOrder;
  const RoutineDay({required this.id, required this.routineId, required this.name, required this.sortOrder});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['routine_id'] = Variable<int>(routineId);
    map['name'] = Variable<String>(name);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  RoutineDaysCompanion toCompanion(bool nullToAbsent) {
    return RoutineDaysCompanion(id: Value(id), routineId: Value(routineId), name: Value(name), sortOrder: Value(sortOrder));
  }

  factory RoutineDay.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RoutineDay(
      id: serializer.fromJson<int>(json['id']),
      routineId: serializer.fromJson<int>(json['routineId']),
      name: serializer.fromJson<String>(json['name']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'routineId': serializer.toJson<int>(routineId),
      'name': serializer.toJson<String>(name),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  RoutineDay copyWith({int? id, int? routineId, String? name, int? sortOrder}) => RoutineDay(
    id: id ?? this.id,
    routineId: routineId ?? this.routineId,
    name: name ?? this.name,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  RoutineDay copyWithCompanion(RoutineDaysCompanion data) {
    return RoutineDay(
      id: data.id.present ? data.id.value : this.id,
      routineId: data.routineId.present ? data.routineId.value : this.routineId,
      name: data.name.present ? data.name.value : this.name,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RoutineDay(')
          ..write('id: $id, ')
          ..write('routineId: $routineId, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, routineId, name, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RoutineDay &&
          other.id == this.id &&
          other.routineId == this.routineId &&
          other.name == this.name &&
          other.sortOrder == this.sortOrder);
}

class RoutineDaysCompanion extends UpdateCompanion<RoutineDay> {
  final Value<int> id;
  final Value<int> routineId;
  final Value<String> name;
  final Value<int> sortOrder;
  const RoutineDaysCompanion({
    this.id = const Value.absent(),
    this.routineId = const Value.absent(),
    this.name = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  RoutineDaysCompanion.insert({
    this.id = const Value.absent(),
    required int routineId,
    required String name,
    this.sortOrder = const Value.absent(),
  }) : routineId = Value(routineId),
       name = Value(name);
  static Insertable<RoutineDay> custom({
    Expression<int>? id,
    Expression<int>? routineId,
    Expression<String>? name,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (routineId != null) 'routine_id': routineId,
      if (name != null) 'name': name,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  RoutineDaysCompanion copyWith({Value<int>? id, Value<int>? routineId, Value<String>? name, Value<int>? sortOrder}) {
    return RoutineDaysCompanion(
      id: id ?? this.id,
      routineId: routineId ?? this.routineId,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (routineId.present) {
      map['routine_id'] = Variable<int>(routineId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoutineDaysCompanion(')
          ..write('id: $id, ')
          ..write('routineId: $routineId, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

class $RoutineSetsTable extends RoutineSets with TableInfo<$RoutineSetsTable, RoutineSet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoutineSetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _dayIdMeta = const VerificationMeta('dayId');
  @override
  late final GeneratedColumn<int> dayId = GeneratedColumn<int>(
    'day_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('REFERENCES routine_days (id) ON DELETE CASCADE'),
  );
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta('exerciseId');
  @override
  late final GeneratedColumn<int> exerciseId = GeneratedColumn<int>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('REFERENCES exercises (id)'),
  );
  static const VerificationMeta _rawWeightMeta = const VerificationMeta('rawWeight');
  @override
  late final GeneratedColumn<double> rawWeight = GeneratedColumn<double>(
    'raw_weight',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
    'reps',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _distanceMeta = const VerificationMeta('distance');
  @override
  late final GeneratedColumn<double> distance = GeneratedColumn<double>(
    'distance',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta('durationSeconds');
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _groupNameMeta = const VerificationMeta('groupName');
  @override
  late final GeneratedColumn<String> groupName = GeneratedColumn<String>(
    'group_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, dayId, exerciseId, rawWeight, reps, distance, durationSeconds, sortOrder, groupName];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'routine_sets';
  @override
  VerificationContext validateIntegrity(Insertable<RoutineSet> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('day_id')) {
      context.handle(_dayIdMeta, dayId.isAcceptableOrUnknown(data['day_id']!, _dayIdMeta));
    } else if (isInserting) {
      context.missing(_dayIdMeta);
    }
    if (data.containsKey('exercise_id')) {
      context.handle(_exerciseIdMeta, exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta));
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('raw_weight')) {
      context.handle(_rawWeightMeta, rawWeight.isAcceptableOrUnknown(data['raw_weight']!, _rawWeightMeta));
    }
    if (data.containsKey('reps')) {
      context.handle(_repsMeta, reps.isAcceptableOrUnknown(data['reps']!, _repsMeta));
    }
    if (data.containsKey('distance')) {
      context.handle(_distanceMeta, distance.isAcceptableOrUnknown(data['distance']!, _distanceMeta));
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(data['duration_seconds']!, _durationSecondsMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta, sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('group_name')) {
      context.handle(_groupNameMeta, groupName.isAcceptableOrUnknown(data['group_name']!, _groupNameMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RoutineSet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RoutineSet(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      dayId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}day_id'])!,
      exerciseId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}exercise_id'])!,
      rawWeight: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}raw_weight']),
      reps: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}reps']),
      distance: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}distance']),
      durationSeconds: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}duration_seconds']),
      sortOrder: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      groupName: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}group_name']),
    );
  }

  @override
  $RoutineSetsTable createAlias(String alias) {
    return $RoutineSetsTable(attachedDatabase, alias);
  }
}

class RoutineSet extends DataClass implements Insertable<RoutineSet> {
  final int id;
  final int dayId;
  final int exerciseId;
  final double? rawWeight;
  final int? reps;
  final double? distance;
  final int? durationSeconds;
  final int sortOrder;
  final String? groupName;
  const RoutineSet({
    required this.id,
    required this.dayId,
    required this.exerciseId,
    this.rawWeight,
    this.reps,
    this.distance,
    this.durationSeconds,
    required this.sortOrder,
    this.groupName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['day_id'] = Variable<int>(dayId);
    map['exercise_id'] = Variable<int>(exerciseId);
    if (!nullToAbsent || rawWeight != null) {
      map['raw_weight'] = Variable<double>(rawWeight);
    }
    if (!nullToAbsent || reps != null) {
      map['reps'] = Variable<int>(reps);
    }
    if (!nullToAbsent || distance != null) {
      map['distance'] = Variable<double>(distance);
    }
    if (!nullToAbsent || durationSeconds != null) {
      map['duration_seconds'] = Variable<int>(durationSeconds);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || groupName != null) {
      map['group_name'] = Variable<String>(groupName);
    }
    return map;
  }

  RoutineSetsCompanion toCompanion(bool nullToAbsent) {
    return RoutineSetsCompanion(
      id: Value(id),
      dayId: Value(dayId),
      exerciseId: Value(exerciseId),
      rawWeight: rawWeight == null && nullToAbsent ? const Value.absent() : Value(rawWeight),
      reps: reps == null && nullToAbsent ? const Value.absent() : Value(reps),
      distance: distance == null && nullToAbsent ? const Value.absent() : Value(distance),
      durationSeconds: durationSeconds == null && nullToAbsent ? const Value.absent() : Value(durationSeconds),
      sortOrder: Value(sortOrder),
      groupName: groupName == null && nullToAbsent ? const Value.absent() : Value(groupName),
    );
  }

  factory RoutineSet.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RoutineSet(
      id: serializer.fromJson<int>(json['id']),
      dayId: serializer.fromJson<int>(json['dayId']),
      exerciseId: serializer.fromJson<int>(json['exerciseId']),
      rawWeight: serializer.fromJson<double?>(json['rawWeight']),
      reps: serializer.fromJson<int?>(json['reps']),
      distance: serializer.fromJson<double?>(json['distance']),
      durationSeconds: serializer.fromJson<int?>(json['durationSeconds']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      groupName: serializer.fromJson<String?>(json['groupName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'dayId': serializer.toJson<int>(dayId),
      'exerciseId': serializer.toJson<int>(exerciseId),
      'rawWeight': serializer.toJson<double?>(rawWeight),
      'reps': serializer.toJson<int?>(reps),
      'distance': serializer.toJson<double?>(distance),
      'durationSeconds': serializer.toJson<int?>(durationSeconds),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'groupName': serializer.toJson<String?>(groupName),
    };
  }

  RoutineSet copyWith({
    int? id,
    int? dayId,
    int? exerciseId,
    Value<double?> rawWeight = const Value.absent(),
    Value<int?> reps = const Value.absent(),
    Value<double?> distance = const Value.absent(),
    Value<int?> durationSeconds = const Value.absent(),
    int? sortOrder,
    Value<String?> groupName = const Value.absent(),
  }) => RoutineSet(
    id: id ?? this.id,
    dayId: dayId ?? this.dayId,
    exerciseId: exerciseId ?? this.exerciseId,
    rawWeight: rawWeight.present ? rawWeight.value : this.rawWeight,
    reps: reps.present ? reps.value : this.reps,
    distance: distance.present ? distance.value : this.distance,
    durationSeconds: durationSeconds.present ? durationSeconds.value : this.durationSeconds,
    sortOrder: sortOrder ?? this.sortOrder,
    groupName: groupName.present ? groupName.value : this.groupName,
  );
  RoutineSet copyWithCompanion(RoutineSetsCompanion data) {
    return RoutineSet(
      id: data.id.present ? data.id.value : this.id,
      dayId: data.dayId.present ? data.dayId.value : this.dayId,
      exerciseId: data.exerciseId.present ? data.exerciseId.value : this.exerciseId,
      rawWeight: data.rawWeight.present ? data.rawWeight.value : this.rawWeight,
      reps: data.reps.present ? data.reps.value : this.reps,
      distance: data.distance.present ? data.distance.value : this.distance,
      durationSeconds: data.durationSeconds.present ? data.durationSeconds.value : this.durationSeconds,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      groupName: data.groupName.present ? data.groupName.value : this.groupName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RoutineSet(')
          ..write('id: $id, ')
          ..write('dayId: $dayId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('rawWeight: $rawWeight, ')
          ..write('reps: $reps, ')
          ..write('distance: $distance, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('groupName: $groupName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, dayId, exerciseId, rawWeight, reps, distance, durationSeconds, sortOrder, groupName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RoutineSet &&
          other.id == this.id &&
          other.dayId == this.dayId &&
          other.exerciseId == this.exerciseId &&
          other.rawWeight == this.rawWeight &&
          other.reps == this.reps &&
          other.distance == this.distance &&
          other.durationSeconds == this.durationSeconds &&
          other.sortOrder == this.sortOrder &&
          other.groupName == this.groupName);
}

class RoutineSetsCompanion extends UpdateCompanion<RoutineSet> {
  final Value<int> id;
  final Value<int> dayId;
  final Value<int> exerciseId;
  final Value<double?> rawWeight;
  final Value<int?> reps;
  final Value<double?> distance;
  final Value<int?> durationSeconds;
  final Value<int> sortOrder;
  final Value<String?> groupName;
  const RoutineSetsCompanion({
    this.id = const Value.absent(),
    this.dayId = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.rawWeight = const Value.absent(),
    this.reps = const Value.absent(),
    this.distance = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.groupName = const Value.absent(),
  });
  RoutineSetsCompanion.insert({
    this.id = const Value.absent(),
    required int dayId,
    required int exerciseId,
    this.rawWeight = const Value.absent(),
    this.reps = const Value.absent(),
    this.distance = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.groupName = const Value.absent(),
  }) : dayId = Value(dayId),
       exerciseId = Value(exerciseId);
  static Insertable<RoutineSet> custom({
    Expression<int>? id,
    Expression<int>? dayId,
    Expression<int>? exerciseId,
    Expression<double>? rawWeight,
    Expression<int>? reps,
    Expression<double>? distance,
    Expression<int>? durationSeconds,
    Expression<int>? sortOrder,
    Expression<String>? groupName,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dayId != null) 'day_id': dayId,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (rawWeight != null) 'raw_weight': rawWeight,
      if (reps != null) 'reps': reps,
      if (distance != null) 'distance': distance,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (groupName != null) 'group_name': groupName,
    });
  }

  RoutineSetsCompanion copyWith({
    Value<int>? id,
    Value<int>? dayId,
    Value<int>? exerciseId,
    Value<double?>? rawWeight,
    Value<int?>? reps,
    Value<double?>? distance,
    Value<int?>? durationSeconds,
    Value<int>? sortOrder,
    Value<String?>? groupName,
  }) {
    return RoutineSetsCompanion(
      id: id ?? this.id,
      dayId: dayId ?? this.dayId,
      exerciseId: exerciseId ?? this.exerciseId,
      rawWeight: rawWeight ?? this.rawWeight,
      reps: reps ?? this.reps,
      distance: distance ?? this.distance,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      sortOrder: sortOrder ?? this.sortOrder,
      groupName: groupName ?? this.groupName,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (dayId.present) {
      map['day_id'] = Variable<int>(dayId.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<int>(exerciseId.value);
    }
    if (rawWeight.present) {
      map['raw_weight'] = Variable<double>(rawWeight.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (distance.present) {
      map['distance'] = Variable<double>(distance.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (groupName.present) {
      map['group_name'] = Variable<String>(groupName.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoutineSetsCompanion(')
          ..write('id: $id, ')
          ..write('dayId: $dayId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('rawWeight: $rawWeight, ')
          ..write('reps: $reps, ')
          ..write('distance: $distance, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('groupName: $groupName')
          ..write(')'))
        .toString();
  }
}

class $MeasurementTypesTable extends MeasurementTypes with TableInfo<$MeasurementTypesTable, MeasurementType> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MeasurementTypesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 80),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, unit];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'measurement_types';
  @override
  VerificationContext validateIntegrity(Insertable<MeasurementType> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(_unitMeta, unit.isAcceptableOrUnknown(data['unit']!, _unitMeta));
    } else if (isInserting) {
      context.missing(_unitMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MeasurementType map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MeasurementType(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      unit: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}unit'])!,
    );
  }

  @override
  $MeasurementTypesTable createAlias(String alias) {
    return $MeasurementTypesTable(attachedDatabase, alias);
  }
}

class MeasurementType extends DataClass implements Insertable<MeasurementType> {
  final int id;
  final String name;
  final String unit;
  const MeasurementType({required this.id, required this.name, required this.unit});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['unit'] = Variable<String>(unit);
    return map;
  }

  MeasurementTypesCompanion toCompanion(bool nullToAbsent) {
    return MeasurementTypesCompanion(id: Value(id), name: Value(name), unit: Value(unit));
  }

  factory MeasurementType.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MeasurementType(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      unit: serializer.fromJson<String>(json['unit']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'unit': serializer.toJson<String>(unit),
    };
  }

  MeasurementType copyWith({int? id, String? name, String? unit}) =>
      MeasurementType(id: id ?? this.id, name: name ?? this.name, unit: unit ?? this.unit);
  MeasurementType copyWithCompanion(MeasurementTypesCompanion data) {
    return MeasurementType(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      unit: data.unit.present ? data.unit.value : this.unit,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MeasurementType(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('unit: $unit')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, unit);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MeasurementType && other.id == this.id && other.name == this.name && other.unit == this.unit);
}

class MeasurementTypesCompanion extends UpdateCompanion<MeasurementType> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> unit;
  const MeasurementTypesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.unit = const Value.absent(),
  });
  MeasurementTypesCompanion.insert({this.id = const Value.absent(), required String name, required String unit})
    : name = Value(name),
      unit = Value(unit);
  static Insertable<MeasurementType> custom({Expression<int>? id, Expression<String>? name, Expression<String>? unit}) {
    return RawValuesInsertable({if (id != null) 'id': id, if (name != null) 'name': name, if (unit != null) 'unit': unit});
  }

  MeasurementTypesCompanion copyWith({Value<int>? id, Value<String>? name, Value<String>? unit}) {
    return MeasurementTypesCompanion(id: id ?? this.id, name: name ?? this.name, unit: unit ?? this.unit);
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
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MeasurementTypesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('unit: $unit')
          ..write(')'))
        .toString();
  }
}

class $MeasurementsTable extends Measurements with TableInfo<$MeasurementsTable, Measurement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MeasurementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _typeIdMeta = const VerificationMeta('typeId');
  @override
  late final GeneratedColumn<int> typeId = GeneratedColumn<int>(
    'type_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('REFERENCES measurement_types (id) ON DELETE CASCADE'),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<double> value = GeneratedColumn<double>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [id, typeId, date, value, note];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'measurements';
  @override
  VerificationContext validateIntegrity(Insertable<Measurement> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('type_id')) {
      context.handle(_typeIdMeta, typeId.isAcceptableOrUnknown(data['type_id']!, _typeIdMeta));
    } else if (isInserting) {
      context.missing(_typeIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(_dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('value')) {
      context.handle(_valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('note')) {
      context.handle(_noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {typeId, date},
  ];
  @override
  Measurement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Measurement(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      typeId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}type_id'])!,
      date: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}date'])!,
      value: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}value'])!,
      note: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}note'])!,
    );
  }

  @override
  $MeasurementsTable createAlias(String alias) {
    return $MeasurementsTable(attachedDatabase, alias);
  }
}

class Measurement extends DataClass implements Insertable<Measurement> {
  final int id;
  final int typeId;
  final String date;
  final double value;
  final String note;
  const Measurement({required this.id, required this.typeId, required this.date, required this.value, required this.note});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['type_id'] = Variable<int>(typeId);
    map['date'] = Variable<String>(date);
    map['value'] = Variable<double>(value);
    map['note'] = Variable<String>(note);
    return map;
  }

  MeasurementsCompanion toCompanion(bool nullToAbsent) {
    return MeasurementsCompanion(id: Value(id), typeId: Value(typeId), date: Value(date), value: Value(value), note: Value(note));
  }

  factory Measurement.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Measurement(
      id: serializer.fromJson<int>(json['id']),
      typeId: serializer.fromJson<int>(json['typeId']),
      date: serializer.fromJson<String>(json['date']),
      value: serializer.fromJson<double>(json['value']),
      note: serializer.fromJson<String>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'typeId': serializer.toJson<int>(typeId),
      'date': serializer.toJson<String>(date),
      'value': serializer.toJson<double>(value),
      'note': serializer.toJson<String>(note),
    };
  }

  Measurement copyWith({int? id, int? typeId, String? date, double? value, String? note}) => Measurement(
    id: id ?? this.id,
    typeId: typeId ?? this.typeId,
    date: date ?? this.date,
    value: value ?? this.value,
    note: note ?? this.note,
  );
  Measurement copyWithCompanion(MeasurementsCompanion data) {
    return Measurement(
      id: data.id.present ? data.id.value : this.id,
      typeId: data.typeId.present ? data.typeId.value : this.typeId,
      date: data.date.present ? data.date.value : this.date,
      value: data.value.present ? data.value.value : this.value,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Measurement(')
          ..write('id: $id, ')
          ..write('typeId: $typeId, ')
          ..write('date: $date, ')
          ..write('value: $value, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, typeId, date, value, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Measurement &&
          other.id == this.id &&
          other.typeId == this.typeId &&
          other.date == this.date &&
          other.value == this.value &&
          other.note == this.note);
}

class MeasurementsCompanion extends UpdateCompanion<Measurement> {
  final Value<int> id;
  final Value<int> typeId;
  final Value<String> date;
  final Value<double> value;
  final Value<String> note;
  const MeasurementsCompanion({
    this.id = const Value.absent(),
    this.typeId = const Value.absent(),
    this.date = const Value.absent(),
    this.value = const Value.absent(),
    this.note = const Value.absent(),
  });
  MeasurementsCompanion.insert({
    this.id = const Value.absent(),
    required int typeId,
    required String date,
    required double value,
    this.note = const Value.absent(),
  }) : typeId = Value(typeId),
       date = Value(date),
       value = Value(value);
  static Insertable<Measurement> custom({
    Expression<int>? id,
    Expression<int>? typeId,
    Expression<String>? date,
    Expression<double>? value,
    Expression<String>? note,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (typeId != null) 'type_id': typeId,
      if (date != null) 'date': date,
      if (value != null) 'value': value,
      if (note != null) 'note': note,
    });
  }

  MeasurementsCompanion copyWith({
    Value<int>? id,
    Value<int>? typeId,
    Value<String>? date,
    Value<double>? value,
    Value<String>? note,
  }) {
    return MeasurementsCompanion(
      id: id ?? this.id,
      typeId: typeId ?? this.typeId,
      date: date ?? this.date,
      value: value ?? this.value,
      note: note ?? this.note,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (typeId.present) {
      map['type_id'] = Variable<int>(typeId.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (value.present) {
      map['value'] = Variable<double>(value.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MeasurementsCompanion(')
          ..write('id: $id, ')
          ..write('typeId: $typeId, ')
          ..write('date: $date, ')
          ..write('value: $value, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }
}

class $ExerciseGoalsTable extends ExerciseGoals with TableInfo<$ExerciseGoalsTable, ExerciseGoal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExerciseGoalsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta('exerciseId');
  @override
  late final GeneratedColumn<int> exerciseId = GeneratedColumn<int>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('REFERENCES exercises (id) ON DELETE CASCADE'),
  );
  static const VerificationMeta _metricMeta = const VerificationMeta('metric');
  @override
  late final GeneratedColumn<String> metric = GeneratedColumn<String>(
    'metric',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetMeta = const VerificationMeta('target');
  @override
  late final GeneratedColumn<double> target = GeneratedColumn<double>(
    'target',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetDateMeta = const VerificationMeta('targetDate');
  @override
  late final GeneratedColumn<String> targetDate = GeneratedColumn<String>(
    'target_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, exerciseId, metric, target, targetDate];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercise_goals';
  @override
  VerificationContext validateIntegrity(Insertable<ExerciseGoal> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('exercise_id')) {
      context.handle(_exerciseIdMeta, exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta));
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('metric')) {
      context.handle(_metricMeta, metric.isAcceptableOrUnknown(data['metric']!, _metricMeta));
    } else if (isInserting) {
      context.missing(_metricMeta);
    }
    if (data.containsKey('target')) {
      context.handle(_targetMeta, target.isAcceptableOrUnknown(data['target']!, _targetMeta));
    } else if (isInserting) {
      context.missing(_targetMeta);
    }
    if (data.containsKey('target_date')) {
      context.handle(_targetDateMeta, targetDate.isAcceptableOrUnknown(data['target_date']!, _targetDateMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExerciseGoal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExerciseGoal(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      exerciseId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}exercise_id'])!,
      metric: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}metric'])!,
      target: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}target'])!,
      targetDate: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}target_date']),
    );
  }

  @override
  $ExerciseGoalsTable createAlias(String alias) {
    return $ExerciseGoalsTable(attachedDatabase, alias);
  }
}

class ExerciseGoal extends DataClass implements Insertable<ExerciseGoal> {
  final int id;
  final int exerciseId;
  final String metric;
  final double target;
  final String? targetDate;
  const ExerciseGoal({required this.id, required this.exerciseId, required this.metric, required this.target, this.targetDate});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['exercise_id'] = Variable<int>(exerciseId);
    map['metric'] = Variable<String>(metric);
    map['target'] = Variable<double>(target);
    if (!nullToAbsent || targetDate != null) {
      map['target_date'] = Variable<String>(targetDate);
    }
    return map;
  }

  ExerciseGoalsCompanion toCompanion(bool nullToAbsent) {
    return ExerciseGoalsCompanion(
      id: Value(id),
      exerciseId: Value(exerciseId),
      metric: Value(metric),
      target: Value(target),
      targetDate: targetDate == null && nullToAbsent ? const Value.absent() : Value(targetDate),
    );
  }

  factory ExerciseGoal.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExerciseGoal(
      id: serializer.fromJson<int>(json['id']),
      exerciseId: serializer.fromJson<int>(json['exerciseId']),
      metric: serializer.fromJson<String>(json['metric']),
      target: serializer.fromJson<double>(json['target']),
      targetDate: serializer.fromJson<String?>(json['targetDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'exerciseId': serializer.toJson<int>(exerciseId),
      'metric': serializer.toJson<String>(metric),
      'target': serializer.toJson<double>(target),
      'targetDate': serializer.toJson<String?>(targetDate),
    };
  }

  ExerciseGoal copyWith({
    int? id,
    int? exerciseId,
    String? metric,
    double? target,
    Value<String?> targetDate = const Value.absent(),
  }) => ExerciseGoal(
    id: id ?? this.id,
    exerciseId: exerciseId ?? this.exerciseId,
    metric: metric ?? this.metric,
    target: target ?? this.target,
    targetDate: targetDate.present ? targetDate.value : this.targetDate,
  );
  ExerciseGoal copyWithCompanion(ExerciseGoalsCompanion data) {
    return ExerciseGoal(
      id: data.id.present ? data.id.value : this.id,
      exerciseId: data.exerciseId.present ? data.exerciseId.value : this.exerciseId,
      metric: data.metric.present ? data.metric.value : this.metric,
      target: data.target.present ? data.target.value : this.target,
      targetDate: data.targetDate.present ? data.targetDate.value : this.targetDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseGoal(')
          ..write('id: $id, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('metric: $metric, ')
          ..write('target: $target, ')
          ..write('targetDate: $targetDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, exerciseId, metric, target, targetDate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExerciseGoal &&
          other.id == this.id &&
          other.exerciseId == this.exerciseId &&
          other.metric == this.metric &&
          other.target == this.target &&
          other.targetDate == this.targetDate);
}

class ExerciseGoalsCompanion extends UpdateCompanion<ExerciseGoal> {
  final Value<int> id;
  final Value<int> exerciseId;
  final Value<String> metric;
  final Value<double> target;
  final Value<String?> targetDate;
  const ExerciseGoalsCompanion({
    this.id = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.metric = const Value.absent(),
    this.target = const Value.absent(),
    this.targetDate = const Value.absent(),
  });
  ExerciseGoalsCompanion.insert({
    this.id = const Value.absent(),
    required int exerciseId,
    required String metric,
    required double target,
    this.targetDate = const Value.absent(),
  }) : exerciseId = Value(exerciseId),
       metric = Value(metric),
       target = Value(target);
  static Insertable<ExerciseGoal> custom({
    Expression<int>? id,
    Expression<int>? exerciseId,
    Expression<String>? metric,
    Expression<double>? target,
    Expression<String>? targetDate,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (metric != null) 'metric': metric,
      if (target != null) 'target': target,
      if (targetDate != null) 'target_date': targetDate,
    });
  }

  ExerciseGoalsCompanion copyWith({
    Value<int>? id,
    Value<int>? exerciseId,
    Value<String>? metric,
    Value<double>? target,
    Value<String?>? targetDate,
  }) {
    return ExerciseGoalsCompanion(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      metric: metric ?? this.metric,
      target: target ?? this.target,
      targetDate: targetDate ?? this.targetDate,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<int>(exerciseId.value);
    }
    if (metric.present) {
      map['metric'] = Variable<String>(metric.value);
    }
    if (target.present) {
      map['target'] = Variable<double>(target.value);
    }
    if (targetDate.present) {
      map['target_date'] = Variable<String>(targetDate.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseGoalsCompanion(')
          ..write('id: $id, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('metric: $metric, ')
          ..write('target: $target, ')
          ..write('targetDate: $targetDate')
          ..write(')'))
        .toString();
  }
}

class $WorkoutSessionsTable extends WorkoutSessions with TableInfo<$WorkoutSessionsTable, WorkoutSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta('endedAt');
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _elapsedSecondsMeta = const VerificationMeta('elapsedSeconds');
  @override
  late final GeneratedColumn<int> elapsedSeconds = GeneratedColumn<int>(
    'elapsed_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _runningSinceMeta = const VerificationMeta('runningSince');
  @override
  late final GeneratedColumn<DateTime> runningSince = GeneratedColumn<DateTime>(
    'running_since',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [date, startedAt, endedAt, elapsedSeconds, runningSince];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_sessions';
  @override
  VerificationContext validateIntegrity(Insertable<WorkoutSession> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date')) {
      context.handle(_dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta, startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(_endedAtMeta, endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta));
    }
    if (data.containsKey('elapsed_seconds')) {
      context.handle(_elapsedSecondsMeta, elapsedSeconds.isAcceptableOrUnknown(data['elapsed_seconds']!, _elapsedSecondsMeta));
    }
    if (data.containsKey('running_since')) {
      context.handle(_runningSinceMeta, runningSince.isAcceptableOrUnknown(data['running_since']!, _runningSinceMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {date};
  @override
  WorkoutSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutSession(
      date: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}date'])!,
      startedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}started_at'])!,
      endedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}ended_at']),
      elapsedSeconds: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}elapsed_seconds'])!,
      runningSince: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}running_since']),
    );
  }

  @override
  $WorkoutSessionsTable createAlias(String alias) {
    return $WorkoutSessionsTable(attachedDatabase, alias);
  }
}

class WorkoutSession extends DataClass implements Insertable<WorkoutSession> {
  final String date;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int elapsedSeconds;
  final DateTime? runningSince;
  const WorkoutSession({
    required this.date,
    required this.startedAt,
    this.endedAt,
    required this.elapsedSeconds,
    this.runningSince,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<String>(date);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    map['elapsed_seconds'] = Variable<int>(elapsedSeconds);
    if (!nullToAbsent || runningSince != null) {
      map['running_since'] = Variable<DateTime>(runningSince);
    }
    return map;
  }

  WorkoutSessionsCompanion toCompanion(bool nullToAbsent) {
    return WorkoutSessionsCompanion(
      date: Value(date),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent ? const Value.absent() : Value(endedAt),
      elapsedSeconds: Value(elapsedSeconds),
      runningSince: runningSince == null && nullToAbsent ? const Value.absent() : Value(runningSince),
    );
  }

  factory WorkoutSession.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutSession(
      date: serializer.fromJson<String>(json['date']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      elapsedSeconds: serializer.fromJson<int>(json['elapsedSeconds']),
      runningSince: serializer.fromJson<DateTime?>(json['runningSince']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'date': serializer.toJson<String>(date),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'elapsedSeconds': serializer.toJson<int>(elapsedSeconds),
      'runningSince': serializer.toJson<DateTime?>(runningSince),
    };
  }

  WorkoutSession copyWith({
    String? date,
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
    int? elapsedSeconds,
    Value<DateTime?> runningSince = const Value.absent(),
  }) => WorkoutSession(
    date: date ?? this.date,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
    runningSince: runningSince.present ? runningSince.value : this.runningSince,
  );
  WorkoutSession copyWithCompanion(WorkoutSessionsCompanion data) {
    return WorkoutSession(
      date: data.date.present ? data.date.value : this.date,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      elapsedSeconds: data.elapsedSeconds.present ? data.elapsedSeconds.value : this.elapsedSeconds,
      runningSince: data.runningSince.present ? data.runningSince.value : this.runningSince,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSession(')
          ..write('date: $date, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('elapsedSeconds: $elapsedSeconds, ')
          ..write('runningSince: $runningSince')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(date, startedAt, endedAt, elapsedSeconds, runningSince);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutSession &&
          other.date == this.date &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.elapsedSeconds == this.elapsedSeconds &&
          other.runningSince == this.runningSince);
}

class WorkoutSessionsCompanion extends UpdateCompanion<WorkoutSession> {
  final Value<String> date;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<int> elapsedSeconds;
  final Value<DateTime?> runningSince;
  final Value<int> rowid;
  const WorkoutSessionsCompanion({
    this.date = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.elapsedSeconds = const Value.absent(),
    this.runningSince = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkoutSessionsCompanion.insert({
    required String date,
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    this.elapsedSeconds = const Value.absent(),
    this.runningSince = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : date = Value(date),
       startedAt = Value(startedAt);
  static Insertable<WorkoutSession> custom({
    Expression<String>? date,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<int>? elapsedSeconds,
    Expression<DateTime>? runningSince,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (elapsedSeconds != null) 'elapsed_seconds': elapsedSeconds,
      if (runningSince != null) 'running_since': runningSince,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkoutSessionsCompanion copyWith({
    Value<String>? date,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<int>? elapsedSeconds,
    Value<DateTime?>? runningSince,
    Value<int>? rowid,
  }) {
    return WorkoutSessionsCompanion(
      date: date ?? this.date,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      runningSince: runningSince ?? this.runningSince,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (elapsedSeconds.present) {
      map['elapsed_seconds'] = Variable<int>(elapsedSeconds.value);
    }
    if (runningSince.present) {
      map['running_since'] = Variable<DateTime>(runningSince.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSessionsCompanion(')
          ..write('date: $date, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('elapsedSeconds: $elapsedSeconds, ')
          ..write('runningSince: $runningSince, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkoutExerciseOrdersTable extends WorkoutExerciseOrders
    with TableInfo<$WorkoutExerciseOrdersTable, WorkoutExerciseOrder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutExerciseOrdersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta('exerciseId');
  @override
  late final GeneratedColumn<int> exerciseId = GeneratedColumn<int>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('REFERENCES exercises (id) ON DELETE CASCADE'),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [date, exerciseId, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_exercise_orders';
  @override
  VerificationContext validateIntegrity(Insertable<WorkoutExerciseOrder> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date')) {
      context.handle(_dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('exercise_id')) {
      context.handle(_exerciseIdMeta, exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta));
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta, sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {date, exerciseId};
  @override
  WorkoutExerciseOrder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutExerciseOrder(
      date: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}date'])!,
      exerciseId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}exercise_id'])!,
      sortOrder: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
    );
  }

  @override
  $WorkoutExerciseOrdersTable createAlias(String alias) {
    return $WorkoutExerciseOrdersTable(attachedDatabase, alias);
  }
}

class WorkoutExerciseOrder extends DataClass implements Insertable<WorkoutExerciseOrder> {
  final String date;
  final int exerciseId;
  final int sortOrder;
  const WorkoutExerciseOrder({required this.date, required this.exerciseId, required this.sortOrder});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<String>(date);
    map['exercise_id'] = Variable<int>(exerciseId);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  WorkoutExerciseOrdersCompanion toCompanion(bool nullToAbsent) {
    return WorkoutExerciseOrdersCompanion(date: Value(date), exerciseId: Value(exerciseId), sortOrder: Value(sortOrder));
  }

  factory WorkoutExerciseOrder.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutExerciseOrder(
      date: serializer.fromJson<String>(json['date']),
      exerciseId: serializer.fromJson<int>(json['exerciseId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'date': serializer.toJson<String>(date),
      'exerciseId': serializer.toJson<int>(exerciseId),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  WorkoutExerciseOrder copyWith({String? date, int? exerciseId, int? sortOrder}) => WorkoutExerciseOrder(
    date: date ?? this.date,
    exerciseId: exerciseId ?? this.exerciseId,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  WorkoutExerciseOrder copyWithCompanion(WorkoutExerciseOrdersCompanion data) {
    return WorkoutExerciseOrder(
      date: data.date.present ? data.date.value : this.date,
      exerciseId: data.exerciseId.present ? data.exerciseId.value : this.exerciseId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutExerciseOrder(')
          ..write('date: $date, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(date, exerciseId, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutExerciseOrder &&
          other.date == this.date &&
          other.exerciseId == this.exerciseId &&
          other.sortOrder == this.sortOrder);
}

class WorkoutExerciseOrdersCompanion extends UpdateCompanion<WorkoutExerciseOrder> {
  final Value<String> date;
  final Value<int> exerciseId;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const WorkoutExerciseOrdersCompanion({
    this.date = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkoutExerciseOrdersCompanion.insert({
    required String date,
    required int exerciseId,
    required int sortOrder,
    this.rowid = const Value.absent(),
  }) : date = Value(date),
       exerciseId = Value(exerciseId),
       sortOrder = Value(sortOrder);
  static Insertable<WorkoutExerciseOrder> custom({
    Expression<String>? date,
    Expression<int>? exerciseId,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkoutExerciseOrdersCompanion copyWith({
    Value<String>? date,
    Value<int>? exerciseId,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return WorkoutExerciseOrdersCompanion(
      date: date ?? this.date,
      exerciseId: exerciseId ?? this.exerciseId,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<int>(exerciseId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutExerciseOrdersCompanion(')
          ..write('date: $date, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $ExercisesTable exercises = $ExercisesTable(this);
  late final $ExerciseMultipliersTable exerciseMultipliers = $ExerciseMultipliersTable(this);
  late final $WorkoutSetsTable workoutSets = $WorkoutSetsTable(this);
  late final $WorkoutDayNotesTable workoutDayNotes = $WorkoutDayNotesTable(this);
  late final $PrResetMarkersTable prResetMarkers = $PrResetMarkersTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $RoutinesTable routines = $RoutinesTable(this);
  late final $RoutineDaysTable routineDays = $RoutineDaysTable(this);
  late final $RoutineSetsTable routineSets = $RoutineSetsTable(this);
  late final $MeasurementTypesTable measurementTypes = $MeasurementTypesTable(this);
  late final $MeasurementsTable measurements = $MeasurementsTable(this);
  late final $ExerciseGoalsTable exerciseGoals = $ExerciseGoalsTable(this);
  late final $WorkoutSessionsTable workoutSessions = $WorkoutSessionsTable(this);
  late final $WorkoutExerciseOrdersTable workoutExerciseOrders = $WorkoutExerciseOrdersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    categories,
    exercises,
    exerciseMultipliers,
    workoutSets,
    workoutDayNotes,
    prResetMarkers,
    appSettings,
    routines,
    routineDays,
    routineSets,
    measurementTypes,
    measurements,
    exerciseGoals,
    workoutSessions,
    workoutExerciseOrders,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName('routines', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('routine_days', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName('routine_days', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('routine_sets', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName('measurement_types', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('measurements', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName('exercises', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('exercise_goals', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName('exercises', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('workout_exercise_orders', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$CategoriesTableCreateCompanionBuilder = CategoriesCompanion Function({
  Value<int> id,
  required String name,
  Value<int> colorArgb,
  Value<int> sortOrder,
});
typedef $$CategoriesTableUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<int> colorArgb,
  Value<int> sortOrder,
});

final class $$CategoriesTableReferences extends BaseReferences<_$AppDatabase, $CategoriesTable, Category> {
  $$CategoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ExercisesTable, List<Exercise>> _exercisesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.exercises, aliasName: 'categories__id__exercises__category_id');

  $$ExercisesTableProcessedTableManager get exercisesRefs {
    final manager = $$ExercisesTableTableManager(
      $_db,
      $_db.exercises,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_exercisesRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$CategoriesTableFilterComposer extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get colorArgb => $composableBuilder(column: $table.colorArgb, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  Expression<bool> exercisesRefs(Expression<bool> Function($$ExercisesTableFilterComposer f) f) {
    final $$ExercisesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.categoryId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ExercisesTableFilterComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableOrderingComposer extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get colorArgb =>
      $composableBuilder(column: $table.colorArgb, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => ColumnOrderings(column));
}

class $$CategoriesTableAnnotationComposer extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get colorArgb => $composableBuilder(column: $table.colorArgb, builder: (column) => column);

  GeneratedColumn<int> get sortOrder => $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  Expression<T> exercisesRefs<T extends Object>(Expression<T> Function($$ExercisesTableAnnotationComposer a) f) {
    final $$ExercisesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.categoryId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ExercisesTableAnnotationComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriesTable,
          Category,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (Category, $$CategoriesTableReferences),
          Category,
          PrefetchHooks Function({bool exercisesRefs})
        > {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> colorArgb = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
          }) => CategoriesCompanion(id: id, name: name, colorArgb: colorArgb, sortOrder: sortOrder),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            Value<int> colorArgb = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
          }) => CategoriesCompanion.insert(id: id, name: name, colorArgb: colorArgb, sortOrder: sortOrder),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable<$CategoriesTable, Category>(table), $$CategoriesTableReferences(db, table, e))).toList(),
          prefetchHooksCallback: ({exercisesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (exercisesRefs) db.exercises],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (exercisesRefs)
                    await $_getPrefetchedData<Category, $CategoriesTable, Exercise>(
                      currentTable: table,
                      referencedTable: $$CategoriesTableReferences._exercisesRefsTable(db),
                      managerFromTypedResult: (p0) => $$CategoriesTableReferences(db, table, p0).exercisesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.categoryId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriesTable,
      Category,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (Category, $$CategoriesTableReferences),
      Category,
      PrefetchHooks Function({bool exercisesRefs})
    >;
typedef $$ExercisesTableCreateCompanionBuilder = ExercisesCompanion Function({
  Value<int> id,
  required String name,
  required int categoryId,
  Value<ExerciseType> type,
  Value<String?> notes,
  Value<int?> defaultRestTimeSeconds,
  Value<bool> isFavourite,
  Value<bool> archived,
  Value<int> sortOrder,
  Value<double?> weightIncrement,
});
typedef $$ExercisesTableUpdateCompanionBuilder = ExercisesCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<int> categoryId,
  Value<ExerciseType> type,
  Value<String?> notes,
  Value<int?> defaultRestTimeSeconds,
  Value<bool> isFavourite,
  Value<bool> archived,
  Value<int> sortOrder,
  Value<double?> weightIncrement,
});

final class $$ExercisesTableReferences extends BaseReferences<_$AppDatabase, $ExercisesTable, Exercise> {
  $$ExercisesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias('exercises__category_id__categories__id');

  $$CategoriesTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<int>('category_id')!;

    final manager = $$CategoriesTableTableManager($_db, $_db.categories).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$ExerciseMultipliersTable, List<ExerciseMultiplier>> _exerciseMultipliersRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(db.exerciseMultipliers, aliasName: 'exercises__id__exercise_multipliers__exercise_id');

  $$ExerciseMultipliersTableProcessedTableManager get exerciseMultipliersRefs {
    final manager = $$ExerciseMultipliersTableTableManager(
      $_db,
      $_db.exerciseMultipliers,
    ).filter((f) => f.exerciseId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_exerciseMultipliersRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$WorkoutSetsTable, List<WorkoutSet>> _workoutSetsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.workoutSets, aliasName: 'exercises__id__workout_sets__exercise_id');

  $$WorkoutSetsTableProcessedTableManager get workoutSetsRefs {
    final manager = $$WorkoutSetsTableTableManager(
      $_db,
      $_db.workoutSets,
    ).filter((f) => f.exerciseId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_workoutSetsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$RoutineSetsTable, List<RoutineSet>> _routineSetsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.routineSets, aliasName: 'exercises__id__routine_sets__exercise_id');

  $$RoutineSetsTableProcessedTableManager get routineSetsRefs {
    final manager = $$RoutineSetsTableTableManager(
      $_db,
      $_db.routineSets,
    ).filter((f) => f.exerciseId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_routineSetsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$ExerciseGoalsTable, List<ExerciseGoal>> _exerciseGoalsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.exerciseGoals, aliasName: 'exercises__id__exercise_goals__exercise_id');

  $$ExerciseGoalsTableProcessedTableManager get exerciseGoalsRefs {
    final manager = $$ExerciseGoalsTableTableManager(
      $_db,
      $_db.exerciseGoals,
    ).filter((f) => f.exerciseId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_exerciseGoalsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$WorkoutExerciseOrdersTable, List<WorkoutExerciseOrder>> _workoutExerciseOrdersRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(db.workoutExerciseOrders, aliasName: 'exercises__id__workout_exercise_orders__exercise_id');

  $$WorkoutExerciseOrdersTableProcessedTableManager get workoutExerciseOrdersRefs {
    final manager = $$WorkoutExerciseOrdersTableTableManager(
      $_db,
      $_db.workoutExerciseOrders,
    ).filter((f) => f.exerciseId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_workoutExerciseOrdersRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ExercisesTableFilterComposer extends Composer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<ExerciseType, ExerciseType, int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get defaultRestTimeSeconds =>
      $composableBuilder(column: $table.defaultRestTimeSeconds, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isFavourite =>
      $composableBuilder(column: $table.isFavourite, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get archived => $composableBuilder(column: $table.archived, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get weightIncrement =>
      $composableBuilder(column: $table.weightIncrement, builder: (column) => ColumnFilters(column));

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> exerciseMultipliersRefs(Expression<bool> Function($$ExerciseMultipliersTableFilterComposer f) f) {
    final $$ExerciseMultipliersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.exerciseMultipliers,
      getReferencedColumn: (t) => t.exerciseId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ExerciseMultipliersTableFilterComposer(
            $db: $db,
            $table: $db.exerciseMultipliers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> workoutSetsRefs(Expression<bool> Function($$WorkoutSetsTableFilterComposer f) f) {
    final $$WorkoutSetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workoutSets,
      getReferencedColumn: (t) => t.exerciseId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$WorkoutSetsTableFilterComposer(
            $db: $db,
            $table: $db.workoutSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> routineSetsRefs(Expression<bool> Function($$RoutineSetsTableFilterComposer f) f) {
    final $$RoutineSetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.routineSets,
      getReferencedColumn: (t) => t.exerciseId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RoutineSetsTableFilterComposer(
            $db: $db,
            $table: $db.routineSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> exerciseGoalsRefs(Expression<bool> Function($$ExerciseGoalsTableFilterComposer f) f) {
    final $$ExerciseGoalsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.exerciseGoals,
      getReferencedColumn: (t) => t.exerciseId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ExerciseGoalsTableFilterComposer(
            $db: $db,
            $table: $db.exerciseGoals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> workoutExerciseOrdersRefs(Expression<bool> Function($$WorkoutExerciseOrdersTableFilterComposer f) f) {
    final $$WorkoutExerciseOrdersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workoutExerciseOrders,
      getReferencedColumn: (t) => t.exerciseId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$WorkoutExerciseOrdersTableFilterComposer(
            $db: $db,
            $table: $db.workoutExerciseOrders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ExercisesTableOrderingComposer extends Composer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get type => $composableBuilder(column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get defaultRestTimeSeconds =>
      $composableBuilder(column: $table.defaultRestTimeSeconds, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isFavourite =>
      $composableBuilder(column: $table.isFavourite, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get archived => $composableBuilder(column: $table.archived, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get weightIncrement =>
      $composableBuilder(column: $table.weightIncrement, builder: (column) => ColumnOrderings(column));

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExercisesTableAnnotationComposer extends Composer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ExerciseType, int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get notes => $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get defaultRestTimeSeconds =>
      $composableBuilder(column: $table.defaultRestTimeSeconds, builder: (column) => column);

  GeneratedColumn<bool> get isFavourite => $composableBuilder(column: $table.isFavourite, builder: (column) => column);

  GeneratedColumn<bool> get archived => $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<int> get sortOrder => $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<double> get weightIncrement => $composableBuilder(column: $table.weightIncrement, builder: (column) => column);

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> exerciseMultipliersRefs<T extends Object>(
    Expression<T> Function($$ExerciseMultipliersTableAnnotationComposer a) f,
  ) {
    final $$ExerciseMultipliersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.exerciseMultipliers,
      getReferencedColumn: (t) => t.exerciseId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ExerciseMultipliersTableAnnotationComposer(
            $db: $db,
            $table: $db.exerciseMultipliers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> workoutSetsRefs<T extends Object>(Expression<T> Function($$WorkoutSetsTableAnnotationComposer a) f) {
    final $$WorkoutSetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workoutSets,
      getReferencedColumn: (t) => t.exerciseId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$WorkoutSetsTableAnnotationComposer(
            $db: $db,
            $table: $db.workoutSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> routineSetsRefs<T extends Object>(Expression<T> Function($$RoutineSetsTableAnnotationComposer a) f) {
    final $$RoutineSetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.routineSets,
      getReferencedColumn: (t) => t.exerciseId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RoutineSetsTableAnnotationComposer(
            $db: $db,
            $table: $db.routineSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> exerciseGoalsRefs<T extends Object>(Expression<T> Function($$ExerciseGoalsTableAnnotationComposer a) f) {
    final $$ExerciseGoalsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.exerciseGoals,
      getReferencedColumn: (t) => t.exerciseId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ExerciseGoalsTableAnnotationComposer(
            $db: $db,
            $table: $db.exerciseGoals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> workoutExerciseOrdersRefs<T extends Object>(
    Expression<T> Function($$WorkoutExerciseOrdersTableAnnotationComposer a) f,
  ) {
    final $$WorkoutExerciseOrdersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workoutExerciseOrders,
      getReferencedColumn: (t) => t.exerciseId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$WorkoutExerciseOrdersTableAnnotationComposer(
            $db: $db,
            $table: $db.workoutExerciseOrders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ExercisesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExercisesTable,
          Exercise,
          $$ExercisesTableFilterComposer,
          $$ExercisesTableOrderingComposer,
          $$ExercisesTableAnnotationComposer,
          $$ExercisesTableCreateCompanionBuilder,
          $$ExercisesTableUpdateCompanionBuilder,
          (Exercise, $$ExercisesTableReferences),
          Exercise,
          PrefetchHooks Function({
            bool categoryId,
            bool exerciseMultipliersRefs,
            bool workoutSetsRefs,
            bool routineSetsRefs,
            bool exerciseGoalsRefs,
            bool workoutExerciseOrdersRefs,
          })
        > {
  $$ExercisesTableTableManager(_$AppDatabase db, $ExercisesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$ExercisesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$ExercisesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$ExercisesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> categoryId = const Value.absent(),
                Value<ExerciseType> type = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int?> defaultRestTimeSeconds = const Value.absent(),
                Value<bool> isFavourite = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<double?> weightIncrement = const Value.absent(),
              }) => ExercisesCompanion(
                id: id,
                name: name,
                categoryId: categoryId,
                type: type,
                notes: notes,
                defaultRestTimeSeconds: defaultRestTimeSeconds,
                isFavourite: isFavourite,
                archived: archived,
                sortOrder: sortOrder,
                weightIncrement: weightIncrement,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required int categoryId,
                Value<ExerciseType> type = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int?> defaultRestTimeSeconds = const Value.absent(),
                Value<bool> isFavourite = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<double?> weightIncrement = const Value.absent(),
              }) => ExercisesCompanion.insert(
                id: id,
                name: name,
                categoryId: categoryId,
                type: type,
                notes: notes,
                defaultRestTimeSeconds: defaultRestTimeSeconds,
                isFavourite: isFavourite,
                archived: archived,
                sortOrder: sortOrder,
                weightIncrement: weightIncrement,
              ),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable<$ExercisesTable, Exercise>(table), $$ExercisesTableReferences(db, table, e))).toList(),
          prefetchHooksCallback:
              ({
                categoryId = false,
                exerciseMultipliersRefs = false,
                workoutSetsRefs = false,
                routineSetsRefs = false,
                exerciseGoalsRefs = false,
                workoutExerciseOrdersRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (exerciseMultipliersRefs) db.exerciseMultipliers,
                    if (workoutSetsRefs) db.workoutSets,
                    if (routineSetsRefs) db.routineSets,
                    if (exerciseGoalsRefs) db.exerciseGoals,
                    if (workoutExerciseOrdersRefs) db.workoutExerciseOrders,
                  ],
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
                        if (categoryId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.categoryId,
                            referencedTable: $$ExercisesTableReferences._categoryIdTable(db),
                            referencedColumn: $$ExercisesTableReferences._categoryIdTable(db).id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (exerciseMultipliersRefs)
                        await $_getPrefetchedData<Exercise, $ExercisesTable, ExerciseMultiplier>(
                          currentTable: table,
                          referencedTable: $$ExercisesTableReferences._exerciseMultipliersRefsTable(db),
                          managerFromTypedResult: (p0) => $$ExercisesTableReferences(db, table, p0).exerciseMultipliersRefs,
                          referencedItemsForCurrentItem: (item, referencedItems) =>
                              referencedItems.where((e) => e.exerciseId == item.id),
                          typedResults: items,
                        ),
                      if (workoutSetsRefs)
                        await $_getPrefetchedData<Exercise, $ExercisesTable, WorkoutSet>(
                          currentTable: table,
                          referencedTable: $$ExercisesTableReferences._workoutSetsRefsTable(db),
                          managerFromTypedResult: (p0) => $$ExercisesTableReferences(db, table, p0).workoutSetsRefs,
                          referencedItemsForCurrentItem: (item, referencedItems) =>
                              referencedItems.where((e) => e.exerciseId == item.id),
                          typedResults: items,
                        ),
                      if (routineSetsRefs)
                        await $_getPrefetchedData<Exercise, $ExercisesTable, RoutineSet>(
                          currentTable: table,
                          referencedTable: $$ExercisesTableReferences._routineSetsRefsTable(db),
                          managerFromTypedResult: (p0) => $$ExercisesTableReferences(db, table, p0).routineSetsRefs,
                          referencedItemsForCurrentItem: (item, referencedItems) =>
                              referencedItems.where((e) => e.exerciseId == item.id),
                          typedResults: items,
                        ),
                      if (exerciseGoalsRefs)
                        await $_getPrefetchedData<Exercise, $ExercisesTable, ExerciseGoal>(
                          currentTable: table,
                          referencedTable: $$ExercisesTableReferences._exerciseGoalsRefsTable(db),
                          managerFromTypedResult: (p0) => $$ExercisesTableReferences(db, table, p0).exerciseGoalsRefs,
                          referencedItemsForCurrentItem: (item, referencedItems) =>
                              referencedItems.where((e) => e.exerciseId == item.id),
                          typedResults: items,
                        ),
                      if (workoutExerciseOrdersRefs)
                        await $_getPrefetchedData<Exercise, $ExercisesTable, WorkoutExerciseOrder>(
                          currentTable: table,
                          referencedTable: $$ExercisesTableReferences._workoutExerciseOrdersRefsTable(db),
                          managerFromTypedResult: (p0) => $$ExercisesTableReferences(db, table, p0).workoutExerciseOrdersRefs,
                          referencedItemsForCurrentItem: (item, referencedItems) =>
                              referencedItems.where((e) => e.exerciseId == item.id),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ExercisesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExercisesTable,
      Exercise,
      $$ExercisesTableFilterComposer,
      $$ExercisesTableOrderingComposer,
      $$ExercisesTableAnnotationComposer,
      $$ExercisesTableCreateCompanionBuilder,
      $$ExercisesTableUpdateCompanionBuilder,
      (Exercise, $$ExercisesTableReferences),
      Exercise,
      PrefetchHooks Function({
        bool categoryId,
        bool exerciseMultipliersRefs,
        bool workoutSetsRefs,
        bool routineSetsRefs,
        bool exerciseGoalsRefs,
        bool workoutExerciseOrdersRefs,
      })
    >;
typedef $$ExerciseMultipliersTableCreateCompanionBuilder = ExerciseMultipliersCompanion Function({
  Value<int> id,
  required int exerciseId,
  required String label,
  Value<double> factor,
  Value<bool> enabled,
  Value<int> sortOrder,
});
typedef $$ExerciseMultipliersTableUpdateCompanionBuilder = ExerciseMultipliersCompanion Function({
  Value<int> id,
  Value<int> exerciseId,
  Value<String> label,
  Value<double> factor,
  Value<bool> enabled,
  Value<int> sortOrder,
});

final class $$ExerciseMultipliersTableReferences
    extends BaseReferences<_$AppDatabase, $ExerciseMultipliersTable, ExerciseMultiplier> {
  $$ExerciseMultipliersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ExercisesTable _exerciseIdTable(_$AppDatabase db) =>
      db.exercises.createAlias('exercise_multipliers__exercise_id__exercises__id');

  $$ExercisesTableProcessedTableManager get exerciseId {
    final $_column = $_itemColumn<int>('exercise_id')!;

    final manager = $$ExercisesTableTableManager($_db, $_db.exercises).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_exerciseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ExerciseMultipliersTableFilterComposer extends Composer<_$AppDatabase, $ExerciseMultipliersTable> {
  $$ExerciseMultipliersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get label => $composableBuilder(column: $table.label, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get factor => $composableBuilder(column: $table.factor, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get enabled => $composableBuilder(column: $table.enabled, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  $$ExercisesTableFilterComposer get exerciseId {
    final $$ExercisesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ExercisesTableFilterComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExerciseMultipliersTableOrderingComposer extends Composer<_$AppDatabase, $ExerciseMultipliersTable> {
  $$ExerciseMultipliersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get label => $composableBuilder(column: $table.label, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get factor => $composableBuilder(column: $table.factor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get enabled => $composableBuilder(column: $table.enabled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  $$ExercisesTableOrderingComposer get exerciseId {
    final $$ExercisesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ExercisesTableOrderingComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExerciseMultipliersTableAnnotationComposer extends Composer<_$AppDatabase, $ExerciseMultipliersTable> {
  $$ExerciseMultipliersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label => $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<double> get factor => $composableBuilder(column: $table.factor, builder: (column) => column);

  GeneratedColumn<bool> get enabled => $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<int> get sortOrder => $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$ExercisesTableAnnotationComposer get exerciseId {
    final $$ExercisesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ExercisesTableAnnotationComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExerciseMultipliersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExerciseMultipliersTable,
          ExerciseMultiplier,
          $$ExerciseMultipliersTableFilterComposer,
          $$ExerciseMultipliersTableOrderingComposer,
          $$ExerciseMultipliersTableAnnotationComposer,
          $$ExerciseMultipliersTableCreateCompanionBuilder,
          $$ExerciseMultipliersTableUpdateCompanionBuilder,
          (ExerciseMultiplier, $$ExerciseMultipliersTableReferences),
          ExerciseMultiplier,
          PrefetchHooks Function({bool exerciseId})
        > {
  $$ExerciseMultipliersTableTableManager(_$AppDatabase db, $ExerciseMultipliersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$ExerciseMultipliersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$ExerciseMultipliersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$ExerciseMultipliersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> exerciseId = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<double> factor = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => ExerciseMultipliersCompanion(
                id: id,
                exerciseId: exerciseId,
                label: label,
                factor: factor,
                enabled: enabled,
                sortOrder: sortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int exerciseId,
                required String label,
                Value<double> factor = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => ExerciseMultipliersCompanion.insert(
                id: id,
                exerciseId: exerciseId,
                label: label,
                factor: factor,
                enabled: enabled,
                sortOrder: sortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ExerciseMultipliersTable, ExerciseMultiplier>(table),
                  $$ExerciseMultipliersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({exerciseId = false}) {
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
                    if (exerciseId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.exerciseId,
                        referencedTable: $$ExerciseMultipliersTableReferences._exerciseIdTable(db),
                        referencedColumn: $$ExerciseMultipliersTableReferences._exerciseIdTable(db).id,
                      ) as T;
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

typedef $$ExerciseMultipliersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExerciseMultipliersTable,
      ExerciseMultiplier,
      $$ExerciseMultipliersTableFilterComposer,
      $$ExerciseMultipliersTableOrderingComposer,
      $$ExerciseMultipliersTableAnnotationComposer,
      $$ExerciseMultipliersTableCreateCompanionBuilder,
      $$ExerciseMultipliersTableUpdateCompanionBuilder,
      (ExerciseMultiplier, $$ExerciseMultipliersTableReferences),
      ExerciseMultiplier,
      PrefetchHooks Function({bool exerciseId})
    >;
typedef $$WorkoutSetsTableCreateCompanionBuilder = WorkoutSetsCompanion Function({
  Value<int> id,
  required int exerciseId,
  required String date,
  Value<double> rawWeight,
  Value<double> weightMultiplier,
  Value<int> reps,
  Value<double> distance,
  Value<int> durationSeconds,
  Value<bool> isComplete,
  Value<String?> note,
  required DateTime createdAt,
  Value<String?> sourceKey,
  Value<bool> isPlanned,
  Value<double?> rpe,
  Value<String?> groupName,
});
typedef $$WorkoutSetsTableUpdateCompanionBuilder = WorkoutSetsCompanion Function({
  Value<int> id,
  Value<int> exerciseId,
  Value<String> date,
  Value<double> rawWeight,
  Value<double> weightMultiplier,
  Value<int> reps,
  Value<double> distance,
  Value<int> durationSeconds,
  Value<bool> isComplete,
  Value<String?> note,
  Value<DateTime> createdAt,
  Value<String?> sourceKey,
  Value<bool> isPlanned,
  Value<double?> rpe,
  Value<String?> groupName,
});

final class $$WorkoutSetsTableReferences extends BaseReferences<_$AppDatabase, $WorkoutSetsTable, WorkoutSet> {
  $$WorkoutSetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ExercisesTable _exerciseIdTable(_$AppDatabase db) =>
      db.exercises.createAlias('workout_sets__exercise_id__exercises__id');

  $$ExercisesTableProcessedTableManager get exerciseId {
    final $_column = $_itemColumn<int>('exercise_id')!;

    final manager = $$ExercisesTableTableManager($_db, $_db.exercises).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_exerciseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$WorkoutSetsTableFilterComposer extends Composer<_$AppDatabase, $WorkoutSetsTable> {
  $$WorkoutSetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get date => $composableBuilder(column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get rawWeight => $composableBuilder(column: $table.rawWeight, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get weightMultiplier =>
      $composableBuilder(column: $table.weightMultiplier, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get reps => $composableBuilder(column: $table.reps, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get distance => $composableBuilder(column: $table.distance, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationSeconds =>
      $composableBuilder(column: $table.durationSeconds, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isComplete => $composableBuilder(column: $table.isComplete, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceKey => $composableBuilder(column: $table.sourceKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isPlanned => $composableBuilder(column: $table.isPlanned, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get rpe => $composableBuilder(column: $table.rpe, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get groupName => $composableBuilder(column: $table.groupName, builder: (column) => ColumnFilters(column));

  $$ExercisesTableFilterComposer get exerciseId {
    final $$ExercisesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ExercisesTableFilterComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkoutSetsTableOrderingComposer extends Composer<_$AppDatabase, $WorkoutSetsTable> {
  $$WorkoutSetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get date => $composableBuilder(column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get rawWeight =>
      $composableBuilder(column: $table.rawWeight, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get weightMultiplier =>
      $composableBuilder(column: $table.weightMultiplier, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get reps => $composableBuilder(column: $table.reps, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get distance =>
      $composableBuilder(column: $table.distance, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationSeconds =>
      $composableBuilder(column: $table.durationSeconds, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isComplete =>
      $composableBuilder(column: $table.isComplete, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceKey =>
      $composableBuilder(column: $table.sourceKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isPlanned =>
      $composableBuilder(column: $table.isPlanned, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get rpe => $composableBuilder(column: $table.rpe, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get groupName =>
      $composableBuilder(column: $table.groupName, builder: (column) => ColumnOrderings(column));

  $$ExercisesTableOrderingComposer get exerciseId {
    final $$ExercisesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ExercisesTableOrderingComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkoutSetsTableAnnotationComposer extends Composer<_$AppDatabase, $WorkoutSetsTable> {
  $$WorkoutSetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get date => $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<double> get rawWeight => $composableBuilder(column: $table.rawWeight, builder: (column) => column);

  GeneratedColumn<double> get weightMultiplier =>
      $composableBuilder(column: $table.weightMultiplier, builder: (column) => column);

  GeneratedColumn<int> get reps => $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<double> get distance => $composableBuilder(column: $table.distance, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(column: $table.durationSeconds, builder: (column) => column);

  GeneratedColumn<bool> get isComplete => $composableBuilder(column: $table.isComplete, builder: (column) => column);

  GeneratedColumn<String> get note => $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get sourceKey => $composableBuilder(column: $table.sourceKey, builder: (column) => column);

  GeneratedColumn<bool> get isPlanned => $composableBuilder(column: $table.isPlanned, builder: (column) => column);

  GeneratedColumn<double> get rpe => $composableBuilder(column: $table.rpe, builder: (column) => column);

  GeneratedColumn<String> get groupName => $composableBuilder(column: $table.groupName, builder: (column) => column);

  $$ExercisesTableAnnotationComposer get exerciseId {
    final $$ExercisesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ExercisesTableAnnotationComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkoutSetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkoutSetsTable,
          WorkoutSet,
          $$WorkoutSetsTableFilterComposer,
          $$WorkoutSetsTableOrderingComposer,
          $$WorkoutSetsTableAnnotationComposer,
          $$WorkoutSetsTableCreateCompanionBuilder,
          $$WorkoutSetsTableUpdateCompanionBuilder,
          (WorkoutSet, $$WorkoutSetsTableReferences),
          WorkoutSet,
          PrefetchHooks Function({bool exerciseId})
        > {
  $$WorkoutSetsTableTableManager(_$AppDatabase db, $WorkoutSetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$WorkoutSetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$WorkoutSetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$WorkoutSetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> exerciseId = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<double> rawWeight = const Value.absent(),
                Value<double> weightMultiplier = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<double> distance = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
                Value<bool> isComplete = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> sourceKey = const Value.absent(),
                Value<bool> isPlanned = const Value.absent(),
                Value<double?> rpe = const Value.absent(),
                Value<String?> groupName = const Value.absent(),
              }) => WorkoutSetsCompanion(
                id: id,
                exerciseId: exerciseId,
                date: date,
                rawWeight: rawWeight,
                weightMultiplier: weightMultiplier,
                reps: reps,
                distance: distance,
                durationSeconds: durationSeconds,
                isComplete: isComplete,
                note: note,
                createdAt: createdAt,
                sourceKey: sourceKey,
                isPlanned: isPlanned,
                rpe: rpe,
                groupName: groupName,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int exerciseId,
                required String date,
                Value<double> rawWeight = const Value.absent(),
                Value<double> weightMultiplier = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<double> distance = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
                Value<bool> isComplete = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required DateTime createdAt,
                Value<String?> sourceKey = const Value.absent(),
                Value<bool> isPlanned = const Value.absent(),
                Value<double?> rpe = const Value.absent(),
                Value<String?> groupName = const Value.absent(),
              }) => WorkoutSetsCompanion.insert(
                id: id,
                exerciseId: exerciseId,
                date: date,
                rawWeight: rawWeight,
                weightMultiplier: weightMultiplier,
                reps: reps,
                distance: distance,
                durationSeconds: durationSeconds,
                isComplete: isComplete,
                note: note,
                createdAt: createdAt,
                sourceKey: sourceKey,
                isPlanned: isPlanned,
                rpe: rpe,
                groupName: groupName,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable<$WorkoutSetsTable, WorkoutSet>(table), $$WorkoutSetsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({exerciseId = false}) {
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
                    if (exerciseId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.exerciseId,
                        referencedTable: $$WorkoutSetsTableReferences._exerciseIdTable(db),
                        referencedColumn: $$WorkoutSetsTableReferences._exerciseIdTable(db).id,
                      ) as T;
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

typedef $$WorkoutSetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkoutSetsTable,
      WorkoutSet,
      $$WorkoutSetsTableFilterComposer,
      $$WorkoutSetsTableOrderingComposer,
      $$WorkoutSetsTableAnnotationComposer,
      $$WorkoutSetsTableCreateCompanionBuilder,
      $$WorkoutSetsTableUpdateCompanionBuilder,
      (WorkoutSet, $$WorkoutSetsTableReferences),
      WorkoutSet,
      PrefetchHooks Function({bool exerciseId})
    >;
typedef $$WorkoutDayNotesTableCreateCompanionBuilder = WorkoutDayNotesCompanion Function({
  Value<int> id,
  required String date,
  required String comment,
});
typedef $$WorkoutDayNotesTableUpdateCompanionBuilder = WorkoutDayNotesCompanion Function({
  Value<int> id,
  Value<String> date,
  Value<String> comment,
});

class $$WorkoutDayNotesTableFilterComposer extends Composer<_$AppDatabase, $WorkoutDayNotesTable> {
  $$WorkoutDayNotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get date => $composableBuilder(column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get comment => $composableBuilder(column: $table.comment, builder: (column) => ColumnFilters(column));
}

class $$WorkoutDayNotesTableOrderingComposer extends Composer<_$AppDatabase, $WorkoutDayNotesTable> {
  $$WorkoutDayNotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get date => $composableBuilder(column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get comment => $composableBuilder(column: $table.comment, builder: (column) => ColumnOrderings(column));
}

class $$WorkoutDayNotesTableAnnotationComposer extends Composer<_$AppDatabase, $WorkoutDayNotesTable> {
  $$WorkoutDayNotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get date => $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get comment => $composableBuilder(column: $table.comment, builder: (column) => column);
}

class $$WorkoutDayNotesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkoutDayNotesTable,
          WorkoutDayNote,
          $$WorkoutDayNotesTableFilterComposer,
          $$WorkoutDayNotesTableOrderingComposer,
          $$WorkoutDayNotesTableAnnotationComposer,
          $$WorkoutDayNotesTableCreateCompanionBuilder,
          $$WorkoutDayNotesTableUpdateCompanionBuilder,
          (WorkoutDayNote, BaseReferences<_$AppDatabase, $WorkoutDayNotesTable, WorkoutDayNote>),
          WorkoutDayNote,
          PrefetchHooks Function()
        > {
  $$WorkoutDayNotesTableTableManager(_$AppDatabase db, $WorkoutDayNotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$WorkoutDayNotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$WorkoutDayNotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$WorkoutDayNotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> date = const Value.absent(),
            Value<String> comment = const Value.absent(),
          }) => WorkoutDayNotesCompanion(id: id, date: date, comment: comment),
          createCompanionCallback: ({Value<int> id = const Value.absent(), required String date, required String comment}) =>
              WorkoutDayNotesCompanion.insert(id: id, date: date, comment: comment),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WorkoutDayNotesTable, WorkoutDayNote>(table),
                  BaseReferences<_$AppDatabase, $WorkoutDayNotesTable, WorkoutDayNote>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WorkoutDayNotesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkoutDayNotesTable,
      WorkoutDayNote,
      $$WorkoutDayNotesTableFilterComposer,
      $$WorkoutDayNotesTableOrderingComposer,
      $$WorkoutDayNotesTableAnnotationComposer,
      $$WorkoutDayNotesTableCreateCompanionBuilder,
      $$WorkoutDayNotesTableUpdateCompanionBuilder,
      (WorkoutDayNote, BaseReferences<_$AppDatabase, $WorkoutDayNotesTable, WorkoutDayNote>),
      WorkoutDayNote,
      PrefetchHooks Function()
    >;
typedef $$PrResetMarkersTableCreateCompanionBuilder = PrResetMarkersCompanion Function({
  Value<int> id,
  required String date,
  Value<String?> note,
  required DateTime createdAt,
});
typedef $$PrResetMarkersTableUpdateCompanionBuilder = PrResetMarkersCompanion Function({
  Value<int> id,
  Value<String> date,
  Value<String?> note,
  Value<DateTime> createdAt,
});

class $$PrResetMarkersTableFilterComposer extends Composer<_$AppDatabase, $PrResetMarkersTable> {
  $$PrResetMarkersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get date => $composableBuilder(column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$PrResetMarkersTableOrderingComposer extends Composer<_$AppDatabase, $PrResetMarkersTable> {
  $$PrResetMarkersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get date => $composableBuilder(column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$PrResetMarkersTableAnnotationComposer extends Composer<_$AppDatabase, $PrResetMarkersTable> {
  $$PrResetMarkersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get date => $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get note => $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PrResetMarkersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PrResetMarkersTable,
          PrResetMarker,
          $$PrResetMarkersTableFilterComposer,
          $$PrResetMarkersTableOrderingComposer,
          $$PrResetMarkersTableAnnotationComposer,
          $$PrResetMarkersTableCreateCompanionBuilder,
          $$PrResetMarkersTableUpdateCompanionBuilder,
          (PrResetMarker, BaseReferences<_$AppDatabase, $PrResetMarkersTable, PrResetMarker>),
          PrResetMarker,
          PrefetchHooks Function()
        > {
  $$PrResetMarkersTableTableManager(_$AppDatabase db, $PrResetMarkersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$PrResetMarkersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$PrResetMarkersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$PrResetMarkersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> date = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) => PrResetMarkersCompanion(id: id, date: date, note: note, createdAt: createdAt),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String date,
            Value<String?> note = const Value.absent(),
            required DateTime createdAt,
          }) => PrResetMarkersCompanion.insert(id: id, date: date, note: note, createdAt: createdAt),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PrResetMarkersTable, PrResetMarker>(table),
                  BaseReferences<_$AppDatabase, $PrResetMarkersTable, PrResetMarker>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PrResetMarkersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PrResetMarkersTable,
      PrResetMarker,
      $$PrResetMarkersTableFilterComposer,
      $$PrResetMarkersTableOrderingComposer,
      $$PrResetMarkersTableAnnotationComposer,
      $$PrResetMarkersTableCreateCompanionBuilder,
      $$PrResetMarkersTableUpdateCompanionBuilder,
      (PrResetMarker, BaseReferences<_$AppDatabase, $PrResetMarkersTable, PrResetMarker>),
      PrResetMarker,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableCreateCompanionBuilder = AppSettingsCompanion Function({
  Value<int> id,
  Value<int> themeMode,
  Value<int> firstDayOfWeek,
  Value<double> defaultWeightIncrement,
  Value<int> restTimerSeconds,
  Value<bool> restTimerVibrate,
  Value<bool> restTimerSound,
  Value<bool> restTimerAutoStart,
  Value<bool> trackPersonalRecords,
  Value<bool> markSetsComplete,
  Value<bool> keepScreenOn,
  Value<int> estimated1rmMaxReps,
  Value<bool> useImperial,
});
typedef $$AppSettingsTableUpdateCompanionBuilder = AppSettingsCompanion Function({
  Value<int> id,
  Value<int> themeMode,
  Value<int> firstDayOfWeek,
  Value<double> defaultWeightIncrement,
  Value<int> restTimerSeconds,
  Value<bool> restTimerVibrate,
  Value<bool> restTimerSound,
  Value<bool> restTimerAutoStart,
  Value<bool> trackPersonalRecords,
  Value<bool> markSetsComplete,
  Value<bool> keepScreenOn,
  Value<int> estimated1rmMaxReps,
  Value<bool> useImperial,
});

class $$AppSettingsTableFilterComposer extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get themeMode => $composableBuilder(column: $table.themeMode, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get firstDayOfWeek =>
      $composableBuilder(column: $table.firstDayOfWeek, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get defaultWeightIncrement =>
      $composableBuilder(column: $table.defaultWeightIncrement, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get restTimerSeconds =>
      $composableBuilder(column: $table.restTimerSeconds, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get restTimerVibrate =>
      $composableBuilder(column: $table.restTimerVibrate, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get restTimerSound =>
      $composableBuilder(column: $table.restTimerSound, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get restTimerAutoStart =>
      $composableBuilder(column: $table.restTimerAutoStart, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get trackPersonalRecords =>
      $composableBuilder(column: $table.trackPersonalRecords, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get markSetsComplete =>
      $composableBuilder(column: $table.markSetsComplete, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get keepScreenOn =>
      $composableBuilder(column: $table.keepScreenOn, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get estimated1rmMaxReps =>
      $composableBuilder(column: $table.estimated1rmMaxReps, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get useImperial =>
      $composableBuilder(column: $table.useImperial, builder: (column) => ColumnFilters(column));
}

class $$AppSettingsTableOrderingComposer extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get themeMode =>
      $composableBuilder(column: $table.themeMode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get firstDayOfWeek =>
      $composableBuilder(column: $table.firstDayOfWeek, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get defaultWeightIncrement =>
      $composableBuilder(column: $table.defaultWeightIncrement, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get restTimerSeconds =>
      $composableBuilder(column: $table.restTimerSeconds, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get restTimerVibrate =>
      $composableBuilder(column: $table.restTimerVibrate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get restTimerSound =>
      $composableBuilder(column: $table.restTimerSound, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get restTimerAutoStart =>
      $composableBuilder(column: $table.restTimerAutoStart, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get trackPersonalRecords =>
      $composableBuilder(column: $table.trackPersonalRecords, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get markSetsComplete =>
      $composableBuilder(column: $table.markSetsComplete, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get keepScreenOn =>
      $composableBuilder(column: $table.keepScreenOn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get estimated1rmMaxReps =>
      $composableBuilder(column: $table.estimated1rmMaxReps, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get useImperial =>
      $composableBuilder(column: $table.useImperial, builder: (column) => ColumnOrderings(column));
}

class $$AppSettingsTableAnnotationComposer extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get themeMode => $composableBuilder(column: $table.themeMode, builder: (column) => column);

  GeneratedColumn<int> get firstDayOfWeek => $composableBuilder(column: $table.firstDayOfWeek, builder: (column) => column);

  GeneratedColumn<double> get defaultWeightIncrement =>
      $composableBuilder(column: $table.defaultWeightIncrement, builder: (column) => column);

  GeneratedColumn<int> get restTimerSeconds => $composableBuilder(column: $table.restTimerSeconds, builder: (column) => column);

  GeneratedColumn<bool> get restTimerVibrate => $composableBuilder(column: $table.restTimerVibrate, builder: (column) => column);

  GeneratedColumn<bool> get restTimerSound => $composableBuilder(column: $table.restTimerSound, builder: (column) => column);

  GeneratedColumn<bool> get restTimerAutoStart =>
      $composableBuilder(column: $table.restTimerAutoStart, builder: (column) => column);

  GeneratedColumn<bool> get trackPersonalRecords =>
      $composableBuilder(column: $table.trackPersonalRecords, builder: (column) => column);

  GeneratedColumn<bool> get markSetsComplete => $composableBuilder(column: $table.markSetsComplete, builder: (column) => column);

  GeneratedColumn<bool> get keepScreenOn => $composableBuilder(column: $table.keepScreenOn, builder: (column) => column);

  GeneratedColumn<int> get estimated1rmMaxReps =>
      $composableBuilder(column: $table.estimated1rmMaxReps, builder: (column) => column);

  GeneratedColumn<bool> get useImperial => $composableBuilder(column: $table.useImperial, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSettingsRow,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (AppSettingsRow, BaseReferences<_$AppDatabase, $AppSettingsTable, AppSettingsRow>),
          AppSettingsRow,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> themeMode = const Value.absent(),
                Value<int> firstDayOfWeek = const Value.absent(),
                Value<double> defaultWeightIncrement = const Value.absent(),
                Value<int> restTimerSeconds = const Value.absent(),
                Value<bool> restTimerVibrate = const Value.absent(),
                Value<bool> restTimerSound = const Value.absent(),
                Value<bool> restTimerAutoStart = const Value.absent(),
                Value<bool> trackPersonalRecords = const Value.absent(),
                Value<bool> markSetsComplete = const Value.absent(),
                Value<bool> keepScreenOn = const Value.absent(),
                Value<int> estimated1rmMaxReps = const Value.absent(),
                Value<bool> useImperial = const Value.absent(),
              }) => AppSettingsCompanion(
                id: id,
                themeMode: themeMode,
                firstDayOfWeek: firstDayOfWeek,
                defaultWeightIncrement: defaultWeightIncrement,
                restTimerSeconds: restTimerSeconds,
                restTimerVibrate: restTimerVibrate,
                restTimerSound: restTimerSound,
                restTimerAutoStart: restTimerAutoStart,
                trackPersonalRecords: trackPersonalRecords,
                markSetsComplete: markSetsComplete,
                keepScreenOn: keepScreenOn,
                estimated1rmMaxReps: estimated1rmMaxReps,
                useImperial: useImperial,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> themeMode = const Value.absent(),
                Value<int> firstDayOfWeek = const Value.absent(),
                Value<double> defaultWeightIncrement = const Value.absent(),
                Value<int> restTimerSeconds = const Value.absent(),
                Value<bool> restTimerVibrate = const Value.absent(),
                Value<bool> restTimerSound = const Value.absent(),
                Value<bool> restTimerAutoStart = const Value.absent(),
                Value<bool> trackPersonalRecords = const Value.absent(),
                Value<bool> markSetsComplete = const Value.absent(),
                Value<bool> keepScreenOn = const Value.absent(),
                Value<int> estimated1rmMaxReps = const Value.absent(),
                Value<bool> useImperial = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                id: id,
                themeMode: themeMode,
                firstDayOfWeek: firstDayOfWeek,
                defaultWeightIncrement: defaultWeightIncrement,
                restTimerSeconds: restTimerSeconds,
                restTimerVibrate: restTimerVibrate,
                restTimerSound: restTimerSound,
                restTimerAutoStart: restTimerAutoStart,
                trackPersonalRecords: trackPersonalRecords,
                markSetsComplete: markSetsComplete,
                keepScreenOn: keepScreenOn,
                estimated1rmMaxReps: estimated1rmMaxReps,
                useImperial: useImperial,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppSettingsTable, AppSettingsRow>(table),
                  BaseReferences<_$AppDatabase, $AppSettingsTable, AppSettingsRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSettingsRow,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (AppSettingsRow, BaseReferences<_$AppDatabase, $AppSettingsTable, AppSettingsRow>),
      AppSettingsRow,
      PrefetchHooks Function()
    >;
typedef $$RoutinesTableCreateCompanionBuilder = RoutinesCompanion Function({
  Value<int> id,
  required String name,
  Value<String> notes,
});
typedef $$RoutinesTableUpdateCompanionBuilder = RoutinesCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> notes,
});

final class $$RoutinesTableReferences extends BaseReferences<_$AppDatabase, $RoutinesTable, Routine> {
  $$RoutinesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$RoutineDaysTable, List<RoutineDay>> _routineDaysRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.routineDays, aliasName: 'routines__id__routine_days__routine_id');

  $$RoutineDaysTableProcessedTableManager get routineDaysRefs {
    final manager = $$RoutineDaysTableTableManager(
      $_db,
      $_db.routineDays,
    ).filter((f) => f.routineId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_routineDaysRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$RoutinesTableFilterComposer extends Composer<_$AppDatabase, $RoutinesTable> {
  $$RoutinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(column: $table.notes, builder: (column) => ColumnFilters(column));

  Expression<bool> routineDaysRefs(Expression<bool> Function($$RoutineDaysTableFilterComposer f) f) {
    final $$RoutineDaysTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.routineDays,
      getReferencedColumn: (t) => t.routineId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RoutineDaysTableFilterComposer(
            $db: $db,
            $table: $db.routineDays,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RoutinesTableOrderingComposer extends Composer<_$AppDatabase, $RoutinesTable> {
  $$RoutinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(column: $table.notes, builder: (column) => ColumnOrderings(column));
}

class $$RoutinesTableAnnotationComposer extends Composer<_$AppDatabase, $RoutinesTable> {
  $$RoutinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get notes => $composableBuilder(column: $table.notes, builder: (column) => column);

  Expression<T> routineDaysRefs<T extends Object>(Expression<T> Function($$RoutineDaysTableAnnotationComposer a) f) {
    final $$RoutineDaysTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.routineDays,
      getReferencedColumn: (t) => t.routineId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RoutineDaysTableAnnotationComposer(
            $db: $db,
            $table: $db.routineDays,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RoutinesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RoutinesTable,
          Routine,
          $$RoutinesTableFilterComposer,
          $$RoutinesTableOrderingComposer,
          $$RoutinesTableAnnotationComposer,
          $$RoutinesTableCreateCompanionBuilder,
          $$RoutinesTableUpdateCompanionBuilder,
          (Routine, $$RoutinesTableReferences),
          Routine,
          PrefetchHooks Function({bool routineDaysRefs})
        > {
  $$RoutinesTableTableManager(_$AppDatabase db, $RoutinesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$RoutinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$RoutinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$RoutinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> notes = const Value.absent(),
          }) => RoutinesCompanion(id: id, name: name, notes: notes),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            Value<String> notes = const Value.absent(),
          }) => RoutinesCompanion.insert(id: id, name: name, notes: notes),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable<$RoutinesTable, Routine>(table), $$RoutinesTableReferences(db, table, e))).toList(),
          prefetchHooksCallback: ({routineDaysRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (routineDaysRefs) db.routineDays],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (routineDaysRefs)
                    await $_getPrefetchedData<Routine, $RoutinesTable, RoutineDay>(
                      currentTable: table,
                      referencedTable: $$RoutinesTableReferences._routineDaysRefsTable(db),
                      managerFromTypedResult: (p0) => $$RoutinesTableReferences(db, table, p0).routineDaysRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.routineId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$RoutinesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RoutinesTable,
      Routine,
      $$RoutinesTableFilterComposer,
      $$RoutinesTableOrderingComposer,
      $$RoutinesTableAnnotationComposer,
      $$RoutinesTableCreateCompanionBuilder,
      $$RoutinesTableUpdateCompanionBuilder,
      (Routine, $$RoutinesTableReferences),
      Routine,
      PrefetchHooks Function({bool routineDaysRefs})
    >;
typedef $$RoutineDaysTableCreateCompanionBuilder = RoutineDaysCompanion Function({
  Value<int> id,
  required int routineId,
  required String name,
  Value<int> sortOrder,
});
typedef $$RoutineDaysTableUpdateCompanionBuilder = RoutineDaysCompanion Function({
  Value<int> id,
  Value<int> routineId,
  Value<String> name,
  Value<int> sortOrder,
});

final class $$RoutineDaysTableReferences extends BaseReferences<_$AppDatabase, $RoutineDaysTable, RoutineDay> {
  $$RoutineDaysTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RoutinesTable _routineIdTable(_$AppDatabase db) => db.routines.createAlias('routine_days__routine_id__routines__id');

  $$RoutinesTableProcessedTableManager get routineId {
    final $_column = $_itemColumn<int>('routine_id')!;

    final manager = $$RoutinesTableTableManager($_db, $_db.routines).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_routineIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$RoutineSetsTable, List<RoutineSet>> _routineSetsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.routineSets, aliasName: 'routine_days__id__routine_sets__day_id');

  $$RoutineSetsTableProcessedTableManager get routineSetsRefs {
    final manager = $$RoutineSetsTableTableManager(
      $_db,
      $_db.routineSets,
    ).filter((f) => f.dayId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_routineSetsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$RoutineDaysTableFilterComposer extends Composer<_$AppDatabase, $RoutineDaysTable> {
  $$RoutineDaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  $$RoutinesTableFilterComposer get routineId {
    final $$RoutinesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.routineId,
      referencedTable: $db.routines,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RoutinesTableFilterComposer(
            $db: $db,
            $table: $db.routines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> routineSetsRefs(Expression<bool> Function($$RoutineSetsTableFilterComposer f) f) {
    final $$RoutineSetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.routineSets,
      getReferencedColumn: (t) => t.dayId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RoutineSetsTableFilterComposer(
            $db: $db,
            $table: $db.routineSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RoutineDaysTableOrderingComposer extends Composer<_$AppDatabase, $RoutineDaysTable> {
  $$RoutineDaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  $$RoutinesTableOrderingComposer get routineId {
    final $$RoutinesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.routineId,
      referencedTable: $db.routines,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RoutinesTableOrderingComposer(
            $db: $db,
            $table: $db.routines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RoutineDaysTableAnnotationComposer extends Composer<_$AppDatabase, $RoutineDaysTable> {
  $$RoutineDaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get sortOrder => $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$RoutinesTableAnnotationComposer get routineId {
    final $$RoutinesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.routineId,
      referencedTable: $db.routines,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RoutinesTableAnnotationComposer(
            $db: $db,
            $table: $db.routines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> routineSetsRefs<T extends Object>(Expression<T> Function($$RoutineSetsTableAnnotationComposer a) f) {
    final $$RoutineSetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.routineSets,
      getReferencedColumn: (t) => t.dayId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RoutineSetsTableAnnotationComposer(
            $db: $db,
            $table: $db.routineSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RoutineDaysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RoutineDaysTable,
          RoutineDay,
          $$RoutineDaysTableFilterComposer,
          $$RoutineDaysTableOrderingComposer,
          $$RoutineDaysTableAnnotationComposer,
          $$RoutineDaysTableCreateCompanionBuilder,
          $$RoutineDaysTableUpdateCompanionBuilder,
          (RoutineDay, $$RoutineDaysTableReferences),
          RoutineDay,
          PrefetchHooks Function({bool routineId, bool routineSetsRefs})
        > {
  $$RoutineDaysTableTableManager(_$AppDatabase db, $RoutineDaysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$RoutineDaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$RoutineDaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$RoutineDaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> routineId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
          }) => RoutineDaysCompanion(id: id, routineId: routineId, name: name, sortOrder: sortOrder),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int routineId,
            required String name,
            Value<int> sortOrder = const Value.absent(),
          }) => RoutineDaysCompanion.insert(id: id, routineId: routineId, name: name, sortOrder: sortOrder),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable<$RoutineDaysTable, RoutineDay>(table), $$RoutineDaysTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({routineId = false, routineSetsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (routineSetsRefs) db.routineSets],
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
                    if (routineId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.routineId,
                        referencedTable: $$RoutineDaysTableReferences._routineIdTable(db),
                        referencedColumn: $$RoutineDaysTableReferences._routineIdTable(db).id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (routineSetsRefs)
                    await $_getPrefetchedData<RoutineDay, $RoutineDaysTable, RoutineSet>(
                      currentTable: table,
                      referencedTable: $$RoutineDaysTableReferences._routineSetsRefsTable(db),
                      managerFromTypedResult: (p0) => $$RoutineDaysTableReferences(db, table, p0).routineSetsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) => referencedItems.where((e) => e.dayId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$RoutineDaysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RoutineDaysTable,
      RoutineDay,
      $$RoutineDaysTableFilterComposer,
      $$RoutineDaysTableOrderingComposer,
      $$RoutineDaysTableAnnotationComposer,
      $$RoutineDaysTableCreateCompanionBuilder,
      $$RoutineDaysTableUpdateCompanionBuilder,
      (RoutineDay, $$RoutineDaysTableReferences),
      RoutineDay,
      PrefetchHooks Function({bool routineId, bool routineSetsRefs})
    >;
typedef $$RoutineSetsTableCreateCompanionBuilder = RoutineSetsCompanion Function({
  Value<int> id,
  required int dayId,
  required int exerciseId,
  Value<double?> rawWeight,
  Value<int?> reps,
  Value<double?> distance,
  Value<int?> durationSeconds,
  Value<int> sortOrder,
  Value<String?> groupName,
});
typedef $$RoutineSetsTableUpdateCompanionBuilder = RoutineSetsCompanion Function({
  Value<int> id,
  Value<int> dayId,
  Value<int> exerciseId,
  Value<double?> rawWeight,
  Value<int?> reps,
  Value<double?> distance,
  Value<int?> durationSeconds,
  Value<int> sortOrder,
  Value<String?> groupName,
});

final class $$RoutineSetsTableReferences extends BaseReferences<_$AppDatabase, $RoutineSetsTable, RoutineSet> {
  $$RoutineSetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RoutineDaysTable _dayIdTable(_$AppDatabase db) => db.routineDays.createAlias('routine_sets__day_id__routine_days__id');

  $$RoutineDaysTableProcessedTableManager get dayId {
    final $_column = $_itemColumn<int>('day_id')!;

    final manager = $$RoutineDaysTableTableManager($_db, $_db.routineDays).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_dayIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }

  static $ExercisesTable _exerciseIdTable(_$AppDatabase db) =>
      db.exercises.createAlias('routine_sets__exercise_id__exercises__id');

  $$ExercisesTableProcessedTableManager get exerciseId {
    final $_column = $_itemColumn<int>('exercise_id')!;

    final manager = $$ExercisesTableTableManager($_db, $_db.exercises).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_exerciseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$RoutineSetsTableFilterComposer extends Composer<_$AppDatabase, $RoutineSetsTable> {
  $$RoutineSetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get rawWeight => $composableBuilder(column: $table.rawWeight, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get reps => $composableBuilder(column: $table.reps, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get distance => $composableBuilder(column: $table.distance, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationSeconds =>
      $composableBuilder(column: $table.durationSeconds, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get groupName => $composableBuilder(column: $table.groupName, builder: (column) => ColumnFilters(column));

  $$RoutineDaysTableFilterComposer get dayId {
    final $$RoutineDaysTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.dayId,
      referencedTable: $db.routineDays,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RoutineDaysTableFilterComposer(
            $db: $db,
            $table: $db.routineDays,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExercisesTableFilterComposer get exerciseId {
    final $$ExercisesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ExercisesTableFilterComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RoutineSetsTableOrderingComposer extends Composer<_$AppDatabase, $RoutineSetsTable> {
  $$RoutineSetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get rawWeight =>
      $composableBuilder(column: $table.rawWeight, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get reps => $composableBuilder(column: $table.reps, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get distance =>
      $composableBuilder(column: $table.distance, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationSeconds =>
      $composableBuilder(column: $table.durationSeconds, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get groupName =>
      $composableBuilder(column: $table.groupName, builder: (column) => ColumnOrderings(column));

  $$RoutineDaysTableOrderingComposer get dayId {
    final $$RoutineDaysTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.dayId,
      referencedTable: $db.routineDays,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RoutineDaysTableOrderingComposer(
            $db: $db,
            $table: $db.routineDays,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExercisesTableOrderingComposer get exerciseId {
    final $$ExercisesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ExercisesTableOrderingComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RoutineSetsTableAnnotationComposer extends Composer<_$AppDatabase, $RoutineSetsTable> {
  $$RoutineSetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get rawWeight => $composableBuilder(column: $table.rawWeight, builder: (column) => column);

  GeneratedColumn<int> get reps => $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<double> get distance => $composableBuilder(column: $table.distance, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(column: $table.durationSeconds, builder: (column) => column);

  GeneratedColumn<int> get sortOrder => $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get groupName => $composableBuilder(column: $table.groupName, builder: (column) => column);

  $$RoutineDaysTableAnnotationComposer get dayId {
    final $$RoutineDaysTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.dayId,
      referencedTable: $db.routineDays,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RoutineDaysTableAnnotationComposer(
            $db: $db,
            $table: $db.routineDays,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExercisesTableAnnotationComposer get exerciseId {
    final $$ExercisesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ExercisesTableAnnotationComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RoutineSetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RoutineSetsTable,
          RoutineSet,
          $$RoutineSetsTableFilterComposer,
          $$RoutineSetsTableOrderingComposer,
          $$RoutineSetsTableAnnotationComposer,
          $$RoutineSetsTableCreateCompanionBuilder,
          $$RoutineSetsTableUpdateCompanionBuilder,
          (RoutineSet, $$RoutineSetsTableReferences),
          RoutineSet,
          PrefetchHooks Function({bool dayId, bool exerciseId})
        > {
  $$RoutineSetsTableTableManager(_$AppDatabase db, $RoutineSetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$RoutineSetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$RoutineSetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$RoutineSetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> dayId = const Value.absent(),
                Value<int> exerciseId = const Value.absent(),
                Value<double?> rawWeight = const Value.absent(),
                Value<int?> reps = const Value.absent(),
                Value<double?> distance = const Value.absent(),
                Value<int?> durationSeconds = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> groupName = const Value.absent(),
              }) => RoutineSetsCompanion(
                id: id,
                dayId: dayId,
                exerciseId: exerciseId,
                rawWeight: rawWeight,
                reps: reps,
                distance: distance,
                durationSeconds: durationSeconds,
                sortOrder: sortOrder,
                groupName: groupName,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int dayId,
                required int exerciseId,
                Value<double?> rawWeight = const Value.absent(),
                Value<int?> reps = const Value.absent(),
                Value<double?> distance = const Value.absent(),
                Value<int?> durationSeconds = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> groupName = const Value.absent(),
              }) => RoutineSetsCompanion.insert(
                id: id,
                dayId: dayId,
                exerciseId: exerciseId,
                rawWeight: rawWeight,
                reps: reps,
                distance: distance,
                durationSeconds: durationSeconds,
                sortOrder: sortOrder,
                groupName: groupName,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable<$RoutineSetsTable, RoutineSet>(table), $$RoutineSetsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({dayId = false, exerciseId = false}) {
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
                    if (dayId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.dayId,
                        referencedTable: $$RoutineSetsTableReferences._dayIdTable(db),
                        referencedColumn: $$RoutineSetsTableReferences._dayIdTable(db).id,
                      ) as T;
                    }
                    if (exerciseId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.exerciseId,
                        referencedTable: $$RoutineSetsTableReferences._exerciseIdTable(db),
                        referencedColumn: $$RoutineSetsTableReferences._exerciseIdTable(db).id,
                      ) as T;
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

typedef $$RoutineSetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RoutineSetsTable,
      RoutineSet,
      $$RoutineSetsTableFilterComposer,
      $$RoutineSetsTableOrderingComposer,
      $$RoutineSetsTableAnnotationComposer,
      $$RoutineSetsTableCreateCompanionBuilder,
      $$RoutineSetsTableUpdateCompanionBuilder,
      (RoutineSet, $$RoutineSetsTableReferences),
      RoutineSet,
      PrefetchHooks Function({bool dayId, bool exerciseId})
    >;
typedef $$MeasurementTypesTableCreateCompanionBuilder = MeasurementTypesCompanion Function({
  Value<int> id,
  required String name,
  required String unit,
});
typedef $$MeasurementTypesTableUpdateCompanionBuilder = MeasurementTypesCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> unit,
});

final class $$MeasurementTypesTableReferences extends BaseReferences<_$AppDatabase, $MeasurementTypesTable, MeasurementType> {
  $$MeasurementTypesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MeasurementsTable, List<Measurement>> _measurementsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.measurements, aliasName: 'measurement_types__id__measurements__type_id');

  $$MeasurementsTableProcessedTableManager get measurementsRefs {
    final manager = $$MeasurementsTableTableManager(
      $_db,
      $_db.measurements,
    ).filter((f) => f.typeId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_measurementsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$MeasurementTypesTableFilterComposer extends Composer<_$AppDatabase, $MeasurementTypesTable> {
  $$MeasurementTypesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get unit => $composableBuilder(column: $table.unit, builder: (column) => ColumnFilters(column));

  Expression<bool> measurementsRefs(Expression<bool> Function($$MeasurementsTableFilterComposer f) f) {
    final $$MeasurementsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.measurements,
      getReferencedColumn: (t) => t.typeId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$MeasurementsTableFilterComposer(
            $db: $db,
            $table: $db.measurements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MeasurementTypesTableOrderingComposer extends Composer<_$AppDatabase, $MeasurementTypesTable> {
  $$MeasurementTypesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get unit => $composableBuilder(column: $table.unit, builder: (column) => ColumnOrderings(column));
}

class $$MeasurementTypesTableAnnotationComposer extends Composer<_$AppDatabase, $MeasurementTypesTable> {
  $$MeasurementTypesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get unit => $composableBuilder(column: $table.unit, builder: (column) => column);

  Expression<T> measurementsRefs<T extends Object>(Expression<T> Function($$MeasurementsTableAnnotationComposer a) f) {
    final $$MeasurementsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.measurements,
      getReferencedColumn: (t) => t.typeId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$MeasurementsTableAnnotationComposer(
            $db: $db,
            $table: $db.measurements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MeasurementTypesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MeasurementTypesTable,
          MeasurementType,
          $$MeasurementTypesTableFilterComposer,
          $$MeasurementTypesTableOrderingComposer,
          $$MeasurementTypesTableAnnotationComposer,
          $$MeasurementTypesTableCreateCompanionBuilder,
          $$MeasurementTypesTableUpdateCompanionBuilder,
          (MeasurementType, $$MeasurementTypesTableReferences),
          MeasurementType,
          PrefetchHooks Function({bool measurementsRefs})
        > {
  $$MeasurementTypesTableTableManager(_$AppDatabase db, $MeasurementTypesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$MeasurementTypesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$MeasurementTypesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$MeasurementTypesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> unit = const Value.absent(),
          }) => MeasurementTypesCompanion(id: id, name: name, unit: unit),
          createCompanionCallback: ({Value<int> id = const Value.absent(), required String name, required String unit}) =>
              MeasurementTypesCompanion.insert(id: id, name: name, unit: unit),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MeasurementTypesTable, MeasurementType>(table),
                  $$MeasurementTypesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({measurementsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (measurementsRefs) db.measurements],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (measurementsRefs)
                    await $_getPrefetchedData<MeasurementType, $MeasurementTypesTable, Measurement>(
                      currentTable: table,
                      referencedTable: $$MeasurementTypesTableReferences._measurementsRefsTable(db),
                      managerFromTypedResult: (p0) => $$MeasurementTypesTableReferences(db, table, p0).measurementsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) => referencedItems.where((e) => e.typeId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$MeasurementTypesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MeasurementTypesTable,
      MeasurementType,
      $$MeasurementTypesTableFilterComposer,
      $$MeasurementTypesTableOrderingComposer,
      $$MeasurementTypesTableAnnotationComposer,
      $$MeasurementTypesTableCreateCompanionBuilder,
      $$MeasurementTypesTableUpdateCompanionBuilder,
      (MeasurementType, $$MeasurementTypesTableReferences),
      MeasurementType,
      PrefetchHooks Function({bool measurementsRefs})
    >;
typedef $$MeasurementsTableCreateCompanionBuilder = MeasurementsCompanion Function({
  Value<int> id,
  required int typeId,
  required String date,
  required double value,
  Value<String> note,
});
typedef $$MeasurementsTableUpdateCompanionBuilder = MeasurementsCompanion Function({
  Value<int> id,
  Value<int> typeId,
  Value<String> date,
  Value<double> value,
  Value<String> note,
});

final class $$MeasurementsTableReferences extends BaseReferences<_$AppDatabase, $MeasurementsTable, Measurement> {
  $$MeasurementsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MeasurementTypesTable _typeIdTable(_$AppDatabase db) =>
      db.measurementTypes.createAlias('measurements__type_id__measurement_types__id');

  $$MeasurementTypesTableProcessedTableManager get typeId {
    final $_column = $_itemColumn<int>('type_id')!;

    final manager = $$MeasurementTypesTableTableManager($_db, $_db.measurementTypes).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_typeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$MeasurementsTableFilterComposer extends Composer<_$AppDatabase, $MeasurementsTable> {
  $$MeasurementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get date => $composableBuilder(column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get value => $composableBuilder(column: $table.value, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(column: $table.note, builder: (column) => ColumnFilters(column));

  $$MeasurementTypesTableFilterComposer get typeId {
    final $$MeasurementTypesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.typeId,
      referencedTable: $db.measurementTypes,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$MeasurementTypesTableFilterComposer(
            $db: $db,
            $table: $db.measurementTypes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MeasurementsTableOrderingComposer extends Composer<_$AppDatabase, $MeasurementsTable> {
  $$MeasurementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get date => $composableBuilder(column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get value => $composableBuilder(column: $table.value, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(column: $table.note, builder: (column) => ColumnOrderings(column));

  $$MeasurementTypesTableOrderingComposer get typeId {
    final $$MeasurementTypesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.typeId,
      referencedTable: $db.measurementTypes,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$MeasurementTypesTableOrderingComposer(
            $db: $db,
            $table: $db.measurementTypes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MeasurementsTableAnnotationComposer extends Composer<_$AppDatabase, $MeasurementsTable> {
  $$MeasurementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get date => $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<double> get value => $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get note => $composableBuilder(column: $table.note, builder: (column) => column);

  $$MeasurementTypesTableAnnotationComposer get typeId {
    final $$MeasurementTypesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.typeId,
      referencedTable: $db.measurementTypes,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$MeasurementTypesTableAnnotationComposer(
            $db: $db,
            $table: $db.measurementTypes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MeasurementsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MeasurementsTable,
          Measurement,
          $$MeasurementsTableFilterComposer,
          $$MeasurementsTableOrderingComposer,
          $$MeasurementsTableAnnotationComposer,
          $$MeasurementsTableCreateCompanionBuilder,
          $$MeasurementsTableUpdateCompanionBuilder,
          (Measurement, $$MeasurementsTableReferences),
          Measurement,
          PrefetchHooks Function({bool typeId})
        > {
  $$MeasurementsTableTableManager(_$AppDatabase db, $MeasurementsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$MeasurementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$MeasurementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$MeasurementsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> typeId = const Value.absent(),
            Value<String> date = const Value.absent(),
            Value<double> value = const Value.absent(),
            Value<String> note = const Value.absent(),
          }) => MeasurementsCompanion(id: id, typeId: typeId, date: date, value: value, note: note),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int typeId,
            required String date,
            required double value,
            Value<String> note = const Value.absent(),
          }) => MeasurementsCompanion.insert(id: id, typeId: typeId, date: date, value: value, note: note),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable<$MeasurementsTable, Measurement>(table), $$MeasurementsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({typeId = false}) {
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
                    if (typeId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.typeId,
                        referencedTable: $$MeasurementsTableReferences._typeIdTable(db),
                        referencedColumn: $$MeasurementsTableReferences._typeIdTable(db).id,
                      ) as T;
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

typedef $$MeasurementsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MeasurementsTable,
      Measurement,
      $$MeasurementsTableFilterComposer,
      $$MeasurementsTableOrderingComposer,
      $$MeasurementsTableAnnotationComposer,
      $$MeasurementsTableCreateCompanionBuilder,
      $$MeasurementsTableUpdateCompanionBuilder,
      (Measurement, $$MeasurementsTableReferences),
      Measurement,
      PrefetchHooks Function({bool typeId})
    >;
typedef $$ExerciseGoalsTableCreateCompanionBuilder = ExerciseGoalsCompanion Function({
  Value<int> id,
  required int exerciseId,
  required String metric,
  required double target,
  Value<String?> targetDate,
});
typedef $$ExerciseGoalsTableUpdateCompanionBuilder = ExerciseGoalsCompanion Function({
  Value<int> id,
  Value<int> exerciseId,
  Value<String> metric,
  Value<double> target,
  Value<String?> targetDate,
});

final class $$ExerciseGoalsTableReferences extends BaseReferences<_$AppDatabase, $ExerciseGoalsTable, ExerciseGoal> {
  $$ExerciseGoalsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ExercisesTable _exerciseIdTable(_$AppDatabase db) =>
      db.exercises.createAlias('exercise_goals__exercise_id__exercises__id');

  $$ExercisesTableProcessedTableManager get exerciseId {
    final $_column = $_itemColumn<int>('exercise_id')!;

    final manager = $$ExercisesTableTableManager($_db, $_db.exercises).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_exerciseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ExerciseGoalsTableFilterComposer extends Composer<_$AppDatabase, $ExerciseGoalsTable> {
  $$ExerciseGoalsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get metric => $composableBuilder(column: $table.metric, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get target => $composableBuilder(column: $table.target, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get targetDate =>
      $composableBuilder(column: $table.targetDate, builder: (column) => ColumnFilters(column));

  $$ExercisesTableFilterComposer get exerciseId {
    final $$ExercisesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ExercisesTableFilterComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExerciseGoalsTableOrderingComposer extends Composer<_$AppDatabase, $ExerciseGoalsTable> {
  $$ExerciseGoalsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get metric => $composableBuilder(column: $table.metric, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get target => $composableBuilder(column: $table.target, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get targetDate =>
      $composableBuilder(column: $table.targetDate, builder: (column) => ColumnOrderings(column));

  $$ExercisesTableOrderingComposer get exerciseId {
    final $$ExercisesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ExercisesTableOrderingComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExerciseGoalsTableAnnotationComposer extends Composer<_$AppDatabase, $ExerciseGoalsTable> {
  $$ExerciseGoalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get metric => $composableBuilder(column: $table.metric, builder: (column) => column);

  GeneratedColumn<double> get target => $composableBuilder(column: $table.target, builder: (column) => column);

  GeneratedColumn<String> get targetDate => $composableBuilder(column: $table.targetDate, builder: (column) => column);

  $$ExercisesTableAnnotationComposer get exerciseId {
    final $$ExercisesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ExercisesTableAnnotationComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExerciseGoalsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExerciseGoalsTable,
          ExerciseGoal,
          $$ExerciseGoalsTableFilterComposer,
          $$ExerciseGoalsTableOrderingComposer,
          $$ExerciseGoalsTableAnnotationComposer,
          $$ExerciseGoalsTableCreateCompanionBuilder,
          $$ExerciseGoalsTableUpdateCompanionBuilder,
          (ExerciseGoal, $$ExerciseGoalsTableReferences),
          ExerciseGoal,
          PrefetchHooks Function({bool exerciseId})
        > {
  $$ExerciseGoalsTableTableManager(_$AppDatabase db, $ExerciseGoalsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$ExerciseGoalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$ExerciseGoalsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$ExerciseGoalsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> exerciseId = const Value.absent(),
            Value<String> metric = const Value.absent(),
            Value<double> target = const Value.absent(),
            Value<String?> targetDate = const Value.absent(),
          }) => ExerciseGoalsCompanion(id: id, exerciseId: exerciseId, metric: metric, target: target, targetDate: targetDate),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int exerciseId,
                required String metric,
                required double target,
                Value<String?> targetDate = const Value.absent(),
              }) => ExerciseGoalsCompanion.insert(
                id: id,
                exerciseId: exerciseId,
                metric: metric,
                target: target,
                targetDate: targetDate,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable<$ExerciseGoalsTable, ExerciseGoal>(table), $$ExerciseGoalsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({exerciseId = false}) {
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
                    if (exerciseId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.exerciseId,
                        referencedTable: $$ExerciseGoalsTableReferences._exerciseIdTable(db),
                        referencedColumn: $$ExerciseGoalsTableReferences._exerciseIdTable(db).id,
                      ) as T;
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

typedef $$ExerciseGoalsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExerciseGoalsTable,
      ExerciseGoal,
      $$ExerciseGoalsTableFilterComposer,
      $$ExerciseGoalsTableOrderingComposer,
      $$ExerciseGoalsTableAnnotationComposer,
      $$ExerciseGoalsTableCreateCompanionBuilder,
      $$ExerciseGoalsTableUpdateCompanionBuilder,
      (ExerciseGoal, $$ExerciseGoalsTableReferences),
      ExerciseGoal,
      PrefetchHooks Function({bool exerciseId})
    >;
typedef $$WorkoutSessionsTableCreateCompanionBuilder = WorkoutSessionsCompanion Function({
  required String date,
  required DateTime startedAt,
  Value<DateTime?> endedAt,
  Value<int> elapsedSeconds,
  Value<DateTime?> runningSince,
  Value<int> rowid,
});
typedef $$WorkoutSessionsTableUpdateCompanionBuilder = WorkoutSessionsCompanion Function({
  Value<String> date,
  Value<DateTime> startedAt,
  Value<DateTime?> endedAt,
  Value<int> elapsedSeconds,
  Value<DateTime?> runningSince,
  Value<int> rowid,
});

class $$WorkoutSessionsTableFilterComposer extends Composer<_$AppDatabase, $WorkoutSessionsTable> {
  $$WorkoutSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get date => $composableBuilder(column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get endedAt => $composableBuilder(column: $table.endedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get elapsedSeconds =>
      $composableBuilder(column: $table.elapsedSeconds, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get runningSince =>
      $composableBuilder(column: $table.runningSince, builder: (column) => ColumnFilters(column));
}

class $$WorkoutSessionsTableOrderingComposer extends Composer<_$AppDatabase, $WorkoutSessionsTable> {
  $$WorkoutSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get date => $composableBuilder(column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get elapsedSeconds =>
      $composableBuilder(column: $table.elapsedSeconds, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get runningSince =>
      $composableBuilder(column: $table.runningSince, builder: (column) => ColumnOrderings(column));
}

class $$WorkoutSessionsTableAnnotationComposer extends Composer<_$AppDatabase, $WorkoutSessionsTable> {
  $$WorkoutSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get date => $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt => $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt => $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<int> get elapsedSeconds => $composableBuilder(column: $table.elapsedSeconds, builder: (column) => column);

  GeneratedColumn<DateTime> get runningSince => $composableBuilder(column: $table.runningSince, builder: (column) => column);
}

class $$WorkoutSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkoutSessionsTable,
          WorkoutSession,
          $$WorkoutSessionsTableFilterComposer,
          $$WorkoutSessionsTableOrderingComposer,
          $$WorkoutSessionsTableAnnotationComposer,
          $$WorkoutSessionsTableCreateCompanionBuilder,
          $$WorkoutSessionsTableUpdateCompanionBuilder,
          (WorkoutSession, BaseReferences<_$AppDatabase, $WorkoutSessionsTable, WorkoutSession>),
          WorkoutSession,
          PrefetchHooks Function()
        > {
  $$WorkoutSessionsTableTableManager(_$AppDatabase db, $WorkoutSessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$WorkoutSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$WorkoutSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$WorkoutSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> date = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int> elapsedSeconds = const Value.absent(),
                Value<DateTime?> runningSince = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkoutSessionsCompanion(
                date: date,
                startedAt: startedAt,
                endedAt: endedAt,
                elapsedSeconds: elapsedSeconds,
                runningSince: runningSince,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String date,
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int> elapsedSeconds = const Value.absent(),
                Value<DateTime?> runningSince = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkoutSessionsCompanion.insert(
                date: date,
                startedAt: startedAt,
                endedAt: endedAt,
                elapsedSeconds: elapsedSeconds,
                runningSince: runningSince,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WorkoutSessionsTable, WorkoutSession>(table),
                  BaseReferences<_$AppDatabase, $WorkoutSessionsTable, WorkoutSession>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WorkoutSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkoutSessionsTable,
      WorkoutSession,
      $$WorkoutSessionsTableFilterComposer,
      $$WorkoutSessionsTableOrderingComposer,
      $$WorkoutSessionsTableAnnotationComposer,
      $$WorkoutSessionsTableCreateCompanionBuilder,
      $$WorkoutSessionsTableUpdateCompanionBuilder,
      (WorkoutSession, BaseReferences<_$AppDatabase, $WorkoutSessionsTable, WorkoutSession>),
      WorkoutSession,
      PrefetchHooks Function()
    >;
typedef $$WorkoutExerciseOrdersTableCreateCompanionBuilder = WorkoutExerciseOrdersCompanion Function({
  required String date,
  required int exerciseId,
  required int sortOrder,
  Value<int> rowid,
});
typedef $$WorkoutExerciseOrdersTableUpdateCompanionBuilder = WorkoutExerciseOrdersCompanion Function({
  Value<String> date,
  Value<int> exerciseId,
  Value<int> sortOrder,
  Value<int> rowid,
});

final class $$WorkoutExerciseOrdersTableReferences
    extends BaseReferences<_$AppDatabase, $WorkoutExerciseOrdersTable, WorkoutExerciseOrder> {
  $$WorkoutExerciseOrdersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ExercisesTable _exerciseIdTable(_$AppDatabase db) =>
      db.exercises.createAlias('workout_exercise_orders__exercise_id__exercises__id');

  $$ExercisesTableProcessedTableManager get exerciseId {
    final $_column = $_itemColumn<int>('exercise_id')!;

    final manager = $$ExercisesTableTableManager($_db, $_db.exercises).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_exerciseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$WorkoutExerciseOrdersTableFilterComposer extends Composer<_$AppDatabase, $WorkoutExerciseOrdersTable> {
  $$WorkoutExerciseOrdersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get date => $composableBuilder(column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  $$ExercisesTableFilterComposer get exerciseId {
    final $$ExercisesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ExercisesTableFilterComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkoutExerciseOrdersTableOrderingComposer extends Composer<_$AppDatabase, $WorkoutExerciseOrdersTable> {
  $$WorkoutExerciseOrdersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get date => $composableBuilder(column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  $$ExercisesTableOrderingComposer get exerciseId {
    final $$ExercisesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ExercisesTableOrderingComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkoutExerciseOrdersTableAnnotationComposer extends Composer<_$AppDatabase, $WorkoutExerciseOrdersTable> {
  $$WorkoutExerciseOrdersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get date => $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get sortOrder => $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$ExercisesTableAnnotationComposer get exerciseId {
    final $$ExercisesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$ExercisesTableAnnotationComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkoutExerciseOrdersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkoutExerciseOrdersTable,
          WorkoutExerciseOrder,
          $$WorkoutExerciseOrdersTableFilterComposer,
          $$WorkoutExerciseOrdersTableOrderingComposer,
          $$WorkoutExerciseOrdersTableAnnotationComposer,
          $$WorkoutExerciseOrdersTableCreateCompanionBuilder,
          $$WorkoutExerciseOrdersTableUpdateCompanionBuilder,
          (WorkoutExerciseOrder, $$WorkoutExerciseOrdersTableReferences),
          WorkoutExerciseOrder,
          PrefetchHooks Function({bool exerciseId})
        > {
  $$WorkoutExerciseOrdersTableTableManager(_$AppDatabase db, $WorkoutExerciseOrdersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$WorkoutExerciseOrdersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$WorkoutExerciseOrdersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$WorkoutExerciseOrdersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> date = const Value.absent(),
            Value<int> exerciseId = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => WorkoutExerciseOrdersCompanion(date: date, exerciseId: exerciseId, sortOrder: sortOrder, rowid: rowid),
          createCompanionCallback: ({
            required String date,
            required int exerciseId,
            required int sortOrder,
            Value<int> rowid = const Value.absent(),
          }) => WorkoutExerciseOrdersCompanion.insert(date: date, exerciseId: exerciseId, sortOrder: sortOrder, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WorkoutExerciseOrdersTable, WorkoutExerciseOrder>(table),
                  $$WorkoutExerciseOrdersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({exerciseId = false}) {
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
                    if (exerciseId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.exerciseId,
                        referencedTable: $$WorkoutExerciseOrdersTableReferences._exerciseIdTable(db),
                        referencedColumn: $$WorkoutExerciseOrdersTableReferences._exerciseIdTable(db).id,
                      ) as T;
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

typedef $$WorkoutExerciseOrdersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkoutExerciseOrdersTable,
      WorkoutExerciseOrder,
      $$WorkoutExerciseOrdersTableFilterComposer,
      $$WorkoutExerciseOrdersTableOrderingComposer,
      $$WorkoutExerciseOrdersTableAnnotationComposer,
      $$WorkoutExerciseOrdersTableCreateCompanionBuilder,
      $$WorkoutExerciseOrdersTableUpdateCompanionBuilder,
      (WorkoutExerciseOrder, $$WorkoutExerciseOrdersTableReferences),
      WorkoutExerciseOrder,
      PrefetchHooks Function({bool exerciseId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CategoriesTableTableManager get categories => $$CategoriesTableTableManager(_db, _db.categories);
  $$ExercisesTableTableManager get exercises => $$ExercisesTableTableManager(_db, _db.exercises);
  $$ExerciseMultipliersTableTableManager get exerciseMultipliers =>
      $$ExerciseMultipliersTableTableManager(_db, _db.exerciseMultipliers);
  $$WorkoutSetsTableTableManager get workoutSets => $$WorkoutSetsTableTableManager(_db, _db.workoutSets);
  $$WorkoutDayNotesTableTableManager get workoutDayNotes => $$WorkoutDayNotesTableTableManager(_db, _db.workoutDayNotes);
  $$PrResetMarkersTableTableManager get prResetMarkers => $$PrResetMarkersTableTableManager(_db, _db.prResetMarkers);
  $$AppSettingsTableTableManager get appSettings => $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$RoutinesTableTableManager get routines => $$RoutinesTableTableManager(_db, _db.routines);
  $$RoutineDaysTableTableManager get routineDays => $$RoutineDaysTableTableManager(_db, _db.routineDays);
  $$RoutineSetsTableTableManager get routineSets => $$RoutineSetsTableTableManager(_db, _db.routineSets);
  $$MeasurementTypesTableTableManager get measurementTypes => $$MeasurementTypesTableTableManager(_db, _db.measurementTypes);
  $$MeasurementsTableTableManager get measurements => $$MeasurementsTableTableManager(_db, _db.measurements);
  $$ExerciseGoalsTableTableManager get exerciseGoals => $$ExerciseGoalsTableTableManager(_db, _db.exerciseGoals);
  $$WorkoutSessionsTableTableManager get workoutSessions => $$WorkoutSessionsTableTableManager(_db, _db.workoutSessions);
  $$WorkoutExerciseOrdersTableTableManager get workoutExerciseOrders =>
      $$WorkoutExerciseOrdersTableTableManager(_db, _db.workoutExerciseOrders);
}
