import 'package:code_builder/code_builder.dart';

import '../../utils/utils.dart';
import '../analyzer/parser.dart';
import '../opt.dart';

Mixin buildMixin(
  LibraryContext ctx,
  ParserInfo info,
  Map<Method, Expression> createMethods,
  List<Method> additionalMethods,
) {
  final sourceRef = ctx.resolveDartType(info.sourceType);

  final validatorType = TypeReference(
    (builder) => builder
      ..symbol = validatorClass
      ..url = validatorURL
      ..types.add(sourceRef),
  );

  final parseMethod = _createParseMethod(ctx, info, createMethods);

  return Mixin(
    (builder) => builder
      ..name = '_\$${info.name}'
      ..on = validatorType
      ..methods.addAll(createMethods.keys)
      ..methods.addAll(additionalMethods)
      ..methods.add(parseMethod),
  );
}

Method _createParseMethod(LibraryContext ctx, ParserInfo info, Map<Method, Expression> methods) {
  final sourceRef = ctx.resolveDartType(info.sourceType);
  final targetRef = ctx.resolveDartType(info.targetType);

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
          ..addExpression(methods.values.first.assignFinal('create'))
          ..addExpression(refer('validate').call([refer('source')]).assignFinal('result'))
          ..addExpression(refer('result').property('mapRight').call([refer('create')]).returned),
      ),
  );
}
