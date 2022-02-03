part of 'converter.dart';

class ExternConverterInfo extends ConverterInfo {
  final ExecutableElement function;

  ExternConverterInfo({
    required this.function,
  }) : super(
          from: LType(function.parameters[0].type),
          to: LType(function.returnType),
        );
}

Iterable<ExternConverterInfo> analyzeExternConverter(ConstantReader annotation) sync* {
  final elements = annotation.read('converter').listValue.map((e) => e.toFunctionValue()).whereNotNull().toList();

  for (final element in elements) {
    if (element.parameters.length != 1) {
      error(null, 'Extern converter functions can only have one argument, violated by: ${element.name}');
    }

    if (element.parameters[0].isNamed) {
      error(null, 'Extern converter functions can only have unnamed argument, violated by: ${element.name}');
    }

    yield ExternConverterInfo(function: element);
  }
}
