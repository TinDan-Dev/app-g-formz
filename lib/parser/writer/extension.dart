import 'package:analyzer/dart/element/element.dart';
import 'package:code_builder/code_builder.dart';

import '../../utils/utils.dart';
import '../analyzer/parser.dart';
import '../opt.dart';

Extension buildExtension(LibraryContext ctx, ParserInfo info, ClassElement element) {
  final sourceRef = info.sourceType.ref;
  final targetRef = info.targetType.ref;
  final validator = ctx.resolveDartType(element.thisType);

  final resultRef = TypeReference(
    (builder) => builder
      ..symbol = resultClass
      ..url = resultURL
      ..types.add(targetRef),
  );

  final parseMethod = Method((builder) => builder
    ..name = 'parse'
    ..returns = resultRef
    ..body = Block(
      (builder) => builder.addExpression(validator.constInstance([]).property('parse').call([refer('this')]).returned),
    ));

  return Extension((builder) => builder
    ..name = '\$${info.name}Extension'
    ..on = sourceRef
    ..methods.add(parseMethod));
}
