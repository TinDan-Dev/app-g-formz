import 'package:code_builder/code_builder.dart';

import '../../utils/utils.dart';
import '../analyzer/create_method.dart';
import '../analyzer/parser.dart';
import '../opt.dart';

Method buildCreateMethod(LibraryContext ctx, ParserInfo info, CreateMethod method) {
  final targetRef = ctx.resolveDartType(info.target);

  return Method(
    (builder) => builder
      ..name = createInstanceMethodName
      ..returns = targetRef
      ..requiredParameters.addAll(_buildParameters(ctx, method.parameters)),
  );
}

Iterable<Parameter> _buildParameters(LibraryContext ctx, List<CreateParameter> parameters) sync* {
  for (final param in parameters) {
    yield Parameter(
      (builder) => builder
        ..name = param.name
        ..type = ctx.resolveDartType(param.type),
    );
  }
}

Expression buildCreateMethodInvocation(LibraryContext ctx, ParserInfo info, CreateMethod method) {
  final targetRef = ctx.resolveDartType(info.target);
  final args = _buildArguments(method.parameters, method.converters).join(', ');

  return Method(
    (builder) => builder
      ..requiredParameters.add(Parameter((builder) => builder..name = '_'))
      ..returns = targetRef
      ..body = Code('return $createInstanceMethodName($args);'),
  ).closure;
}

Iterable<String> _buildArguments(List<CreateParameter> parameter, ConverterMap converters) sync* {
  for (final param in parameter) {
    var arg = 'source.${param.name}';

    final sortedConverter = converters[param] ?? [];
    sortedConverter.sort((a, b) => a.priority.compareTo(b.priority));

    for (final converter in sortedConverter) {
      arg = converter.apply(arg);
    }

    yield arg;
  }
}
