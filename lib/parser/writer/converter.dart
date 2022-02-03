import 'package:meta/meta.dart';

import '../../utils/utils.dart';
import '../analyzer/converter/converter.dart';
import '../analyzer/method.dart';

Iterable<String> buildArguments(List<LParameter> parameter, LibraryContext ctx, Allocate allocate) sync* {
  for (final param in parameter) {
    var arg = 'source.${param.name}';

    if (param.converter != null) {
      arg = param.converter!.apply(ctx, allocate, arg);
    }

    yield arg;
  }
}

abstract class ArgumentConverter {
  final ArgumentConverter? child;

  const ArgumentConverter(this.child);

  @mustCallSuper
  String apply(LibraryContext ctx, Allocate allocate, String parameter) {
    if (child != null) {
      return child!.apply(ctx, allocate, parameter);
    } else {
      return parameter;
    }
  }
}

class NullCheckConverter extends ArgumentConverter {
  final NullCheckConverterInfo info;

  const NullCheckConverter(this.info) : super(null);

  @override
  String apply(LibraryContext ctx, Allocate allocate, String parameter) {
    final ref = allocate(info.to.ref);

    return '${super.apply(ctx, allocate, parameter)} as $ref';
  }
}

class MethodConverter extends ArgumentConverter {
  final MethodConverterInfo info;

  MethodConverter(this.info, {ArgumentConverter? child}) : super(child);

  @override
  String apply(LibraryContext ctx, Allocate allocate, String parameter) {
    final params = [
      super.apply(ctx, allocate, parameter),
      ...buildArguments(info.parameters, ctx, allocate),
    ].join(', ');

    return '${info.methodName}($params)';
  }
}

class FieldMethodConverter extends ArgumentConverter {
  final FieldMethodConverterInfo info;

  FieldMethodConverter(this.info, {ArgumentConverter? child}) : super(child);

  @override
  String apply(LibraryContext ctx, Allocate allocate, String parameter) {
    final params = [
      super.apply(ctx, allocate, parameter),
      ...buildArguments(info.parameters.sublist(1), ctx, allocate),
    ].join(', ');

    return '${info.methodName}($params)';
  }
}

class ValidatorConverter extends ArgumentConverter {
  final ValidatorConverterInfo info;

  ValidatorConverter(this.info, {ArgumentConverter? child}) : super(child);

  @override
  String apply(LibraryContext ctx, Allocate allocate, String parameter) {
    return '${info.methodName}(${super.apply(ctx, allocate, parameter)})';
  }
}

class ExternConverter extends ArgumentConverter {
  final ExternConverterInfo info;

  ExternConverter(this.info, {ArgumentConverter? child}) : super(child);

  @override
  String apply(LibraryContext ctx, Allocate allocate, String parameter) {
    final ref = allocate(ctx.resolveFunctionType(info.function));

    return '$ref(${super.apply(ctx, allocate, parameter)})';
  }
}
