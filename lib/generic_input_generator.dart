import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:formz/annotation.dart';
import 'package:source_gen/source_gen.dart';

import 'utils.dart';

Builder genericInputGeneratorBuilder(BuilderOptions options) =>
    SharedPartBuilder([GenericInputGenerator()], 'generic_input');

class _OptionalInput {
  final bool isOptional;
  final bool generateOnlyOptional;

  _OptionalInput({
    required this.isOptional,
    required this.generateOnlyOptional,
  });
}

class GenericInputGenerator extends GeneratorForAnnotation<GenGenericInput> {
  static const optionalInputChecker = TypeChecker.fromRuntime(OptionalInput);
  static const formzUrl = 'package:formz/formz.dart';

  final emitter = DartEmitter(useNullSafetySyntax: true);

  @override
  Future<String> generateForAnnotatedElement(Element element, ConstantReader annotation, BuildStep buildStep) async {
    final libraries = await buildStep.resolver.libraries.toList();

    if (element is! ClassElement) throw UnsupportedError('the annotation target should be a class');
    _isValidClass(element);

    final optional = getOptionalProperties(element);
    final name = element.name;
    final inputName = element.name.replaceAll('CriteriaCollection', '');
    final docs = element.documentationComment;
    final type = resolveDartType(libraries, element.allSupertypes[0].typeArguments[0]);

    final classBuffer = StringBuffer();

    if (optional.isOptional) {
      classBuffer.writeln(buildClass(
        inputName: 'Optional$inputName',
        name: name,
        type: type,
        optional: true,
        docs: docs,
      ).accept(emitter));

      if (!optional.generateOnlyOptional)
        classBuffer.writeln(buildClass(
          inputName: inputName,
          name: name,
          type: type,
          optional: false,
          docs: docs,
        ).accept(emitter));
    } else {
      classBuffer.writeln(buildClass(
        inputName: inputName,
        name: name,
        type: type,
        optional: false,
        docs: docs,
      ).accept(emitter));
    }

    return classBuffer.toString();
  }

  Class buildClass({
    required String inputName,
    required String name,
    required TypeReference type,
    required bool optional,
    String? docs,
  }) {
    return Class((builder) {
      builder.name = inputName;

      builder.docs.add('/// ${optional ? 'Optional ' : ''}Input implementation for "$inputName" criteria collection.');
      if (docs != null) {
        builder.docs.add('/// ');
        builder.docs.add(docs);
      }

      if (optional) builder.mixins.add(refer('OptionalInputMixin'));

      builder.extend = TypeReference((builder) => builder
        ..symbol = 'GenericInput'
        ..url = formzUrl
        ..types.add(type));

      // create static field
      builder.fields.add(Field((fBuilder) => fBuilder
        ..name = '_collection'
        ..static = true
        ..modifier = FieldModifier.final$
        ..assignment = Code('$name()')));

      // create constr
      builder.constructors.add(Constructor((cBuilder) => buildConstr(cBuilder, 'pure', type)));
      builder.constructors.add(Constructor((cBuilder) => buildConstr(cBuilder, 'dirty', type)));

      // add isPure override
      if (optional)
        builder.methods.add(Method((mBuilder) => mBuilder
          ..name = 'isPure'
          ..requiredParameters.add(Parameter((pBuilder) => pBuilder
            ..name = 'value'
            ..type = refer('String?')))
          ..returns = refer('bool')
          ..annotations.add(refer('override'))
          ..lambda = true
          ..body = const Code('_collection.isPure(value)')));

      // add getCollection method
      builder.methods.add(Method((mBuilder) => mBuilder
        ..name = 'getCollection'
        ..annotations.add(refer('override'))
        ..returns = TypeReference((builder) => builder
          ..symbol = 'GenericCriteriaCollection'
          ..url = formzUrl
          ..types.add(type))
        ..lambda = true
        ..body = const Code('_collection')));

      // add copyWith
      final bodyBuffer = StringBuffer();
      bodyBuffer.writeln('if (pure)');
      bodyBuffer.writeln('return $inputName.pure(value, name: name);');
      bodyBuffer.writeln('else');
      bodyBuffer.writeln('return $inputName.dirty(value, name: name);');

      builder.methods.add(Method((mBuilder) => mBuilder
        ..name = 'copyWith'
        ..annotations.add(refer('override'))
        ..optionalParameters.add(Parameter((pBuilder) => pBuilder
          ..name = 'value'
          ..type = setNullable(type, nullable: true)
          ..named = true
          ..required = true))
        ..optionalParameters.add(Parameter((pBuilder) => pBuilder
          ..name = 'pure'
          ..type = refer('bool')
          ..named = true
          ..defaultTo = const Code('false')))
        ..returns = TypeReference((builder) => builder
          ..symbol = 'Input'
          ..url = formzUrl
          ..types.addAll([
            type,
            TypeReference((builder) => builder
              ..symbol = 'GenericInputError'
              ..url = formzUrl),
          ]))
        ..body = Code(bodyBuffer.toString())));
    });
  }

  void _isValidClass(ClassElement element) {
    if (element.isAbstract) throw UnimplementedError('the CriteriaCollection can not be abstract');
    if (element.isEnum) throw UnimplementedError('the CriteriaCollection can not be an enum');
    if (element.isMixin) throw UnimplementedError('the CriteriaCollection can not be a mixin');
    if (element.allSupertypes.isEmpty ||
        element.allSupertypes[0].element.name != 'GenericCriteriaCollection' ||
        element.allSupertypes[0].typeArguments.isEmpty)
      throw UnimplementedError('the CriteriaCollection must derive from GenericCriteriaCollection<T>');

    if (!element.name.endsWith('CriteriaCollection'))
      throw UnimplementedError('the class name ot CriteriaCollection must end with CriteriaCollection');
  }

  void buildConstr(ConstructorBuilder builder, String name, TypeReference type) {
    builder.name = name;
    builder.requiredParameters.add(Parameter((pBuilder) => pBuilder
      ..name = 'value'
      ..type = setNullable(type, nullable: true)));
    builder.optionalParameters.add(Parameter((pBuilder) => pBuilder
      ..name = 'name'
      ..type = refer('String')
      ..named = true
      ..required = true));
    builder.initializers.add(Code('super.$name(value, name: name)'));
  }

  _OptionalInput getOptionalProperties(ClassElement classElement) {
    for (final annotation in classElement.metadata) {
      final constValue = annotation.computeConstantValue();
      if (constValue == null) continue;

      final reader = ConstantReader(constValue);
      if (!optionalInputChecker.isAssignableFromType(constValue.type!)) continue;

      final filed = reader.read('generateOnlyOptional');

      return _OptionalInput(isOptional: true, generateOnlyOptional: filed.boolValue);
    }
    return _OptionalInput(isOptional: false, generateOnlyOptional: false);
  }
}
