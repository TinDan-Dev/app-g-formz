import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';

import '../../utils/log.dart';
import '../../utils/utils.dart';
import '../arl/arl.dart';

List<Rule> analyzeRules(ClassElement element) {
  final ast = getAstNodeFromElement(element);
  if (ast == null) {
    error(null, 'Class ast node was not found');
  }

  if (ast is! ClassDeclaration) {
    error(ast, 'Expected class declaration, but found: ${ast.runtimeType}');
  }

  final rulesMethod = ast.getMethod('rules');
  if (rulesMethod == null) {
    error(ast, 'Could not find rules method/property');
  }

  final body = rulesMethod.body;
  if (body is! ExpressionFunctionBody) {
    error(body, 'The rules method/property should be a expression to list, like => []');
  }

  final expression = body.expression;
  if (expression is! ListLiteral) {
    error(expression, 'The rules method/property should be a expression to list, like => []');
  }

  final rules = <Rule>[];
  for (final element in expression.elements) {
    if (element is MethodInvocation) {
      final node = parseRule(element);
      rules.add(Rule.fromARL(node));
    }
  }

  return rules;
}

class Rule {
  /// The end node for this rule.
  final ARLNode node;

  /// The total amount of nodes used in this rule.
  final int nodeCount;

  /// The name of the rule, if one was found.
  final String? name;

  /// The name of the field for this rule, if one was found.
  final String? fieldName;

  /// Whether this rule includes a null check or not.
  final bool nullChecked;

  Rule._({
    required this.node,
    required this.nodeCount,
    required this.name,
    required this.fieldName,
    required this.nullChecked,
  });

  factory Rule.fromARL(ARLNode node) {
    final analyzer = RuleAnalyzer();
    node.visit(analyzer, null);

    return Rule._(
      node: node,
      nodeCount: analyzer.nodeCount,
      name: analyzer.name,
      fieldName: analyzer.fieldName,
      nullChecked: analyzer.nullChecked,
    );
  }
}

class RuleAnalyzer extends ARLVisitor<void> {
  int nodeCount;

  String? name;
  String? fieldName;

  bool nullChecked;

  RuleAnalyzer()
      : nodeCount = 0,
        nullChecked = false;

  @override
  void visitAttachedNode(AttachedNode node, void args) {
    nodeCount++;
  }

  @override
  void visitRootNode(RootNode node, void args) {
    nodeCount++;

    name = node.name;
  }

  @override
  void visitFieldRootNode(FieldRootNode node, void args) {
    fieldName = node.fieldName;
  }

  @override
  void visitNullCheckNode(NullCheckNode node, void args) {
    if (nullChecked) {
      warning(node.element, 'Unnecessary null check');
    }

    nullChecked = true;
  }
}
