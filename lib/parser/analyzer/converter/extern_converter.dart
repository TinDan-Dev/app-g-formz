import 'package:analyzer/dart/element/element.dart';

import '../../../utils/log.dart';
import 'converter.dart';

class ExternConverterInfo extends ConverterInfo {
  final ExecutableElement function;

  ExternConverterInfo({
    required this.function,
  }) : super(from: function.parameters[0].type, to: function.returnType);
}

Iterable<ExternConverterInfo> analyzeExternConverter(Iterable<ExecutableElement> elements) sync* {
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
