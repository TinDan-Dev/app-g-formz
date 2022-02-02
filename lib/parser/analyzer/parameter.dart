import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';
import 'package:source_gen/source_gen.dart';

import '../../utils/log.dart';
import '../writer/converter.dart';
import 'converter/converter.dart';
import 'converter/method_converter.dart';
import 'converter/validator_converter.dart';
import 'parser.dart';
import 'rule.dart';

class MethodParameter {
  final String name;
  final DartType type;

  ArgumentConverter? converter;

  MethodParameter(this.name, this.type);
}

Iterable<MethodParameter> fromParameterElements(Iterable<ParameterElement> parameters) sync* {
  for (final param in parameters) {
    if (param.isNamed) {
      error(null, 'Named parameters are not supported');
    }

    yield MethodParameter(param.name, param.type);
  }
}

ArgumentConverter? _fromConverter(ConverterInfo info, {ArgumentConverter? child}) {
  if (info is MethodConverterInfo) {
    return MethodConverter(info, child: child);
  }
  if (info is FieldMethodConverterInfo) {
    return FieldMethodConverter(info, child: child);
  }
  if (info is ValidatorConverterInfo) {
    return ValidatorConverter(info);
  }

  return child;
}

bool _nullable(DartType type) => type.nullabilitySuffix == NullabilitySuffix.question;

bool _typeAssignable(DartType to, DartType from, {bool nullability = false}) {
  if (!TypeChecker.fromStatic(from).isAssignableFromType(to)) {
    return false;
  }
  if (_nullable(to) || !nullability) {
    return true;
  }

  return !_nullable(from);
}

class _NoResult implements Exception {
  const _NoResult();
}

ArgumentConverter? _getConverterFor({
  required Iterable<ConverterInfo> converters,
  required Iterable<FieldConverterInfo> fieldConverters,
  required DartType currentType,
  required DartType requestedType,
  required ArgumentConverter? childConverter,
  bool nullChecked = false,
}) {
  if (_typeAssignable(currentType, requestedType, nullability: !nullChecked)) {
    return childConverter;
  }

  for (final converter
      in fieldConverters.where((e) => _typeAssignable(currentType, e.from, nullability: !nullChecked))) {
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
  for (final converter in converters.where((e) => _typeAssignable(currentType, e.from, nullability: !nullChecked))) {
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

MethodParameter _addConverter(MethodParameter param, ParserInfo info, List<Rule> rules) {
  final sourceField = info.source.getField(param.name);
  if (sourceField == null) {
    error(null, 'No field found for parameter: ${param.name}:${param.type}');
  }

  final fieldConverter = info.fieldConverters.where((e) => e.fieldName == param.name);

  try {
    if (_nullable(sourceField.type) && rules.any((e) => e.fieldName == param.name && e.nullChecked)) {
      param.converter = _getConverterFor(
        converters: info.converters,
        fieldConverters: fieldConverter,
        currentType: sourceField.type,
        requestedType: param.type,
        childConverter: const NullCheckConverter(),
        nullChecked: true,
      );

      return param;
    } else {
      param.converter = _getConverterFor(
        converters: info.converters,
        fieldConverters: fieldConverter,
        currentType: sourceField.type,
        requestedType: param.type,
        childConverter: null,
      );

      return param;
    }
  } on _NoResult {
    error(null, 'Could not converter ${param.name}:${sourceField.type} to ${param.type}');
  }
}

void addParameterConverter(List<MethodParameter> parameters, ParserInfo info, List<Rule> rules) {
  for (final param in parameters) {
    _addConverter(param, info, rules);
  }
}
