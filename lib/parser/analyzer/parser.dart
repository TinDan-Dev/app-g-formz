import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';
import 'package:source_gen/source_gen.dart';

import '../../utils/log.dart';
import '../opt.dart';
import 'converter/converter.dart';
import 'converter/method_converter.dart';

const _validatorChecker = TypeChecker.fromUrl('$validatorURL#$validatorClass');

class ParserInfo {
  final ClassElement parser;
  final ClassElement target;
  final ClassElement source;

  final bool useConstructor;

  final List<ConverterInfo> converters;
  final List<FieldConverterInfo> fieldConverters;

  ParserInfo({
    required this.parser,
    required this.target,
    required this.source,
    required this.converters,
    required this.fieldConverters,
    required this.useConstructor,
  });

  String get name => parser.name;

  DartType get targetType => target.thisType;

  DartType get sourceType => source.thisType;
}

ParserInfo analyzeParser(Element element, ConstantReader annotation) {
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
  final externConverter =
      annotation.read('converter').listValue.map((e) => e.toFunctionValue()).whereNotNull().toList();

  final converterCollector = MethodConverterCollector();
  element.visitChildren(converterCollector);

  return ParserInfo(
    source: source,
    target: target,
    parser: element,
    converters: converterCollector.converters,
    fieldConverters: converterCollector.fieldConverters,
    useConstructor: useConstructor,
  );
}
