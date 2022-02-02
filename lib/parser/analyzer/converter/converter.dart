import 'package:analyzer/dart/element/type.dart';
import 'package:code_builder/code_builder.dart';

import '../../../utils/utils.dart';
import '../parameter.dart';

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

typedef Allocate = String Function(Reference);

typedef AllocateBody = String Function(LibraryContext ctx, Allocate allocate);

abstract class MethodConverterWriteInfo {
  DartType get to;
  String get methodName;

  List<MethodParameter> get methodParameters;

  AllocateBody? get body;
}
