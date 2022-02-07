part of 'converter.dart';

const _converterChecker = TypeChecker.fromRuntime(Convert);

class MethodConverterInfo extends ConverterInfo implements MethodWriteInfo {
  @override
  final String methodName;

  final List<LParameter> parameters;

  const MethodConverterInfo({
    required this.methodName,
    required this.parameters,
    required LType from,
    required LType to,
  }) : super(from: from, to: to, ifCondition: null);

  @override
  LType get returnType => to;

  @override
  List<LParameter> get methodParameters => [
        LParameter(name: 'value', type: from, ifCondition: null),
        ...parameters,
      ];

  @override
  AllocateBody? get body => null;
}

class FieldMethodConverterInfo extends FieldConverterInfo implements MethodWriteInfo {
  @override
  final String methodName;

  final List<LParameter> parameters;

  const FieldMethodConverterInfo({
    required this.parameters,
    required this.methodName,
    required String fieldName,
    required LType from,
    required LType to,
  }) : super(fieldName: fieldName, from: from, to: to, ifCondition: null);

  @override
  LType get returnType => to;

  @override
  List<LParameter> get methodParameters => parameters;

  @override
  AllocateBody? get body => null;
}

Iterable<ConverterInfo> analyzeMethodConverter(LibraryContext ctx, ClassElement element) {
  final collector = _MethodConverterCollector(ctx);
  element.visitChildren(collector);

  return collector.converters;
}

class _MethodConverterCollector extends SimpleElementVisitor<void> {
  final List<ConverterInfo> converters;
  final LibraryContext ctx;

  _MethodConverterCollector(this.ctx) : converters = [];

  @override
  void visitMethodElement(MethodElement node) {
    final annotation = _converterChecker.firstAnnotationOfExact(node, throwOnUnresolved: false);
    if (annotation == null) {
      return;
    }

    final params = node.parameters;
    if (params.isEmpty) {
      warning(null, 'Converter method ${node.name} has no parameters, at least on is required');
      return;
    }

    final param = params[0];
    final fieldName = ConstantReader(annotation).read('fieldName');

    final lParams = fromParameterElements(ctx, params).toList();
    if (lParams.first.ifCondition != null) {
      warning(null, 'The first parameter of a method converter cannot have a condition.');
      return;
    }

    if (fieldName.isNull) {
      converters.add(MethodConverterInfo(
        methodName: node.name,
        from: ctx.resolveLType(param.type),
        to: ctx.resolveLType(node.returnType),
        parameters: lParams.sublist(1),
      ));
    } else {
      converters.add(FieldMethodConverterInfo(
        fieldName: fieldName.stringValue,
        methodName: node.name,
        from: ctx.resolveLType(param.type),
        to: ctx.resolveLType(node.returnType),
        parameters: lParams,
      ));
    }
  }
}
