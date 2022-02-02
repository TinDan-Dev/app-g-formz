import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:formz/annotation.dart';
import 'package:source_gen/source_gen.dart';

import '../../../utils/log.dart';
import '../../../utils/utils.dart';
import '../parameter.dart';
import '../parser.dart';
import '../rule.dart';
import 'converter.dart';

const _parserChecker = TypeChecker.fromRuntime(Parser);

class ValidatorConverterInfo extends FieldConverterInfo implements MethodConverterWriteInfo {
  final ClassElement validator;
  final int index;

  const ValidatorConverterInfo({
    required this.index,
    required this.validator,
    required String fieldName,
    required DartType from,
    required DartType to,
  }) : super(fieldName: fieldName, from: from, to: to);

  DartType get validatorType => validator.thisType;

  @override
  String get methodName => '_${validator.name.toLowerCase()}';

  @override
  List<MethodParameter> get methodParameters => [MethodParameter('value', from)];

  @override
  AllocateBody? get body => (LibraryContext ctx, Allocate allocate) =>
      'return (rules[$index].getValidator() as $validatorType).parse(value).rightOrThrow();';
}

void addValidatorConvert(ParserInfo info, List<Rule> rules) {
  for (final rule in rules) {
    final validator = rule.validator;
    if (validator == null) {
      continue;
    }

    final fieldName = rule.fieldName;
    if (fieldName == null) {
      warning(null, 'No field name for validator: $validator');
      continue;
    }

    final fieldType = info.source.getField(fieldName)?.type;
    if (fieldType == null) {
      warning(null, 'Source has not field: $fieldName');
      continue;
    }

    final validatorElement = validator.element;
    if (validatorElement is! ClassElement) {
      warning(null, 'Validator $validator is not a class');
      continue;
    }

    final annotation = _parserChecker.firstAnnotationOfExact(validatorElement, throwOnUnresolved: false);
    if (annotation == null) {
      continue;
    }

    final target = ConstantReader(annotation).read('target').typeValue;

    info.fieldConverters.add(ValidatorConverterInfo(
      index: rule.index,
      validator: validatorElement,
      fieldName: fieldName,
      from: fieldType,
      to: target,
    ));
  }
}
