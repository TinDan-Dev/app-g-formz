part of 'converter.dart';

class ExternConverterInfo extends ConverterInfo {
  final ExecutableElement function;

  ExternConverterInfo({required this.function, required LType from, required LType to}) : super(from: from, to: to);
}

Iterable<ExternConverterInfo> analyzeExternConverter(LibraryContext ctx, ConstantReader annotation) sync* {
  final elements = annotation.read('converter').listValue.map((e) => e.toFunctionValue()).whereNotNull().toList();

  for (final element in elements) {
    if (element.parameters.length != 1) {
      error(null, 'Extern converter functions can only have one argument, violated by: ${element.name}');
    }

    if (element.parameters[0].isNamed) {
      error(null, 'Extern converter functions can only have unnamed argument, violated by: ${element.name}');
    }

    yield ExternConverterInfo(
      function: element,
      from: ctx.resolveLType(element.parameters[0].type),
      to: ctx.resolveLType(element.returnType),
    );
  }
}
