part of 'converter.dart';

const _parserChecker = TypeChecker.fromRuntime(Parser);

class _ValidatorAnalyzeResult {
  final String fieldName;
  final ClassElement validator;
  final DartType fieldType;
  final DartType targetType;

  _ValidatorAnalyzeResult(this.fieldName, this.validator, this.fieldType, this.targetType);
}

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

  @override
  LType get returnType => to;

  @override
  String get methodName => '_${fieldName.toLowerCase()}${validator.name.toLowerCase()}';

  @override
  List<LParameter> get methodParameters => [LParameter('value', from)];

  @override
  List<LParameter> get parameters => [];

  @override
  AllocateBody? get body => (LibraryContext ctx, Allocate allocate) {
        final validatorType = allocate(ctx.resolveDartType(validator.thisType));

        return 'return (rules[$index].getValidator() as $validatorType).parse(value).rightOrThrow();';
      };
}

class IterableValidatorConverterInfo extends ValidatorConverterInfo {
  const IterableValidatorConverterInfo({
    required int index,
    required ClassElement validator,
    required String fieldName,
    required LType from,
    required LType to,
  }) : super(
          fieldName: fieldName,
          from: from,
          to: to,
          validator: validator,
          index: index,
        );

  @override
  AllocateBody? get body => (LibraryContext ctx, Allocate allocate) {
        final validatorType = allocate(ctx.resolveDartType(validator.thisType));

        return '''
          final validator = rules[$index].getIterableRules().first.getValidator() as $validatorType;
          return value.map((e) => validator.parse(e).rightOrThrow());
        ''';
      };
}

Iterable<ConverterInfo> analyzeValidatorConvert(LibraryContext ctx, ParserInfo info, List<Rule> rules) sync* {
  for (final rule in rules) {
    final result = _analyzeValidator(rule.fieldName, rule.validator, info.source);
    if (result != null) {
      yield ValidatorConverterInfo(
        index: rule.index,
        validator: result.validator,
        fieldName: result.fieldName,
        from: ctx.resolveLType(result.fieldType),
        to: ctx.resolveLType(result.targetType),
      );
    }

    final iterableResult = _analyzeValidator(rule.fieldName, rule.iterableRule?.validator, info.source);
    if (iterableResult != null) {
      final from = ctx.resolveLType(iterableResult.fieldType);
      final to = from.copyWith(typeArguments: () => [ctx.resolveLType(iterableResult.targetType)]);

      yield IterableValidatorConverterInfo(
        index: rule.index,
        validator: iterableResult.validator,
        fieldName: iterableResult.fieldName,
        from: from,
        to: to,
      );
    }
  }
}

_ValidatorAnalyzeResult? _analyzeValidator(String? fieldName, ClassElement? validator, ClassElement source) {
  if (validator == null) {
    return null;
  }

  if (fieldName == null) {
    warning(null, 'No field name for validator: $validator');
    return null;
  }

  final fieldType = source.getField(fieldName)?.type;
  if (fieldType == null) {
    warning(null, 'Source has not field: $fieldName');
    return null;
  }

  final annotation = _parserChecker.firstAnnotationOfExact(validator, throwOnUnresolved: false);
  if (annotation == null) {
    return null;
  }

  final target = ConstantReader(annotation).read('target').typeValue;

  return _ValidatorAnalyzeResult(fieldName, validator, fieldType, target);
}
