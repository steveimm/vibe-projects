typedef MultiplierValue = ({String label, double factor, bool enabled});

String nextMultiplierName(Iterable<String> labels) {
  final existing = labels.toSet();
  var number = 1;
  while (existing.contains('Multiplier $number')) {
    number++;
  }
  return 'Multiplier $number';
}

void validateMultipliers(Iterable<MultiplierValue> values) {
  var product = 1.0;
  for (final value in values) {
    if (!value.factor.isFinite || value.factor <= 0 || value.factor > 100) {
      throw const FormatException('Use a multiplier greater than 0, up to 100.');
    }
    if (value.enabled) product *= value.factor;
  }
  if (!product.isFinite || product > 10000 || product < 0.0001) {
    throw const FormatException('Combined multiplier must be between 0.0001 and 10000.');
  }
}
