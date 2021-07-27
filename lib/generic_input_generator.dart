// @dart = 2.0

import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:formz/annotation.dart';
import 'package:source_gen/source_gen.dart';

Builder genericInputGeneratorBuilder(BuilderOptions options) => SharedPartBuilder(
      [GenericInputGenerator()],
      'generic_input',
    );

class _OptionalInput {
  final bool isOptional;
  final bool generateOnlyOptional;

  _OptionalInput({this.isOptional, this.generateOnlyOptional}) : assert(isOptional || !generateOnlyOptional);
}

class GenericInputGenerator extends GeneratorForAnnotation<GenGenericInput> {
  final emitter = DartEmitter();

  @override
  FutureOr<String> generateForAnnotatedElement(Element element, ConstantReader annotation, BuildStep buildStep) {
    // check and cast to ClassElement
    if (element is! ClassElement) throw UnsupportedError('the annotation target should be a class');
    final classElement = element as ClassElement;

    isValidClass(classElement);

    final optional = getOptionalProperties(classElement);

    // gather the required information
    final name = classElement.name;
    final inputName = classElement.name.replaceAll('CriteriaCollection', '');
    final type = getTargetType(classElement, classElement.allSupertypes[0].typeArguments[0]);
    final docs = element.documentationComment;

    // build the classes
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
    String inputName,
    String name,
    String type,
    bool optional,
    String docs,
  }) {
    return Class((builder) {
      // create header
      builder.name = inputName;

      builder.docs.add('/// ${optional ? 'Optional ' : ''}Input implementation for "$inputName" criteria collection.');
      if (docs != null) {
        builder.docs.add('/// ');
        builder.docs.add(docs);
      }

      if (optional) builder.mixins.add(refer('OptionalInputMixin'));

      builder.extend = refer('GenericInput<$type>');

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
        ..returns = refer('GenericCriteriaCollection<$type>')
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
          ..type = refer('$type?')
          ..named = true
          ..required = true))
        ..optionalParameters.add(Parameter((pBuilder) => pBuilder
          ..name = 'pure'
          ..type = refer('bool')
          ..named = true
          ..defaultTo = const Code('false')))
        ..returns = refer('Input<$type,GenericInputError>')
        ..body = Code(bodyBuffer.toString())));
    });
  }

  void isValidClass(ClassElement element) {
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

  String getTargetType(ClassElement classElement, DartType type) {
    if (!type.isDynamic) return type.element.name;

    // ignore: avoid_print
    print('found dynamic target type, assuming due to other code generation, checking source...');

    final source = classElement.source?.contents?.data;
    if (source == null) throw UnsupportedError('could not access source code to analyse type');

    final regex = RegExp(
      '(?<=@genGenericInput\n(.*\n)*class ${classElement.name} extends GenericCriteriaCollection<)[^<>]*(?=>)',
      multiLine: true,
    );

    final match = regex.stringMatch(source);
    if (match == null)
      throw UnsupportedError('could not find type in source code, regex used to identify type: ${regex.pattern}');

    if (match == 'dynamic') {
      // ignore: avoid_print
      print('target is actually dynamic');
      return 'dynamic';
    } else {
      // ignore: avoid_print
      print('found type in source: $match');
      return match;
    }
  }

  void buildConstr(ConstructorBuilder builder, String name, String type) {
    builder.name = name;
    builder.requiredParameters.add(Parameter((pBuilder) => pBuilder
      ..name = 'value'
      ..type = refer('$type?')));
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
      if (constValue?.type?.element?.name != 'OptionalInput') continue;

      final generateOnlyOptionalField = constValue.getField('generateOnlyOptional');
      if (generateOnlyOptionalField == null || generateOnlyOptionalField.isNull)
        throw UnsupportedError('could not access generateOnlyOptional of OptionalInput');

      final generateOnlyOptional = generateOnlyOptionalField.toBoolValue();
      if (generateOnlyOptional == null) throw UnsupportedError('could not parse generateOnlyOptional of OptionalInput');

      return _OptionalInput(isOptional: true, generateOnlyOptional: generateOnlyOptional);
    }
    return _OptionalInput(isOptional: false, generateOnlyOptional: false);
  }
}
