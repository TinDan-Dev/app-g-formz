import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:formz/annotation.dart';
import 'package:source_gen/source_gen.dart';

import 'parser/analyzer/converter/validator_converter.dart';
import 'parser/analyzer/method.dart';
import 'parser/analyzer/parameter.dart';
import 'parser/analyzer/parser.dart';
import 'parser/analyzer/rule.dart';
import 'parser/writer/extension.dart';
import 'parser/writer/method.dart';
import 'parser/writer/mixin.dart';
import 'utils/utils.dart';

Builder parserGeneratorBuilder(BuilderOptions options) => SharedPartBuilder([ParserGenerator()], 'parser');

const validatorURL = 'package:formz/src/functional/validation/validator.dart';

class ParserGenerator extends GeneratorForAnnotation<Parser> {
  @override
  Future<String> generateForAnnotatedElement(Element element, ConstantReader annotation, BuildStep buildStep) async {
    final ctx = await LibraryContext.fromBuildStep(buildStep);

    final info = analyzeParser(ctx, element, annotation);
    final rules = analyzeRules(await buildStep.resolver.astNodeFor(element, resolve: true));

    addValidatorConvert(info, rules);

    final CreateMethod method;
    if (info.useConstructor) {
      method = analyzeCreateConstructor(info);
    } else {
      method = analyzeCreateMethod(element as ClassElement, info);
    }

    final methods = <MethodWriteInfo>[method];
    methods.addAll(info.converters.whereType<MethodWriteInfo>());
    methods.addAll(info.fieldConverters.whereType<MethodWriteInfo>());

    for (final m in methods) {
      addParameterConverter(m.parameters, info, rules);
    }

    final buildMethods = methods.map((e) => buildMethod(ctx, e)).toList();

    final createMethodInvocation = buildCreateMethodInvocation(ctx, info, method);
    final mixin = buildMixin(ctx, info, createMethodInvocation, buildMethods);
    final extension = buildExtension(ctx, info, element as ClassElement);

    final emitter = DartEmitter(useNullSafetySyntax: true);

    return '''
    ${mixin.accept(emitter)}
    ${extension.accept(emitter)}
    ''';
  }
}
