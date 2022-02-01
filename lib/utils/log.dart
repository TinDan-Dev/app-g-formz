import 'package:analyzer/dart/ast/ast.dart';

void warning(AstNode cause, String msg) {
  print('''
  $msg @:

  ${cause.toSource()}
  ''');
}

Never error(AstNode? cause, msg) {
  if (cause != null) {
    throw UnsupportedError('''
    $msg @:

    ${cause.toSource()}
    ''');
  } else {
    throw UnsupportedError(msg);
  }
}
