part of 'arl.dart';

extension ElementExtension on Element {
  String get ruleMethodName => methodName.toString();
}

class ParserStepResult {
  final RootNode root;
  ARLNode node;

  ParserStepResult({required this.root}) : node = root;

  void setOptional(ARLNode? node) {
    if (node != null) {
      this.node = node;
    }
  }
}

ARLNode parseRule(Element invocation) => _parseRule(invocation).node;

ParserStepResult _parseRule(Element invocation, [bool iterableRule = false]) {
  final ParserStepResult prevResult;

  final target = invocation.target;
  if (target is! Element) {
    if (target is SimpleIdentifier && iterableRule) {
      prevResult = ParserStepResult(root: IterableRootNode(target));
    } else {
      return _parseRootNode(target, invocation);
    }
  } else {
    prevResult = _parseRule(target, iterableRule);
  }

  switch (invocation.ruleMethodName) {
    case 'notNull':
      return prevResult..node = NullCheckNode(invocation, root: prevResult.root, child: prevResult.node);

    case 'any':
      return prevResult..setOptional(_parseIterableNode(invocation, prevResult, IterableCondition.any));

    case 'none':
      return prevResult..setOptional(_parseIterableNode(invocation, prevResult, IterableCondition.none));

    case 'every':
      return prevResult..setOptional(_parseIterableNode(invocation, prevResult, IterableCondition.every));

    case 'validator':
      return prevResult..setOptional(_parseValidatorNode(invocation, prevResult));

    case 'iff':
    case 'check':
    case 'match':
      return prevResult;

    default:
      warning(invocation, 'Unknown method');
      return prevResult;
  }
}

ParserStepResult _parseRootNode(AstNode? target, Element invocation) {
  if (invocation.ruleMethodName != 'ruleFor') {
    final String? name;
    if (invocation.ruleMethodName == 'rule') {
      name = _ruleNameFromArgumentList(invocation.argumentList);
    } else {
      name = null;
      warning(invocation, 'Unknown root node');
    }

    return ParserStepResult(root: RootNode(invocation, name: name));
  } else {
    final name = _ruleNameFromArgumentList(invocation.argumentList);
    final field = _fieldNameFromArgumentList(invocation.argumentList);

    final RootNode node;
    if (field != null) {
      node = FieldRootNode(invocation, fieldName: field, name: name);
    } else {
      node = RootNode(invocation, name: name);
    }

    return ParserStepResult(root: node);
  }
}

String? _ruleNameFromArgumentList(ArgumentList list) {
  for (final element in list.arguments) {
    if (element is NamedExpression && element.name.toString().startsWith('name')) {
      final expression = element.expression;
      if (expression is SimpleStringLiteral) {
        return expression.value;
      } else {
        warning(element, 'Name will be ignored, not a simple string literal');
      }
    }
  }

  return null;
}

String? _fieldNameFromArgumentList(ArgumentList list) {
  if (list.arguments.isEmpty) {
    return null;
  } else if (list.arguments.length > 1) {
    warning(list, 'Expected no more then 1 argument');
  }

  final argument = list.arguments[0];
  if (argument is! FunctionExpression) {
    warning(argument, 'The argument is not a function expression');
    return null;
  }

  final String? sourceName;
  final parameters = argument.parameters?.parameterElements.whereNotNull();
  if (parameters == null || parameters.isEmpty) {
    sourceName = null;
  } else {
    sourceName = parameters.firstOrNull?.name;
  }

  final body = argument.body;
  if (body is! ExpressionFunctionBody) {
    warning(body, 'The body is not a expression function');
    return null;
  }

  final expression = body.expression;
  if (expression is! PrefixedIdentifier) {
    warning(expression, 'The expression is not a prefixed identifier');
    return null;
  }

  if (sourceName != null && expression.prefix.toString() != sourceName) {
    warning(expression.prefix, 'The prefix is different from the source, expected $sourceName');
  }

  return expression.identifier.name;
}

ARLNode? _parseValidatorNode(Element invocation, ParserStepResult prevResult) {
  final args = invocation.argumentList.arguments;

  if (args.length != 1) {
    warning(invocation, 'Expected exactly one argument');
    return null;
  }

  final validatorType = args[0].staticType;
  if (validatorType == null) {
    error(args[0], 'Could not determine type of validator');
  }

  return ValidatorNode(
    invocation,
    validatorType: validatorType,
    child: prevResult.node,
    root: prevResult.root,
  );
}

ARLNode? _parseIterableNode(Element invocation, ParserStepResult prevResult, IterableCondition condition) {
  final args = invocation.argumentList.arguments;
  if (args.length != 1) {
    warning(invocation, 'Expected exactly one argument for the iterable rule');
    return null;
  }

  final arg = invocation.argumentList.arguments[0];
  if (arg is! FunctionExpression) {
    warning(arg, 'Expected a function expression');
    return null;
  }

  final body = arg.body;
  if (body is! ExpressionFunctionBody) {
    warning(body, 'Expected a expression function body');
    return null;
  }

  final ruleAst = body.expression;
  if (ruleAst is! Element) {
    warning(body, 'Expected a method invocation');
    return null;
  }

  return IterableNode(
    invocation,
    rule: _parseRule(ruleAst, true).node,
    condition: condition,
    child: prevResult.node,
    root: prevResult.root,
  );
}
