import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/visitor.dart';
import 'package:formz/annotation.dart';
import 'package:source_gen/source_gen.dart';

import '../../../utils/log.dart';
import '../method.dart';
import '../parameter.dart';
import 'converter.dart';

const _converterChecker = TypeChecker.fromRuntime(Convert);

class MethodConverterInfo extends ConverterInfo implements MethodWriteInfo {
  @override
  final String methodName;

  final List<MethodParameter> parameters;

  const MethodConverterInfo({
    required this.methodName,
    required this.parameters,
    required DartType from,
    required DartType to,
  }) : super(from: from, to: to);

  @override
  DartType get returnType => to;

  @override
  List<MethodParameter> get methodParameters => [
        MethodParameter('value', from),
        ...parameters,
      ];

  @override
  AllocateBody? get body => null;
}

class FieldMethodConverterInfo extends FieldConverterInfo implements MethodWriteInfo {
  @override
  final String methodName;

  final List<MethodParameter> parameters;

  const FieldMethodConverterInfo({
    required this.parameters,
    required this.methodName,
    required String fieldName,
    required DartType from,
    required DartType to,
  }) : super(fieldName: fieldName, from: from, to: to);

  @override
  DartType get returnType => to;

  @override
  List<MethodParameter> get methodParameters => parameters;

  @override
  AllocateBody? get body => null;
}

class MethodConverterCollector extends SimpleElementVisitor<void> {
  final List<ConverterInfo> converters;
  final List<FieldConverterInfo> fieldConverters;

  MethodConverterCollector(this.converters, this.fieldConverters);

  @override
  void visitMethodElement(MethodElement node) {
    final annotation = _converterChecker.firstAnnotationOfExact(node, throwOnUnresolved: false);
    if (annotation == null) {
      return;
    }

    final params = node.parameters;
    if (params.isEmpty) {
      warning(null, 'Converter method ${node.name} has no parameters, at least on is required');
    }

    final param = params[0];
    final fieldName = ConstantReader(annotation).read('fieldName');

    if (fieldName.isNull) {
      converters.add(MethodConverterInfo(
        methodName: node.name,
        from: param.type,
        to: node.returnType,
        parameters: fromParameterElements(node.parameters.sublist(1)).toList(),
      ));
    } else {
      fieldConverters.add(FieldMethodConverterInfo(
        fieldName: fieldName.stringValue,
        methodName: node.name,
        from: param.type,
        to: node.returnType,
        parameters: fromParameterElements(node.parameters).toList(),
      ));
    }
  }
}
