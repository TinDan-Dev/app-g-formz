import 'package:analyzer/dart/element/element.dart';
import 'package:collection/collection.dart';
import 'package:formz/annotation.dart';
import 'package:source_gen/source_gen.dart';

import '../../utils/log.dart';
import '../../utils/utils.dart';
import '../types/types.dart';
import '../writer/converter.dart';
import 'converter/converter.dart';

const _iffChecker = TypeChecker.fromRuntime(Iff);

Iterable<LParameter> fromParameterElements(
  LibraryContext ctx,
  Iterable<ParameterElement> parameters, {
  bool allowNamed = false,
}) sync* {
  for (final param in parameters) {
    if (!allowNamed && param.isNamed) {
      error(null, 'Named parameters are not supported');
    }

    final annotation = _iffChecker.firstAnnotationOfExact(param, throwOnUnresolved: false);
    final String? ifCondition;

    if (annotation != null) {
      ifCondition = ConstantReader(annotation).read('condition').stringValue;
    } else {
      ifCondition = null;
    }

    yield LParameter(
      name: param.name,
      type: ctx.resolveLType(param.type),
      ifCondition: ifCondition,
    );
  }
}

ArgumentConverter? _fromConverter(ConverterInfo info, {ArgumentConverter? child}) {
  if (info is NullCheckConverterInfo) {
    return NullCheckConverter(info);
  }
  if (info is MethodConverterInfo) {
    return MethodConverter(info, child: child);
  }
  if (info is FieldMethodConverterInfo) {
    return FieldMethodConverter(info, child: child);
  }
  if (info is ValidatorConverterInfo) {
    return ValidatorConverter(info, child: child);
  }
  if (info is ExternConverterInfo) {
    return ExternConverter(info, child: child);
  }

  return child;
}

class _NoResult implements Exception {
  const _NoResult();
}

ArgumentConverter? _getConverterFor({
  required Iterable<ConverterInfo> converters,
  required Iterable<FieldConverterInfo> fieldConverters,
  required LType currentType,
  required LType requestedType,
  ArgumentConverter? childConverter,
}) {
  if (LType.assignable(requestedType, currentType, nullability: true)) {
    return childConverter;
  }

  for (final converter in fieldConverters.where((e) => LType.assignable(e.from, currentType, nullability: true))) {
    try {
      return _getConverterFor(
        converters: converters,
        fieldConverters: fieldConverters.whereNot((e) => e == converter),
        currentType: converter.to,
        requestedType: requestedType,
        childConverter: _fromConverter(converter, child: childConverter),
      );
    } on _NoResult {
      continue;
    }
  }
  for (final converter in converters.where((e) => LType.assignable(e.from, currentType, nullability: true))) {
    try {
      return _getConverterFor(
        converters: converters.whereNot((e) => e == converter),
        fieldConverters: fieldConverters,
        currentType: converter.to,
        requestedType: requestedType,
        childConverter: _fromConverter(converter, child: childConverter),
      );
    } on _NoResult {
      continue;
    }
  }

  throw const _NoResult();
}

ArgumentConverter _getConverter(BuildContext ctx, LParameter param) {
  final fieldType = ctx.info.sourceFields[param.name];
  if (fieldType == null) {
    error(null, 'No field found for parameter: ${param.name}:${param.type}');
  }

  final fieldConverters = ctx.info.fieldConverters
      .where((e) => e.fieldName == param.name)
      .where((e) => e.availableForCondition(ctx.conditions));

  final converters = ctx.info.converters.where((e) => e.availableForCondition(ctx.conditions));

  try {
    final converter = _getConverterFor(
      converters: converters,
      fieldConverters: fieldConverters,
      currentType: fieldType,
      requestedType: param.type,
    );

    return converter ?? const NoConverter();
  } on _NoResult {
    error(null, 'Could not converter ${param.name}:${fieldType} to ${param.type}');
  }
}

ArgumentConverter getConverter(BuildContext ctx, LParameter param) {
  if (param.hasCondition) {
    final index = ctx.getIndexOfRuleForCondition(param.ifCondition!);

    return IffConverter(index, child: _getConverter(ctx.withCondition([param.ifCondition!]), param));
  } else {
    return _getConverter(ctx, param);
  }
}
