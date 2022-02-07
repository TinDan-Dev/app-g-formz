import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/visitor.dart';
import 'package:code_builder/code_builder.dart';
import 'package:collection/collection.dart';
import 'package:formz/annotation.dart';
import 'package:source_gen/source_gen.dart';

import '../../utils/log.dart';
import '../../utils/utils.dart';
import '../opt.dart';
import '../types/types.dart';
import 'parameter.dart';
import 'parser.dart';

typedef Allocate = String Function(Reference);

typedef AllocateBody = String Function(LibraryContext ctx, Allocate allocate);

const _createChecker = TypeChecker.fromRuntime(Create);

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

class CreateMethod with LConditionMixin implements MethodWriteInfo {
  @override
  final String methodName;
  @override
  final LType returnType;
  @override
  final List<LParameter> methodParameters;
  @override
  final AllocateBody? body;

  @override
  final String? ifCondition;

  CreateMethod({
    required this.methodName,
    required this.returnType,
    required this.methodParameters,
    required this.body,
    required this.ifCondition,
  });

  @override
  List<LParameter> get parameters => methodParameters;
}

CreateMethod analyzeCreateConstructor(LibraryContext ctx, ParserInfo parser) {
  final constructor = parser.target.constructors.firstWhereOrNull((e) => e.periodOffset == null);
  if (constructor == null) {
    error(null, 'No unnamed constructor found for: ${parser.targetType}');
  }

  final params = fromParameterElements(ctx, constructor.parameters, allowNamed: true).toList();

  final body = (LibraryContext ctx, Allocate allocate) {
    final buf = StringBuffer('return ');
    buf.write(allocate(parser.targetType.ref));
    buf.write('(');

    for (final param in params) {
      buf.write(param.name);
      buf.write(': ');
      buf.write(param.name);
      buf.write(', ');
    }

    buf.write(');');
    return buf.toString();
  };

  return CreateMethod(
    methodParameters: params,
    methodName: '_$createInstanceMethodName',
    returnType: parser.targetType,
    ifCondition: null,
    body: body,
  );
}

Iterable<CreateMethod> analyzeCreateMethod(LibraryContext ctx, ParserInfo parser, ClassElement element) {
  final collector = _CreateMethodCollector(ctx, parser.targetType);
  element.visitChildren(collector);

  return collector.methods;
}

class _CreateMethodCollector extends SimpleElementVisitor<void> {
  final List<CreateMethod> methods;

  final LibraryContext ctx;
  final LType targetType;

  _CreateMethodCollector(this.ctx, this.targetType) : methods = [];

  @override
  void visitMethodElement(MethodElement node) {
    final annotation = _createChecker.firstAnnotationOfExact(node, throwOnUnresolved: false);
    if (annotation == null) {
      return;
    }

    final createMethodType = ctx.resolveLType(node.returnType);
    if (!LType.sameType(targetType, createMethodType)) {
      error(
        null,
        'The return type of the "$createInstanceMethodName" method should be: $targetType',
      );
    }

    final ifConditionField = ConstantReader(annotation).read('condition');
    final ifCondition = ifConditionField.isNull ? null : ifConditionField.stringValue;

    final parameters = fromParameterElements(ctx, node.parameters).toList();

    methods.add(CreateMethod(
      methodParameters: parameters,
      methodName: createInstanceMethodName,
      returnType: targetType,
      ifCondition: ifCondition,
      body: null,
    ));
  }
}
