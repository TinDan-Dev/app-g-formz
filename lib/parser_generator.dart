import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:formz/annotation.dart';
import 'package:source_gen/source_gen.dart';

import 'parser/analyzer/converter/converter.dart';
import 'parser/analyzer/method.dart';
import 'parser/analyzer/parser.dart';
import 'parser/analyzer/rule.dart';
import 'parser/types/types.dart';
import 'parser/writer/extension.dart';
import 'parser/writer/mixin.dart';
import 'utils/utils.dart';

final Allocate _allocate = (Reference ref) {
  if (ref is TypeReference) {
    var types = '';

    if (ref.types.isNotEmpty) {
      types = ref.types.map(_allocate).join(',');
      types = '<$types>';
    }

    return '${ref.symbol}$types';
  } else {
    return ref.symbol!;
  }
};

Builder parserGeneratorBuilder(BuilderOptions options) => SharedPartBuilder([ParserGenerator()], 'parser');

class ParserGenerator extends GeneratorForAnnotation<Parser> {
  @override
  Future<String> generateForAnnotatedElement(Element element, ConstantReader annotation, BuildStep buildStep) async {
    final ctx = await LibraryContext.fromBuildStep(buildStep);

    final info = analyzeParser(ctx, element, annotation);
    final rules = analyzeRules(await buildStep.resolver.astNodeFor(element, resolve: true));

    info.addConverters(analyzeNullCheckConverter(ctx, info, rules, null));
    info.addConverters(analyzeValidatorConvert(ctx, info, rules, null));
    info.addConverters(analyzeExternConverter(ctx, annotation));
    info.addConverters(analyzeMethodConverter(ctx, element as ClassElement));

    final createMethods = analyzeCreateMethod(ctx, info, element).toList();
    if (info.useConstructor) {
      createMethods.add(analyzeCreateConstructor(ctx, info));
    }

    final methods = <MethodWriteInfo>[...createMethods];
    methods.addAll(info.converters.whereType<MethodWriteInfo>());
    methods.addAll(info.fieldConverters.whereType<MethodWriteInfo>());

    final buildCtx = BuildContext(libCtx: ctx, info: info, rules: rules, allocate: _allocate);

    final mixin = buildMixin(buildCtx, methods);
    final extension = buildExtension(ctx, info, element);

    final emitter = DartEmitter(useNullSafetySyntax: true);

    return '''
    ${mixin.accept(emitter)}
    ${extension.accept(emitter)}
    ''';
  }
}
