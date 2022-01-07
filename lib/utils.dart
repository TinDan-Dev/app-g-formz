import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:code_builder/code_builder.dart';

bool _isCoreDartType(Element? element) {
  return element?.source?.fullName == 'dart:core';
}

String? resolveImport(List<LibraryElement> libraries, Element? element) {
  // return early if source is null or element is a core type
  if (element?.source == null || _isCoreDartType(element)) {
    return null;
  }

  for (final lib in libraries) {
    if (!_isCoreDartType(lib) && lib.exportNamespace.definedNames.values.contains(element)) {
      return lib.identifier;
    }
  }

  return null;
}

Iterable<TypeReference> _resolveTypeArguments(List<LibraryElement> libraries, DartType type) sync* {
  if (type is! ParameterizedType) {
    return;
  }

  for (final argumentType in type.typeArguments) {
    yield resolveDartType(libraries, argumentType);
  }
}

int resolveDartTypeToId(List<LibraryElement> libraries, DartType type, {bool nullable = false}) {
  final symbol = resolveDartTypeName(type);
  final url = resolveImport(libraries, type.element);

  return Object.hash(symbol, url, nullable);
}

String resolveDartTypeName(DartType type) => type.element?.name ?? type.getDisplayString(withNullability: false);

TypeReference resolveDartType(List<LibraryElement> libraries, DartType type, {bool nullable = false}) {
  return TypeReference((builder) => builder
    ..symbol = resolveDartTypeName(type)
    ..url = resolveImport(libraries, type.element)
    ..types.addAll(_resolveTypeArguments(libraries, type))
    ..isNullable = nullable);
}

TypeReference setNullable(TypeReference reference, {required bool nullable}) {
  return TypeReference((builder) => builder
    ..symbol = reference.symbol
    ..url = reference.url
    ..types.addAll(reference.types)
    ..isNullable = nullable);
}

TypeReference resolveFunctionType(
  List<LibraryElement> libraries,
  ExecutableElement executableElement, {
  bool nullable = false,
}) {
  String displayName = executableElement.displayName;
  Element elementToImport = executableElement;

  final enclosingElement = executableElement.enclosingElement;
  if (enclosingElement is ClassElement) {
    displayName = '${enclosingElement.displayName}.$displayName';
    elementToImport = enclosingElement;
  }

  return TypeReference((builder) => builder
    ..symbol = displayName
    ..url = resolveImport(libraries, elementToImport)
    ..isNullable = nullable);
}
