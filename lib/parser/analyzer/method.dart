import 'package:analyzer/dart/element/element.dart';
import 'package:code_builder/code_builder.dart';
import 'package:collection/collection.dart';

import '../../utils/log.dart';
import '../../utils/utils.dart';
import '../opt.dart';
import '../type.dart';
import '../writer/converter.dart';
import 'parameter.dart';
import 'parser.dart';

typedef Allocate = String Function(Reference);

typedef AllocateBody = String Function(LibraryContext ctx, Allocate allocate);

class LParameter {
  final String name;
  final LType type;

  ArgumentConverter? converter;

  LParameter(this.name, this.type);
}

abstract class MethodWriteInfo {
  String get methodName;

  LType get returnType;

  /// The parameters for the generated method, can be different from the
  /// parameters list.
  List<LParameter> get methodParameters;

  /// The parameters that require conversion, should be a subset from the
  /// method parameters.
  List<LParameter> get parameters;

  AllocateBody? get body;
}

class CreateMethod implements MethodWriteInfo {
  @override
  final String methodName;
  @override
  final LType returnType;
  @override
  final List<LParameter> methodParameters;
  @override
  final AllocateBody? body;

  CreateMethod({
    required this.methodName,
    required this.returnType,
    required this.methodParameters,
    required this.body,
  });

  @override
  List<LParameter> get parameters => methodParameters;
}

CreateMethod analyzeCreateMethod(LibraryContext ctx, ParserInfo parser, ClassElement element) {
  final createMethods = element.methods.where((e) => e.name == createInstanceMethodName).toList();
  if (createMethods.isEmpty) {
    error(null, 'Implement the "$createInstanceMethodName" method signature before running the generator');
  }

  final createMethod = createMethods.first;
  final createMethodType = ctx.resolveLType(createMethod.returnType);

  if (!LType.sameType(parser.targetType, createMethodType)) {
    error(
      null,
      'The return type of the "$createInstanceMethodName" method should be: ${parser.target.getDisplayString(withNullability: false)}',
    );
  }

  final parameters = fromParameterElements(ctx, createMethod.parameters).toList();

  return CreateMethod(
    methodParameters: parameters,
    methodName: createInstanceMethodName,
    returnType: parser.targetType,
    body: null,
  );
}

CreateMethod analyzeCreateConstructor(LibraryContext ctx, ParserInfo parser) {
  final constructor = parser.target.constructors.firstWhereOrNull((e) => e.periodOffset == null);
  if (constructor == null) {
    error(null, 'No unnamed constructor found for: ${parser.targetType}');
  }

  final parameters = <LParameter>[];
  for (final param in constructor.parameters) {
    if (!param.isNamed) {
      error(null, 'Unnamed parameters are not supported for the constructor');
    }

    parameters.add(LParameter(param.name, ctx.resolveLType(param.type)));
  }

  final body = (LibraryContext ctx, Allocate allocate) {
    final buf = StringBuffer('return ');
    buf.write(allocate(parser.targetType.ref));
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
