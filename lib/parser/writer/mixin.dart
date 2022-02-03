import 'package:code_builder/code_builder.dart';

import '../../utils/utils.dart';
import '../analyzer/parser.dart';
import '../opt.dart';

Mixin buildMixin(
  LibraryContext ctx,
  ParserInfo info,
  Expression createMethodInvocation,
  List<Method> methods,
) {
  final sourceRef = info.sourceType.ref;

  final validatorType = TypeReference(
    (builder) => builder
      ..symbol = validatorClass
      ..url = validatorURL
      ..types.add(sourceRef),
  );

  final parseMethod = _createParseMethod(ctx, info, createMethodInvocation);

  return Mixin(
    (builder) => builder
      ..name = '_\$${info.name}'
      ..on = validatorType
      ..methods.addAll(methods)
      ..methods.add(parseMethod),
  );
}

Method _createParseMethod(LibraryContext ctx, ParserInfo info, Expression createMethodInvocation) {
  final sourceRef = info.sourceType.ref;
  final targetRef = info.targetType.ref;

  final resultRef = TypeReference(
    (builder) => builder
      ..symbol = resultClass
      ..url = resultURL
      ..types.add(targetRef),
  );

  return Method(
    (builder) => builder
      ..name = 'parse'
      ..requiredParameters.add(Parameter(
        (builder) => builder
          ..name = 'source'
          ..type = sourceRef,
      ))
      ..returns = resultRef
      ..body = Block(
        (builder) => builder
          ..addExpression(createMethodInvocation.assignFinal('create'))
          ..addExpression(refer('validate').call([refer('source')]).assignFinal('result'))
          ..addExpression(refer('result').property('mapRight').call([refer('create')]).returned),
      ),
  );
}
