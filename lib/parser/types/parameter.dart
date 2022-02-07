part of 'types.dart';

mixin LConditionMixin {
  String? get ifCondition;

  bool get hasCondition => ifCondition != null;

  bool get hasNoCondition => ifCondition == null;

  bool availableForCondition(List<String?> conditions) => hasNoCondition || conditions.contains(ifCondition);
}

class LParameter with LConditionMixin {
  final String name;
  final LType type;

  @override
  final String? ifCondition;

  LParameter({
    required this.name,
    required this.type,
    required this.ifCondition,
  });
}
