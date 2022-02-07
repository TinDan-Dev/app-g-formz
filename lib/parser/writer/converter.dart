import '../analyzer/converter/converter.dart';
import '../analyzer/parameter.dart';
import '../types/types.dart';

Iterable<String> buildArguments(BuildContext ctx, List<LParameter> parameter) sync* {
  for (final param in parameter) {
    var arg = 'source.${param.name}';

    final converter = getConverter(ctx, param);

    yield converter.apply(ctx, arg);
  }
}

abstract class ArgumentConverter {
  final ArgumentConverter? child;

  const ArgumentConverter(this.child);

  String apply(BuildContext ctx, String parameter) {
    if (child != null) {
      return child!.apply(ctx, parameter);
    } else {
      return parameter;
    }
  }
}

class NoConverter extends ArgumentConverter {
  const NoConverter() : super(null);

  @override
  String apply(BuildContext ctx, String parameter) => parameter;
}

class NullCheckConverter extends ArgumentConverter {
  final NullCheckConverterInfo info;

  const NullCheckConverter(this.info) : super(null);

  @override
  String apply(BuildContext ctx, String parameter) {
    final ref = ctx.allocate(info.to.ref);

    return '${super.apply(ctx, parameter)} as $ref';
  }
}

class MethodConverter extends ArgumentConverter {
  final MethodConverterInfo info;

  MethodConverter(this.info, {ArgumentConverter? child}) : super(child);

  @override
  String apply(BuildContext ctx, String parameter) {
    final params = [
      super.apply(ctx, parameter),
      ...buildArguments(ctx, info.parameters),
    ].join(', ');

    return '${info.methodName}($params)';
  }
}

class FieldMethodConverter extends ArgumentConverter {
  final FieldMethodConverterInfo info;

  FieldMethodConverter(this.info, {ArgumentConverter? child}) : super(child);

  @override
  String apply(BuildContext ctx, String parameter) {
    final params = [
      super.apply(ctx, parameter),
      ...buildArguments(ctx, info.parameters.sublist(1)),
    ].join(', ');

    return '${info.methodName}($params)';
  }
}

class ValidatorConverter extends ArgumentConverter {
  final ValidatorConverterInfo info;

  ValidatorConverter(this.info, {ArgumentConverter? child}) : super(child);

  @override
  String apply(BuildContext ctx, String parameter) {
    return '${info.methodName}(${super.apply(ctx, parameter)})';
  }
}

class ExternConverter extends ArgumentConverter {
  final ExternConverterInfo info;

  ExternConverter(this.info, {ArgumentConverter? child}) : super(child);

  @override
  String apply(BuildContext ctx, String parameter) {
    final ref = ctx.allocate(ctx.libCtx.resolveFunctionType(info.function));

    return '$ref(${super.apply(ctx, parameter)})';
  }
}

class IffConverter extends ArgumentConverter {
  final int index;

  const IffConverter(this.index, {ArgumentConverter? child}) : super(child);

  @override
  String apply(BuildContext ctx, String parameter) {
    return 'rules[$index].getIfCondition()?.call(source) == true ? ${super.apply(ctx, parameter)} : null';
  }
}
