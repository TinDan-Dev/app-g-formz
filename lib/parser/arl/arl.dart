import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../../utils/log.dart';

part 'parser.dart';

typedef Element = MethodInvocation;

/// Abstract rule list node :)
abstract class ARLNode {
  /// The root node, or null if this is the root node.
  RootNode get root;

  /// The child node, or null if this is the root node.
  ARLNode? get child;

  /// The method that node refers to.
  final AstNode element;

  const ARLNode(this.element);

  @mustCallSuper
  void visit<T>(ARLVisitor<T> visitor, T args);
}

/// The root node, marks the start of a rule.
class RootNode extends ARLNode {
  @override
  RootNode get root => this;

  @override
  ARLNode? get child => null;

  /// The name of the rule, if the rule has a name.
  final String? name;

  const RootNode(AstNode element, {this.name}) : super(element);

  @override
  void visit<T>(ARLVisitor<T> visitor, T args) => visitor.visitRootNode(this, args);
}

/// If the root node accesses one specific field from the source.
class FieldRootNode extends RootNode {
  /// The name of the accessed field.
  final String fieldName;

  const FieldRootNode(AstNode element, {String? name, required this.fieldName}) : super(element, name: name);

  @override
  void visit<T>(ARLVisitor<T> visitor, T args) {
    visitor.visitFieldRootNode(this, args);
    super.visit(visitor, args);
  }
}

/// A node that is attached to a root node or another attached node.
class AttachedNode extends ARLNode {
  @override
  final ARLNode child;

  @override
  final RootNode root;

  const AttachedNode(Element element, {required this.child, required this.root}) : super(element);

  @override
  void visit<T>(ARLVisitor<T> visitor, T args) {
    visitor.visitAttachedNode(this, args);
    child.visit(visitor, args);
  }

  @override
  Element get element => super.element as Element;

  /// The name of the method, retrieved from the element.
  String get methodName => element.ruleMethodName;
}

/// A node that checks that the input is not null.
class NullCheckNode extends AttachedNode {
  const NullCheckNode(Element element, {required ARLNode child, required RootNode root})
      : super(element, child: child, root: root);

  @override
  void visit<T>(ARLVisitor<T> visitor, T args) {
    visitor.visitNullCheckNode(this, args);
    super.visit(visitor, args);
  }
}

class ValidatorNode extends AttachedNode {
  final DartType validatorType;

  const ValidatorNode(
    Element element, {
    required this.validatorType,
    required ARLNode child,
    required RootNode root,
  }) : super(element, child: child, root: root);

  @override
  void visit<T>(ARLVisitor<T> visitor, T args) {
    visitor.visitValidatorNode(this, args);
    super.visit(visitor, args);
  }
}

enum IterableCondition { every, any, none }

class IterableRootNode extends RootNode {
  IterableRootNode(AstNode element) : super(element);

  @override
  void visit<T>(ARLVisitor<T> visitor, T args) {
    visitor.visitIterableRootNode(this, args);
    super.visit(visitor, args);
  }
}

class IterableNode extends AttachedNode {
  final ARLNode rule;
  final IterableCondition condition;

  const IterableNode(
    Element element, {
    required this.rule,
    required this.condition,
    required ARLNode child,
    required RootNode root,
  }) : super(element, child: child, root: root);

  @override
  void visit<T>(ARLVisitor<T> visitor, T args) {
    visitor.visitIterableNode(this, args);
    super.visit(visitor, args);
  }
}

/// A visitor that can walk down the ARL.
abstract class ARLVisitor<T> {
  void visitRootNode(RootNode node, T args);

  void visitFieldRootNode(FieldRootNode node, T args);

  void visitIterableRootNode(IterableRootNode node, T args);

  void visitAttachedNode(AttachedNode node, T args);

  void visitNullCheckNode(NullCheckNode node, T args);

  void visitValidatorNode(ValidatorNode node, T args);

  void visitIterableNode(IterableNode node, T args);
}
