import 'dart:math';

import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';

import 'writer/converter.dart';

bool _nullableAssignable(LType to, LType from) {
  if (to.nullable) {
    return true;
  }

  return !from.nullable;
}

class LType {
  static bool isExactly(LType a, LType b) => a.type.element == b.type.element;

  static bool assignable(LType to, LType from, {bool nullability = false}) {
    final toDartType = to.type;
    final fromDartType = from.type;

    if (toDartType is! InterfaceType || fromDartType is! InterfaceType) {
      if (!isExactly(to, from)) {
        return false;
      } else {
        return _nullableAssignable(to, from) || !nullability;
      }
    }

    final matchingType = [
      fromDartType,
      ...fromDartType.allSupertypes,
    ].firstWhereOrNull((e) => toDartType.element == e.element);

    if (matchingType == null) {
      return false;
    }

    if (!_nullableAssignable(to, from) && nullability) {
      return false;
    }

    for (int i = 0; i < min(to.typeArguments.length, from.typeArguments.length); i++) {
      final toArgument = to.typeArguments[i];
      final fromArgument = from.typeArguments[i];

      if (!assignable(toArgument, fromArgument, nullability: true)) {
        return false;
      }
    }

    return true;
  }

  static bool _getNullability(DartType type, bool? nullable) {
    if (nullable != null) {
      return nullable;
    } else {
      return type.nullabilitySuffix == NullabilitySuffix.question;
    }
  }

  static List<LType> _getTypeParameter(DartType type, List<LType>? typeArguments) {
    if (typeArguments != null) {
      return typeArguments;
    }

    if (type is ParameterizedType) {
      return type.typeArguments.map((e) => LType(e)).toList();
    } else {
      return const [];
    }
  }

  final DartType type;
  final bool nullable;
  final List<LType> typeArguments;

  LType(this.type, {bool? nullable, List<LType>? typeArguments})
      : nullable = _getNullability(type, nullable),
        typeArguments = _getTypeParameter(type, typeArguments);

  LType get notNullable {
    if (!nullable) {
      return this;
    } else {
      return LType(type, nullable: false, typeArguments: typeArguments);
    }
  }

  LType setNotNullableTypeArgument(int index) {
    final args = List.of(typeArguments);
    args[index] = args[index].notNullable;

    return LType(type, nullable: nullable, typeArguments: args);
  }

  @override
  String toString() {
    return type.toString();
  }
}

class LParameter {
  final String name;
  final LType type;

  ArgumentConverter? converter;

  LParameter(this.name, this.type);
}
