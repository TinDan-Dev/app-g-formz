import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';

import '../../utils/log.dart';
import '../opt.dart';
import '../writer/converter.dart';
import 'parser.dart';
import 'rule.dart';

typedef ConverterMap = Map<CreateParameter, List<ArgumentConverter>>;

class CreateMethod {
  final List<CreateParameter> parameters;

  final ConverterMap converters;

  CreateMethod(this.parameters) : converters = {};
}

class CreateParameter {
  final String name;
  final DartType type;

  const CreateParameter(this.name, this.type);
}

CreateMethod analyzeCreateMethod(ClassElement element, ParserInfo parser) {
  final createMethods = element.methods.where((e) => e.name == createInstanceMethodName).toList();
  if (createMethods.isEmpty) {
    error(null, 'Implement the "$createInstanceMethodName" method signature before running the generator');
  }

  final createMethod = createMethods.first;
  if (!TypeChecker.fromStatic(parser.target).isExactlyType(createMethod.returnType)) {
    error(
      null,
      'The return type of the "$createInstanceMethodName" method should be: ${parser.target.getDisplayString(withNullability: false)}',
    );
  }

  final parameters = <CreateParameter>[];
  for (final param in createMethod.parameters) {
    if (param.isNamed) {
      error(null, 'Named parameters for the "$createInstanceMethodName" are not supported');
    }
    parameters.add(CreateParameter(param.name, param.type));
  }

  return CreateMethod(parameters);
}

bool _nullable(DartType type) => type.nullabilitySuffix == NullabilitySuffix.question;

void addParameterConverter(CreateMethod method, ParserInfo info, List<Rule> rules) {
  final source = info.source.element;
  if (source is! ClassElement) {
    error(null, 'Source is not a class');
  }

  for (final param in method.parameters) {
    final paramType = param.type;
    final sourceField = source.getField(param.name);

    if (sourceField == null) {
      error(null, 'No field found for parameter: ${param.name}');
    }
    if (!TypeChecker.fromStatic(sourceField.type).isAssignableFromType(paramType)) {
      error(null, 'Parameter ${param.name} is not assignable from source field');
    }

    if (_nullable(sourceField.type) && !_nullable(paramType)) {
      final nullCheck = rules.any((e) => e.fieldName == param.name && e.nullChecked);

      if (nullCheck) {
        method.converters.putIfAbsent(param, () => []).add(const NullCheckConverter());
      } else {
        error(
          null,
          'Parameter ${param.name} should not be null, but source field is nullable. Did you forget to add a null check rule?',
        );
      }
    }
  }
}
