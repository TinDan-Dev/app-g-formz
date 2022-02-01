import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:formz/annotation.dart';
import 'package:source_gen/source_gen.dart';

import 'parser/analyzer/create_method.dart';
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

    final info = analyzeParser(element, annotation);
    final rules = analyzeRules(element as ClassElement);
    final method = analyzeCreateMethod(element, info);

    addParameterConverter(method, info, rules);

    final emitter = DartEmitter(useNullSafetySyntax: true);

    final createMethod = buildCreateMethod(ctx, info, method);
    final createMethodInvocation = buildCreateMethodInvocation(ctx, info, method);

    final mixin = buildMixin(ctx, info, {createMethod: createMethodInvocation});
    final extension = buildExtension(ctx, info, element);

    return '''
    ${mixin.accept(emitter)}
    ${extension.accept(emitter)}
    ''';
  }
}
