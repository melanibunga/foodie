String formatRupiah(int amount) {
  final isNegative = amount < 0;
  final absVal = amount.abs().toString();
  final buffer = StringBuffer();

  for (int i = 0; i < absVal.length; i++) {
    if (i > 0 && (absVal.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(absVal[i]);
  }

  final prefix = isNegative ? '-Rp ' : 'Rp ';
  return '$prefix$buffer';
}
