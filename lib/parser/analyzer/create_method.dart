import 'package:analyzer/dart/element/element.dart';
import 'package:source_gen/source_gen.dart';

import '../../utils/log.dart';
import '../opt.dart';
import 'parameter.dart';
import 'parser.dart';

class CreateMethod {
  final List<MethodParameter> parameters;

  CreateMethod(this.parameters);
}

CreateMethod analyzeCreateMethod(ClassElement element, ParserInfo parser) {
  final createMethods = element.methods.where((e) => e.name == createInstanceMethodName).toList();
  if (createMethods.isEmpty) {
    error(null, 'Implement the "$createInstanceMethodName" method signature before running the generator');
  }

  final createMethod = createMethods.first;
  if (!TypeChecker.fromStatic(parser.targetType).isExactlyType(createMethod.returnType)) {
    error(
      null,
      'The return type of the "$createInstanceMethodName" method should be: ${parser.target.getDisplayString(withNullability: false)}',
    );
  }

  final parameters = fromParameterElements(createMethod.parameters).toList();

  return CreateMethod(parameters);
}
