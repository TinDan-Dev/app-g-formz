import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:code_builder/code_builder.dart';
import 'package:collection/collection.dart';
import 'package:source_gen/source_gen.dart';

import '../../utils/log.dart';
import '../../utils/utils.dart';
import '../opt.dart';
import 'parameter.dart';
import 'parser.dart';

typedef Allocate = String Function(Reference);

typedef AllocateBody = String Function(LibraryContext ctx, Allocate allocate);

abstract class MethodWriteInfo {
  String get methodName;

  DartType get returnType;

  /// The parameters for the generated method, can be different from the
  /// parameters list.
  List<MethodParameter> get methodParameters;

  /// The parameters that require conversion, should be a subset from the
  /// method parameters.
  List<MethodParameter> get parameters;

  AllocateBody? get body;
}

class CreateMethod implements MethodWriteInfo {
  @override
  final String methodName;
  @override
  final DartType returnType;
  @override
  final List<MethodParameter> methodParameters;
  @override
  final AllocateBody? body;

  CreateMethod({
    required this.methodName,
    required this.returnType,
    required this.methodParameters,
    required this.body,
  });

  @override
  List<MethodParameter> get parameters => methodParameters;
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

  return CreateMethod(
    methodParameters: parameters,
    methodName: createInstanceMethodName,
    returnType: parser.targetType,
    body: null,
  );
}

CreateMethod analyzeCreateConstructor(ParserInfo parser) {
  final constructor = parser.target.constructors.firstWhereOrNull((e) => e.periodOffset == null);
  if (constructor == null) {
    error(null, 'No unnamed constructor found for: ${parser.targetType}');
  }

  final parameters = <MethodParameter>[];
  for (final param in constructor.parameters) {
    if (!param.isNamed) {
      error(null, 'Unnamed parameters are not supported for the constructor');
    }

    parameters.add(MethodParameter(param.name, param.type));
  }

  final body = (LibraryContext ctx, Allocate allocate) {
    final buf = StringBuffer('return ');
    buf.write(allocate(ctx.resolveDartType(parser.targetType)));
    buf.write('(');

    for (final param in parameters) {
      buf.write(param.name);
      buf.write(': ');
      buf.write(param.name);
      buf.write(', ');
    }

    buf.write(');');
    return buf.toString();
  };

  return CreateMethod(
    methodParameters: parameters,
    methodName: '_$createInstanceMethodName',
    returnType: parser.targetType,
    body: body,
  );
}
