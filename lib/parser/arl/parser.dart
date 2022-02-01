part of 'arl.dart';

extension ElementExtension on Element {
  String get ruleMethodName => methodName.toString();
}

class ParserStepResult {
  final RootNode root;
  ARLNode node;

  ParserStepResult({required this.root, required this.node});
}

ARLNode parseRule(Element invocation) => _parseRule(invocation).node;

ParserStepResult _parseRule(Element invocation) {
  final target = invocation.realTarget;
  if (target is! Element) {
    if (target != null) {
      warning(target, 'The target should be a method invocation or null');
    }
    return _parseRootNode(invocation);
  }

  final prevResult = _parseRule(target);

  switch (invocation.ruleMethodName) {
    case 'notNull':
      return prevResult..node = NullCheckNode(invocation, root: prevResult.root, child: prevResult.node);

    default:
      warning(invocation, 'Unknown method');
      return prevResult;
  }
}

ParserStepResult _parseRootNode(Element invocation) {
  if (invocation.ruleMethodName != 'ruleFor') {
    final String? name;
    if (invocation.ruleMethodName == 'rule') {
      name = _ruleNameFromArgumentList(invocation.argumentList);
    } else {
      name = null;
      warning(invocation, 'Unknown root node');
    }

    final node = RootNode(invocation, name: name);
    return ParserStepResult(node: node, root: node);
  } else {
    final name = _ruleNameFromArgumentList(invocation.argumentList);
    final field = _fieldNameFromArgumentList(invocation.argumentList);

    final RootNode node;
    if (field != null) {
      node = FieldRootNode(invocation, fieldName: field, name: name);
    } else {
      node = RootNode(invocation, name: name);
    }

    return ParserStepResult(node: node, root: node);
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
