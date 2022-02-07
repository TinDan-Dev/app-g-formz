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
      return ParserStepResult(root: _parseRootNode(target, invocation));
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

    case 'check':
    case 'match':
      return prevResult;

    default:
      warning(invocation, 'Unknown method');
      return prevResult;
  }
}

RootNode _parseRootNode(AstNode? target, Element invocation) {
  final name = _ruleNameFromArgumentList(invocation.argumentList);

  switch (invocation.ruleMethodName) {
    case 'ruleFor':
      final field = _fieldNameFromArgumentList(invocation.argumentList);

      if (field != null) {
        return FieldRootNode(invocation, fieldName: field, name: name);
      } else {
        continue fallback;
      }

    case 'ruleIf':
      final rules = _ifRulesFromArgumentList(invocation.argumentList);

      if (rules != null && rules.isNotEmpty) {
        return IfRootNode(invocation, rules: rules, name: name);
      } else {
        continue fallback;
      }

    fallback:
    case 'rule':
      return RootNode(invocation, name: name);
    default:
      warning(invocation, 'Unknown root node');
      continue fallback;
  }
}

String? _ruleNameFromArgumentList(ArgumentList list) {
  final expression = list.arguments
      .whereType<NamedExpression>()
      .firstWhereOrNull((e) => e.name.toString().startsWith('name'))
      ?.expression;
  if (expression is! SimpleStringLiteral) {
    return null;
  }

  return expression.value;
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

List<ARLNode>? _ifRulesFromArgumentList(ArgumentList list) {
  final expression = list.arguments
      .whereType<NamedExpression>()
      .firstWhereOrNull((e) => e.name.toString().startsWith('rules'))
      ?.expression;
  if (expression is! ListLiteral) {
    return null;
  }

  return expression.elements.whereType<Element>().map(parseRule).toList();
}

ARLNode? _parseValidatorNode(Element invocation, ParserStepResult prevResult) {
  final args = invocation.argumentList.arguments;

  if (args.length != 1) {
    warning(invocation, 'Expected exactly one argument');
    return null;
  }

  final validator = args[0].staticType?.element;
  if (validator is! ClassElement) {
    error(args[0], 'Could not determine type of validator');
  }

  return ValidatorNode(
    invocation,
    validator: validator,
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
