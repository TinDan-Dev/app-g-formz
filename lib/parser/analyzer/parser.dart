import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';

import '../../utils/log.dart';
import '../opt.dart';

const _validatorChecker = TypeChecker.fromUrl('$validatorURL#$validatorClass');

class ParserInfo {
  final String name;
  final DartType target;
  final DartType source;

  const ParserInfo({
    required this.name,
    required this.target,
    required this.source,
  });
}

ParserInfo analyzeParser(Element element, ConstantReader annotation) {
  if (element is! ClassElement) {
    error(null, 'Parser should be a class, but is ${element.runtimeType}');
  }

  final superClasses = element.allSupertypes.where((e) => _validatorChecker.isExactlyType(e)).toList();
  if (superClasses.isEmpty) {
    error(null, 'Parser must be a subclass of Validator');
  }

  final target = annotation.read('target').typeValue;
  final source = annotation.read('source').typeValue;

  return ParserInfo(name: element.name, source: source, target: target);
}
