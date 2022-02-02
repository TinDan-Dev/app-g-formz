import 'package:code_builder/code_builder.dart';

import '../../utils/utils.dart';
import '../analyzer/converter/method_converter.dart';
import '../analyzer/create_method.dart';
import '../analyzer/parameter.dart';
import '../analyzer/parser.dart';
import '../opt.dart';
import 'converter.dart';

Method buildConvertMethod(LibraryContext ctx, MethodConverterWriteInfo info) {
  final toRef = ctx.resolveDartType(info.to);

  return Method(
    (builder) => builder
      ..name = info.methodName
      ..returns = toRef
      ..requiredParameters.addAll(_buildParameters(ctx, info.methodParameters)),
  );
}

Method buildCreateMethod(LibraryContext ctx, ParserInfo info, CreateMethod method) {
  final targetRef = ctx.resolveDartType(info.targetType);

  return Method(
    (builder) => builder
      ..name = createInstanceMethodName
      ..returns = targetRef
      ..requiredParameters.addAll(_buildParameters(ctx, method.parameters)),
  );
}

Iterable<Parameter> _buildParameters(LibraryContext ctx, List<MethodParameter> parameters) sync* {
  for (final param in parameters) {
    yield Parameter(
      (builder) => builder
        ..name = param.name
        ..type = ctx.resolveDartType(param.type),
    );
  }
}

Expression buildCreateMethodInvocation(LibraryContext ctx, ParserInfo info, CreateMethod method) {
  final targetRef = ctx.resolveDartType(info.targetType);
  final args = buildArguments(method.parameters).join(', ');

  return Method(
    (builder) => builder
      ..requiredParameters.add(Parameter((builder) => builder..name = '_'))
      ..returns = targetRef
      ..body = Code('return $createInstanceMethodName($args);'),
  ).closure;
}
