import 'package:code_builder/code_builder.dart';

import '../../utils/utils.dart';
import '../analyzer/method.dart';
import '../types/types.dart';
import 'converter.dart';

Method buildMethod(BuildContext ctx, MethodWriteInfo info) {
  final toRef = info.returnType.ref;
  final bodyAllocator = info.body;

  final Code? body;
  if (bodyAllocator != null) {
    body = Code(bodyAllocator(ctx.libCtx, ctx.allocate));
  } else {
    body = null;
  }

  return Method(
    (builder) => builder
      ..name = info.methodName
      ..returns = toRef
      ..requiredParameters.addAll(_buildParameters(ctx.libCtx, info.methodParameters))
      ..body = body,
  );
}

Iterable<Parameter> _buildParameters(LibraryContext ctx, List<LParameter> parameters) sync* {
  for (final param in parameters) {
    yield Parameter(
      (builder) => builder
        ..name = param.name
        ..type = param.type.ref,
    );
  }
}

String buildCreateMethodInvocation(BuildContext ctx, CreateMethod method) {
  final args = buildArguments(ctx, method.parameters).join(', ');

  return '${method.methodName}($args)';
}
