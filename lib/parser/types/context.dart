part of 'types.dart';

class BuildContext {
  final LibraryContext libCtx;
  final ParserInfo info;
  final Allocate allocate;
  final List<Rule> rules;
  final List<String> conditions;

  const BuildContext._({
    required this.libCtx,
    required this.info,
    required this.rules,
    required this.allocate,
    required this.conditions,
  });

  const BuildContext({
    required this.libCtx,
    required this.info,
    required this.rules,
    required this.allocate,
  }) : conditions = const [];

  BuildContext withCondition(List<String> conditions) {
    return BuildContext._(
      libCtx: libCtx,
      info: info,
      rules: rules,
      allocate: allocate,
      conditions: conditions + this.conditions,
    );
  }

  int getIndexOfRuleForCondition(String condition) {
    final rule = rules.firstWhereOrNull((e) => e.ifCondition == condition);
    if (rule == null) {
      error(null, 'Could not find rule for condition: $condition');
    }

    return rule.index;
  }
}
