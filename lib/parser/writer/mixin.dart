import 'package:code_builder/code_builder.dart';
import 'package:collection/collection.dart';

import '../../utils/log.dart';
import '../analyzer/method.dart';
import '../opt.dart';
import '../types/types.dart';
import 'method.dart';

Mixin buildMixin(BuildContext ctx, List<MethodWriteInfo> methods) {
  final sourceRef = ctx.info.sourceType.ref;

  final validatorType = TypeReference(
    (builder) => builder
      ..symbol = validatorClass
      ..url = validatorURL
      ..types.add(sourceRef),
  );

  final parseMethod = _createParseMethod(ctx, methods.whereType<CreateMethod>());

  return Mixin(
    (builder) => builder
      ..name = '_\$${ctx.info.name}'
      ..on = validatorType
      ..methods.addAll(methods.map((e) => buildMethod(ctx, e)))
      ..methods.add(parseMethod),
  );
}

Method _createParseMethod(BuildContext ctx, Iterable<CreateMethod> methods) {
  final sourceRef = ctx.info.sourceType.copyWith(nullable: () => true).ref;
  final targetRef = ctx.info.targetType.ref;

  final resultRef = TypeReference(
    (builder) => builder
      ..symbol = resultClass
      ..url = resultURL
      ..types.add(targetRef),
  );

  final buf = StringBuffer();
  buf.writeln('if (source == null) {');
  buf.writeln('   return Result.left(Failure(message: \'Input for ${ctx.info.name} was null\'));');
  buf.writeln('}');

  buf.writeln('return validate(source).mapRight((_) {');

  for (final m in methods.where((e) => e.hasCondition)) {
    final rule = ctx.rules.firstWhereOrNull((e) => e.ifCondition == m.ifCondition);
    if (rule == null) {
      warning(null, 'Could not find rule for condition: ${m.ifCondition}');
      continue;
    }

    final invocation = buildCreateMethodInvocation(ctx.withCondition([m.ifCondition!]), m);

    buf.writeln('if(rules[${rule.index}].getIfCondition()?.call(source) == true) {');
    buf.writeln('return $invocation;');
    buf.writeln('}');
  }

  final m = methods.where((e) => !e.hasCondition).firstOrNull;
  if (m == null) {
    error(null, 'No default create method found');
  }

  final invocation = buildCreateMethodInvocation(ctx, m);
  buf.writeln('return $invocation;');

  buf.writeln('});');

  return Method(
    (builder) => builder
      ..name = 'parse'
      ..requiredParameters.add(Parameter(
        (builder) => builder
          ..name = 'source'
          ..type = sourceRef,
      ))
      ..returns = resultRef
      ..body = Code(buf.toString()),
  );
}
