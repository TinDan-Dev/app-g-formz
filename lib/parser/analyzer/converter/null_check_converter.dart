part of 'converter.dart';

class NullCheckConverterInfo extends FieldConverterInfo {
  NullCheckConverterInfo({
    required String fieldName,
    required LType type,
  }) : super(
          fieldName: fieldName,
          from: type,
          to: type.copyWith(nullable: () => false),
        );
}

class IterableNullCheckConverterInfo extends FieldConverterInfo implements NullCheckConverterInfo {
  IterableNullCheckConverterInfo({
    required String fieldName,
    required LType type,
  }) : super(
          fieldName: fieldName,
          from: type,
          to: type.copyWith(typeArguments: () => [type.typeArguments[0].copyWith(nullable: () => false)]),
        );
}

Iterable<FieldConverterInfo> nullCheckConverterFromRules(
  LibraryContext ctx,
  ParserInfo info,
  Iterable<Rule> rules,
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
      yield NullCheckConverterInfo(fieldName: rule.fieldName!, type: ctx.resolveLType(field.type));
    }
    if (rule.iterableRule != null && rule.iterableRule!.nullChecked) {
      yield IterableNullCheckConverterInfo(fieldName: rule.fieldName!, type: ctx.resolveLType(field.type));
    }
  }
}
