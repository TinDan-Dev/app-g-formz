part of 'types.dart';

bool _nullableAssignable(LType to, LType from) {
  if (to.nullable) {
    return true;
  }

  return !from.nullable;
}

bool _sameType(LType a, LType b) => a.name == b.name && a.url == b.url;

bool _assignable(LType to, LType from, bool nullability) {
  if (_sameType(to, LType.dynamic) || _sameType(from, LType.dynamic)) return true;

  final matchingType = [from, ...from.allSupertypes].firstWhereOrNull((e) => _sameType(to, e));
  if (matchingType == null) {
    return false;
  }

  if (!_nullableAssignable(to, from) && nullability) {
    return false;
  }

  for (int i = 0; i < min(to.typeArguments.length, from.typeArguments.length); i++) {
    final toArgument = to.typeArguments[i];
    final fromArgument = from.typeArguments[i];

    if (!_assignable(toArgument, fromArgument, true)) {
      return false;
    }
  }

  return true;
}

T applyCW<T>(T value, T fun()?) {
  if (fun != null) {
    return fun();
  } else {
    return value;
  }
}

class LType {
  static bool sameType(LType a, LType b) => a.name == b.name && a.url == b.url;

  static bool assignable(LType to, LType from, {bool nullability = false}) => _assignable(to, from, nullability);

  static const dynamic = LType(name: 'dynamic', url: 'dart:dynamic');

  final bool nullable;
  final List<LType> typeArguments;
  final List<LType> allSupertypes;

  final String? prefix;
  final String? url;

  final String name;

  const LType({
    required this.name,
    this.nullable = false,
    this.typeArguments = const [],
    this.allSupertypes = const [],
    this.prefix = null,
    this.url = null,
  });

  LType copyWith({
    bool Function()? nullable,
    List<LType> Function()? typeArguments,
    List<LType> Function()? allSupertypes,
    String? Function()? prefix,
    String? Function()? url,
    String Function()? name,
  }) =>
      LType(
        nullable: applyCW(this.nullable, nullable),
        typeArguments: applyCW(this.typeArguments, typeArguments),
        allSupertypes: applyCW(this.allSupertypes, allSupertypes),
        prefix: applyCW(this.prefix, prefix),
        url: applyCW(this.url, url),
        name: applyCW(this.name, name),
      );

  Reference get ref => TypeReference((builder) => builder
    ..symbol = prefix == null ? name : '$prefix.$name'
    ..url = url
    ..types.addAll(typeArguments.map((e) => e.ref))
    ..isNullable = nullable);

  @override
  String toString() {
    final buf = StringBuffer();

    if (prefix != null) {
      buf.write(prefix);
      buf.write('.');
    }
    buf.write(name);

    if (typeArguments.isNotEmpty) {
      buf.write('<');
      buf.write(typeArguments.join(', '));
      buf.write('>');
    }

    if (nullable) {
      buf.write('?');
    }

    return buf.toString();
  }
}
