import 'package:meta/meta.dart';

import '../analyzer/converter/method_converter.dart';
import '../analyzer/converter/validator_converter.dart';
import '../analyzer/parameter.dart';

Iterable<String> buildArguments(List<MethodParameter> parameter) sync* {
  for (final param in parameter) {
    var arg = 'source.${param.name}';

    if (param.converter != null) {
      arg = param.converter!.apply(arg);
    }

    yield arg;
  }
}

abstract class ArgumentConverter {
  final ArgumentConverter? child;

  const ArgumentConverter(this.child);

  @mustCallSuper
  String apply(String parameter) {
    if (child != null) {
      return child!.apply(parameter);
    } else {
      return parameter;
    }
  }
}

class NullCheckConverter extends ArgumentConverter {
  const NullCheckConverter() : super(null);

  @override
  String apply(String parameter) => '${super.apply(parameter)}!';
}

class MethodConverter extends ArgumentConverter {
  final MethodConverterInfo info;

  MethodConverter(this.info, {ArgumentConverter? child}) : super(child);

  @override
  String apply(String parameter) {
    final params = [super.apply(parameter), ...buildArguments(info.parameters)].join(', ');

    return '${info.methodName}($params)';
  }
}

class FieldMethodConverter extends ArgumentConverter {
  final FieldMethodConverterInfo info;

  FieldMethodConverter(this.info, {ArgumentConverter? child}) : super(child);

  @override
  String apply(String parameter) {
    final params = [super.apply(parameter), ...buildArguments(info.parameters.sublist(1))].join(', ');

    return '${info.methodName}($params)';
  }
}

class ValidatorConverter extends ArgumentConverter {
  final ValidatorConverterInfo info;

  ValidatorConverter(this.info, {ArgumentConverter? child}) : super(child);

  @override
  String apply(String parameter) {
    return '${info.methodName}(${super.apply(parameter)})';
  }
}
