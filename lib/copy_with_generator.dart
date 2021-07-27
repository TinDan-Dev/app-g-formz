import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/visitor.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:formz/annotation.dart';
import 'package:source_gen/source_gen.dart';

Builder copyWithGeneratorBuilder(BuilderOptions options) => SharedPartBuilder([CopyWithGenerator()], 'copy_with');

String compileGenericTypes(List<String> types) {
  final buffer = StringBuffer();

  if (types.isNotEmpty) {
    buffer.write('<');

    for (int i = 0; i < types.length; i++) {
      buffer.write(types[i]);

      if (i < types.length - 1) buffer.write(',');
    }

    buffer.write('>');
  }

  return buffer.toString();
}

String getGenericTypesWithConstrains(ClassElement element) {
  final types = element.typeParameters.map((e) => e.getDisplayString(withNullability: true)).toList();
  return compileGenericTypes(types);
}

String getGenericTypes(ClassElement element) {
  final types = element.typeParameters.map((e) => e.name).toList();
  return compileGenericTypes(types);
}

String getGenericTypesOfAlias(TypeAliasElement element) {
  final types = element.typeParameters.map((e) => e.name).toList();
  return compileGenericTypes(types);
}

class CopyWithGenerator extends GeneratorForAnnotation<WithCopy> {
  final emitter = DartEmitter();

  @override
  FutureOr<String> generateForAnnotatedElement(Element element, ConstantReader annotation, BuildStep buildStep) {
    final visitor = _ModelVisitor();
    element.visitChildren(visitor);

    if (element is! ClassElement) throw UnsupportedError('only classes are supported');
    final genericTypesWithConstrains = getGenericTypesWithConstrains(element);
    final genericTypes = getGenericTypes(element);

    final extension = Extension((eBuilder) {
      eBuilder.name = '${element.name}CopyExtension$genericTypesWithConstrains';
      eBuilder.on = refer('${element.name}$genericTypes');

      eBuilder.methods.add(Method((mBuilder) {
        mBuilder.name = 'copyWith';
        mBuilder.returns = refer('${element.name}$genericTypes');
        mBuilder.lambda = true;

        for (final entry in visitor.fields.entries) {
          mBuilder.optionalParameters.add(Parameter((pBuilder) {
            pBuilder.name = entry.key;
            pBuilder.type = refer('SupplyFunc<${entry.value}>?');
            pBuilder.named = true;
          }));
        }

        final methodBuffer = StringBuffer();
        methodBuffer.write('${element.name}(');

        for (final entry in visitor.fields.entries) {
          final name = entry.key;

          methodBuffer.write('$name: $name == null ? this.$name : $name(), ');
        }

        methodBuffer.write(')');
        mBuilder.body = Code(methodBuffer.toString());
      }));
    });

    return '${extension.accept(emitter)}';
  }
}

class _ModelVisitor extends SimpleElementVisitor {
  Map<String, String> fields = {};

  String parseParam(DartType type, List<TypeParameterElement> params) {
    final alias = type.aliasElement;
    if (alias != null) {
      final genericTypeStr = getGenericTypesOfAlias(alias);

      return alias.name + genericTypeStr;
    } else {
      return type.getDisplayString(withNullability: true);
    }
  }

  @override
  void visitConstructorElement(ConstructorElement element) {
    if (element.name.isNotEmpty) return;

    for (final param in element.parameters) fields[param.name] = parseParam(param.type, param.typeParameters);
  }
}
