import 'package:analyzer/dart/element/type.dart';

abstract class FieldConverterInfo extends ConverterInfo {
  final String fieldName;

  const FieldConverterInfo({
    required DartType from,
    required DartType to,
    required this.fieldName,
  }) : super(from: from, to: to);
}

abstract class ConverterInfo {
  final DartType from;
  final DartType to;

  const ConverterInfo({
    required this.from,
    required this.to,
  });
}
