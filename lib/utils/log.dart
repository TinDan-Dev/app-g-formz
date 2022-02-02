import 'package:analyzer/dart/ast/ast.dart';

void warning(AstNode? cause, String msg) {
  if (cause != null) {
    print('''
    $msg @:

    ${cause.toSource()}
    ''');
  } else {
    print(msg);
  }
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
