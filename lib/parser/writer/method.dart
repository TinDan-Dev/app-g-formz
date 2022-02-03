import 'package:code_builder/code_builder.dart';

import '../../utils/utils.dart';
import '../analyzer/method.dart';
import '../analyzer/parser.dart';
import 'converter.dart';

final Allocate _allocate = (Reference ref) {
  if (ref is TypeReference) {
    var types = '';

    if (ref.types.isNotEmpty) {
      types = ref.types.map(_allocate).join(',');
      types = '<$types>';
    }

    return '${ref.symbol}$types';
  } else {
    return ref.symbol!;
  }
};

Method buildMethod(LibraryContext ctx, MethodWriteInfo info) {
  final toRef = info.returnType.ref;
  final bodyAllocator = info.body;

  final Code? body;
  if (bodyAllocator != null) {
    body = Code(bodyAllocator(ctx, _allocate));
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

Iterable<Parameter> _buildParameters(LibraryContext ctx, List<LParameter> parameters) sync* {
  for (final param in parameters) {
    yield Parameter(
      (builder) => builder
        ..name = param.name
        ..type = param.type.ref,
    );
  }
}

Expression buildCreateMethodInvocation(LibraryContext ctx, ParserInfo info, CreateMethod method) {
  final args = buildArguments(method.methodParameters, ctx, _allocate).join(', ');

  return Method(
    (builder) => builder
      ..requiredParameters.add(Parameter((builder) => builder..name = '_'))
      ..returns = info.targetType.ref
      ..body = Code('return ${method.methodName}($args);'),
  ).closure;
}
