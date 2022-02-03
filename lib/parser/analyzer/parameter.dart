import 'package:analyzer/dart/element/element.dart';
import 'package:collection/collection.dart';

import '../../utils/log.dart';
import '../types.dart';
import '../writer/converter.dart';
import 'converter/converter.dart';
import 'parser.dart';

Iterable<LParameter> fromParameterElements(Iterable<ParameterElement> parameters) sync* {
  for (final param in parameters) {
    if (param.isNamed) {
      error(null, 'Named parameters are not supported');
    }

    yield LParameter(param.name, LType(param.type));
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

LParameter _addConverter(LParameter param, ParserInfo info) {
  final sourceField = info.source.getField(param.name);
  if (sourceField == null) {
    error(null, 'No field found for parameter: ${param.name}:${param.type}');
  }

  final fieldType = LType(sourceField.type);
  final fieldConverter = info.fieldConverters.where((e) => e.fieldName == param.name);

  try {
    param.converter = _getConverterFor(
      converters: info.converters,
      fieldConverters: fieldConverter,
      currentType: fieldType,
      requestedType: param.type,
    );

    return param;
  } on _NoResult {
    error(null, 'Could not converter ${param.name}:${sourceField.type} to ${param.type}');
  }
}

void addParameterConverter(List<LParameter> parameters, ParserInfo info) {
  for (final param in parameters) {
    _addConverter(param, info);
  }
}
