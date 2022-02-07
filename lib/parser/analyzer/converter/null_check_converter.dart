part of 'converter.dart';

class NullCheckConverterInfo extends FieldConverterInfo {
  NullCheckConverterInfo({
    required String fieldName,
    required LType type,
    required String? ifCondition,
  }) : super(
          fieldName: fieldName,
          from: type,
          to: type.copyWith(nullable: () => false),
          ifCondition: ifCondition,
        );
}

class IterableNullCheckConverterInfo extends FieldConverterInfo implements NullCheckConverterInfo {
  IterableNullCheckConverterInfo({
    required String fieldName,
    required LType type,
    required String? ifCondition,
  }) : super(
          fieldName: fieldName,
          from: type,
          to: type.copyWith(typeArguments: () => [type.typeArguments[0].copyWith(nullable: () => false)]),
          ifCondition: ifCondition,
        );
}

Iterable<FieldConverterInfo> analyzeNullCheckConverter(
  LibraryContext ctx,
  ParserInfo info,
  Iterable<Rule> rules,
  String? ifCondition,
) sync* {
  for (final rule in rules) {
    final fieldName = rule.fieldName;
    if (fieldName == null) continue;

    final field = info.source.getField(fieldName);
    if (field == null) {
      warning(null, 'Source has no field $fieldName');
      continue;
    }

    if (rule.nullChecked) {
      yield NullCheckConverterInfo(
        fieldName: fieldName,
        type: ctx.resolveLType(field.type),
        ifCondition: ifCondition,
      );
    }
    if (rule.iterableRule != null && rule.iterableRule!.nullChecked) {
      yield IterableNullCheckConverterInfo(
        fieldName: fieldName,
        type: ctx.resolveLType(field.type),
        ifCondition: ifCondition,
      );
    }

    if (rule.hasCondition) {
      if (ifCondition != null) {
        error(null, 'Nested if conditions are not supported');
      }

      yield* analyzeNullCheckConverter(ctx, info, rule.ifRules, rule.ifCondition);
    }
  }
}
