import 'package:code_builder/code_builder.dart';

import '../../utils/utils.dart';
import '../analyzer/method.dart';
import '../analyzer/parameter.dart';
import '../analyzer/parser.dart';
import 'converter.dart';

Method buildMethod(LibraryContext ctx, MethodWriteInfo info) {
  final toRef = ctx.resolveDartType(info.returnType);
  final bodyAllocator = info.body;

  final Code? body;
  if (bodyAllocator != null) {
    body = Code.scope((allocate) => bodyAllocator(ctx, allocate));
  } else {
    body = null;
  }

  return Method(
    (builder) => builder
      ..name = info.methodName
      ..returns = toRef
      ..requiredParameters.addAll(_buildParameters(ctx, info.methodParameters))
      ..body = body,
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
  final args = buildArguments(method.methodParameters).join(', ');

  return Method(
    (builder) => builder
      ..requiredParameters.add(Parameter((builder) => builder..name = '_'))
      ..returns = targetRef
      ..body = Code('return ${method.methodName}($args);'),
  ).closure;
}
