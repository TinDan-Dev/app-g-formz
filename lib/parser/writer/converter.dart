abstract class ArgumentConverter {
  const ArgumentConverter();

  int get priority;

  String apply(String parameter);
}

class NullCheckConverter extends ArgumentConverter {
  const NullCheckConverter();

  @override
  int get priority => 0;

  @override
  String apply(String parameter) => '$parameter!';
}
