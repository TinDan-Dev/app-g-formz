import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:collection/collection.dart';

import 'imports.dart';

bool _isCoreDartType(Element? element) {
  return element?.source?.fullName == 'dart:core';
}

String _resolveDartTypeName(DartType type) => type.element?.name ?? type.getDisplayString(withNullability: false);

class LibraryContext {
  static Future<LibraryContext> fromBuildStep(BuildStep step) async {
    return LibraryContext(
      await step.resolver.libraries.toList(),
      await step.inputLibrary,
    );
  }

  final List<LibraryElement> allLibraries;
  final LibraryElement? sourceLibrary;

  LibraryContext(this.allLibraries, this.sourceLibrary);

  /// Finds the library identifier for an element, if the element can be found
  /// and is not a core type.
  String? _resolveImport(Element? element) {
    if (element?.source == null || _isCoreDartType(element)) {
      return null;
    }

    for (final lib in allLibraries) {
      if (!_isCoreDartType(lib) && lib.exportNamespace.definedNames.values.contains(element)) {
        return lib.identifier;
      }
    }

    return null;
  }

  /// Resolves the import prefix for an element, if the source lib is not null.
  String? _resolveDartTypePrefix(Element? element) {
    final lib = sourceLibrary;

    if (element == null || lib == null || element.source == null || _isCoreDartType(element)) {
      return null;
    }

    final owner = lib.prefixes.firstWhereOrNull(
      (e) {
        final librariesForPrefix = e.library.getImportsWithPrefix(e);

        return librariesForPrefix.any((l) {
          return l.importedLibrary!.anyTransitiveExport((library) {
            return library.id == element.library?.id;
          });
        });
      },
    );

    return owner?.name;
  }

  /// Iterates over all type arguments and resolves their types.
  Iterable<TypeReference> _resolveTypeArguments(DartType type) sync* {
    if (type is! ParameterizedType) {
      return;
    }

    for (final argumentType in type.typeArguments) {
      yield resolveDartType(argumentType);
    }
  }

  /// Creates a unique hash for every dart type.
  int resolveDartTypeToId(DartType type) {
    final symbol = _resolveDartTypeName(type);
    final url = _resolveImport(type.element);

    return Object.hash(symbol, url);
  }

  /// Resolves a dart type.
  ///
  /// Sets the symbol to the name with import prefix, if necessary. Also the
  /// library url is resolved and all type parameters are resolved.
  TypeReference resolveDartType(DartType type) {
    final prefix = _resolveDartTypePrefix(type.element);
    final name = _resolveDartTypeName(type);

    return TypeReference((builder) => builder
      ..symbol = prefix == null ? name : '$prefix.$name'
      ..url = _resolveImport(type.element)
      ..types.addAll(_resolveTypeArguments(type))
      ..isNullable = type.nullabilitySuffix == NullabilitySuffix.question);
  }

  /// Resolves a function type.
  TypeReference resolveFunctionType(
    LibraryContext ctx,
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
      ..url = _resolveImport(elementToImport)
      ..isNullable = nullable);
  }
}

TypeReference setNullable(TypeReference reference, {required bool nullable}) {
  return TypeReference((builder) => builder
    ..symbol = reference.symbol
    ..url = reference.url
    ..types.addAll(reference.types)
    ..isNullable = nullable);
}

AstNode? getAstNodeFromElement(Element? element) {
  if (element == null) return null;

  final session = element.session;
  final library = element.library;
  if (session == null || library == null) return null;

  final parsedLibResult = session.getParsedLibraryByElement(library);
  if (parsedLibResult is! ParsedLibraryResult) return null;
  return parsedLibResult.getElementDeclaration(element)?.node;
}
