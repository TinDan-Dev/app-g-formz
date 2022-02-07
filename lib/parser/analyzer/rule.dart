import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:collection/collection.dart';

import '../../parser/types/types.dart';
import '../../utils/log.dart';
import '../arl/arl.dart';

List<Rule> analyzeRules(AstNode? ast) {
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
  for (int i = 0; i < expression.elements.length; i++) {
    final element = expression.elements[i];
    if (element is MethodInvocation) {
      final node = parseRule(element);
      rules.add(Rule.fromARL(node, i));
    }
  }

  return rules;
}

class Rule with LConditionMixin {
  /// The index of this rule.
  final int index;

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

  /// The type of the validator used in this rule, if one was found.
  final ClassElement? validator;

  /// The rule of the iterable, if one was found.
  final Rule? iterableRule;

  /// The condition of the iterable, if one was found.
  final IterableCondition? iterableCondition;

  /// Whether this is a rule inside of an iterable.
  final bool inIterable;

  /// If this rule is an if rule, theses are the rules that should be valid
  /// if the condition holds.
  final List<Rule> ifRules;

  Rule._({
    required this.index,
    required this.node,
    required this.nodeCount,
    required this.name,
    required this.fieldName,
    required this.nullChecked,
    required this.validator,
    required this.iterableCondition,
    required this.inIterable,
    required this.iterableRule,
    required this.ifRules,
  });

  factory Rule.fromARL(ARLNode node, int index) {
    final analyzer = RuleAnalyzer();
    node.visit(analyzer, null);

    return Rule._(
      index: index,
      node: node,
      nodeCount: analyzer.nodeCount,
      name: analyzer.name,
      fieldName: analyzer.fieldName,
      nullChecked: analyzer.nullChecked,
      validator: analyzer.validator,
      inIterable: analyzer.inIterable,
      iterableCondition: analyzer.iterableCondition,
      iterableRule: analyzer.iterableRule,
      ifRules: analyzer.ifRules,
    );
  }

  /// Whether this is an if rule.
  bool get isIfRule => ifRules.isNotEmpty;

  /// The name of the if condition if this rule is an if rule.
  @override
  String? get ifCondition => isIfRule ? name : null;
}

class RuleAnalyzer extends ARLVisitor<void> {
  int nodeCount;

  String? name;
  String? fieldName;

  bool nullChecked;
  bool inIterable;

  ClassElement? validator;

  Rule? iterableRule;
  IterableCondition? iterableCondition;

  List<Rule> ifRules;

  RuleAnalyzer()
      : ifRules = [],
        nodeCount = 0,
        nullChecked = false,
        inIterable = false;

  @override
  void visitAttachedNode(AttachedNode node, void args) {
    if (ifRules.isNotEmpty) {
      warning(node.element, 'Do not append any rules to an if rule');
    }

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

  @override
  void visitValidatorNode(ValidatorNode node, void args) {
    if (validator != null) {
      warning(node.element, 'Seconde validator will be ignored, use a new rule for each validator');
      return;
    }

    validator = node.validator;
  }

  @override
  void visitIterableNode(IterableNode node, void args) {
    if (iterableRule != null) {
      warning(node.element, 'Seconde iterable rule will be ignored, use a new rule for each iterable rule');
      return;
    }

    iterableRule = Rule.fromARL(node.rule, 0);
    iterableCondition = node.condition;
  }

  @override
  void visitIterableRootNode(IterableRootNode node, void args) {
    inIterable = true;
  }

  @override
  void visitIfRootNode(IfRootNode node, void args) {
    ifRules = node.rules.mapIndexed((i, e) => Rule.fromARL(e, i)).toList();
  }
}
