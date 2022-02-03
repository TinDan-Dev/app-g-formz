part of 'converter.dart';

const _parserChecker = TypeChecker.fromRuntime(Parser);

class ValidatorConverterInfo extends FieldConverterInfo implements MethodWriteInfo {
  final ClassElement validator;
  final int index;

  const ValidatorConverterInfo({
    required this.index,
    required this.validator,
    required String fieldName,
    required LType from,
    required LType to,
  }) : super(fieldName: fieldName, from: from, to: to);

  LType get validatorType => LType(validator.thisType);

  @override
  LType get returnType => to;

  @override
  String get methodName => '_${fieldName.toLowerCase()}${validator.name.toLowerCase()}';

  @override
  List<LParameter> get methodParameters => [LParameter('value', from)];

  @override
  List<LParameter> get parameters => [];

  @override
  AllocateBody? get body => (LibraryContext ctx, Allocate allocate) =>
      'return (rules[$index].getValidator() as $validatorType).parse(value).rightOrThrow();';
}

Iterable<ConverterInfo> analyzeValidatorConvert(ParserInfo info, List<Rule> rules) sync* {
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

    yield ValidatorConverterInfo(
      index: rule.index,
      validator: validatorElement,
      fieldName: fieldName,
      from: LType(fieldType),
      to: LType(target),
    );
  }
}
