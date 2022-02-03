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
  }) : super(from: from, to: to);

  @override
  LType get returnType => to;

  @override
  List<LParameter> get methodParameters => [
        LParameter('value', from),
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
  }) : super(fieldName: fieldName, from: from, to: to);

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
    }

    final param = params[0];
    final fieldName = ConstantReader(annotation).read('fieldName');

    if (fieldName.isNull) {
      converters.add(MethodConverterInfo(
        methodName: node.name,
        from: ctx.resolveLType(param.type),
        to: ctx.resolveLType(node.returnType),
        parameters: fromParameterElements(ctx, node.parameters.sublist(1)).toList(),
      ));
    } else {
      converters.add(FieldMethodConverterInfo(
        fieldName: fieldName.stringValue,
        methodName: node.name,
        from: ctx.resolveLType(param.type),
        to: ctx.resolveLType(node.returnType),
        parameters: fromParameterElements(ctx, node.parameters).toList(),
      ));
    }
  }
}
