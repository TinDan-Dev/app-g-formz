import 'package:analyzer/dart/element/element.dart';
import 'package:collection/collection.dart';
import 'package:source_gen/source_gen.dart';

import '../../utils/log.dart';
import '../../utils/utils.dart';
import '../opt.dart';
import '../types/types.dart';
import 'converter/converter.dart';

const _validatorChecker = TypeChecker.fromUrl('$validatorURL#$validatorClass');

class ParserInfo {
  final ClassElement parser;
  final ClassElement target;
  final ClassElement source;

  final LType targetType;
  final LType sourceType;
  final Map<String, LType> sourceFields;

  final bool useConstructor;

  final List<ConverterInfo> _converters;

  ParserInfo({
    required this.parser,
    required this.target,
    required this.source,
    required this.targetType,
    required this.sourceType,
    required this.sourceFields,
    required this.useConstructor,
  }) : _converters = [];

  Iterable<ConverterInfo> get converters => _converters.whereNot((e) => e is FieldConverterInfo);

  Iterable<FieldConverterInfo> get fieldConverters => _converters.whereType<FieldConverterInfo>();

  String get name => parser.name;

  void addConverters(Iterable<ConverterInfo> converters) => _converters.addAll(converters);
}

ParserInfo analyzeParser(LibraryContext ctx, Element element, ConstantReader annotation) {
  if (element is! ClassElement) {
    error(null, 'Parser should be a class, but is ${element.runtimeType}');
  }

  final supertype = element.allSupertypes.firstWhereOrNull((e) => _validatorChecker.isExactlyType(e));
  if (supertype == null) {
    error(null, 'Parser should be a subclass of Validator');
  }

  final source = supertype.typeArguments.firstOrNull?.element;
  if (source is! ClassElement) {
    error(null, 'Parser does not declare a type argument for Validator');
  }

  final target = annotation.read('target').typeValue.element;
  if (target is! ClassElement) {
    error(null, 'Target should be a class');
  }

  final useConstructor = annotation.read('useConstructor').boolValue;

  final sourceFields = {
    for (final field in source.fields) field.name: ctx.resolveLType(field.type),
  };

  return ParserInfo(
    source: source,
    target: target,
    sourceType: ctx.resolveLType(source.thisType),
    targetType: ctx.resolveLType(target.thisType),
    sourceFields: sourceFields,
    parser: element,
    useConstructor: useConstructor,
  );
}
