import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/visitor.dart';
import 'package:collection/collection.dart';
import 'package:formz/annotation.dart';
import 'package:source_gen/source_gen.dart';

import '../../../utils/log.dart';
import '../../../utils/utils.dart';
import '../../type.dart';
import '../method.dart';
import '../parameter.dart';
import '../parser.dart';
import '../rule.dart';

part 'extern_converter.dart';
part 'method_converter.dart';
part 'null_check_converter.dart';
part 'validator_converter.dart';

abstract class FieldConverterInfo extends ConverterInfo {
  final String fieldName;

  const FieldConverterInfo({
    required LType from,
    required LType to,
    required this.fieldName,
  }) : super(from: from, to: to);
}

abstract class ConverterInfo {
  final LType from;
  final LType to;

  const ConverterInfo({
    required this.from,
    required this.to,
  });
}
