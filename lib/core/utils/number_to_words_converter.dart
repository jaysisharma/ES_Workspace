class NumberToWordsConverter {
  NumberToWordsConverter._();

  static const List<String> _units = [
    '',
    'One',
    'Two',
    'Three',
    'Four',
    'Five',
    'Six',
    'Seven',
    'Eight',
    'Nine',
    'Ten',
    'Eleven',
    'Twelve',
    'Thirteen',
    'Fourteen',
    'Fifteen',
    'Sixteen',
    'Seventeen',
    'Eighteen',
    'Nineteen',
  ];

  static const List<String> _tens = [
    '',
    '',
    'Twenty',
    'Thirty',
    'Forty',
    'Fifty',
    'Sixty',
    'Seventy',
    'Eighty',
    'Ninety',
  ];

  static String convertToRupees(double amount) {
    if (amount.isNaN || amount.isInfinite) return 'Zero Rupees Only';
    if (amount <= 0) return 'Rupees Zero Only';

    final int rupees = amount.floor();
    final int paisa = ((amount - rupees) * 100).round();

    String result = 'Rupees ${_convert(rupees)}';

    if (paisa > 0) {
      result += ' and ${_convert(paisa)} Paisa';
    }

    return '$result Only';
  }

  static String _convert(int n) {
    if (n == 0) return 'Zero';
    return _convertHelper(n).trim();
  }

  static String _convertHelper(int n) {
    if (n < 20) {
      return _units[n];
    }
    if (n < 100) {
      return '${_tens[n ~/ 10]} ${_units[n % 10]}'.trim();
    }
    if (n < 1000) {
      return '${_units[n ~/ 100]} Hundred ${_convertHelper(n % 100)}'.trim();
    }
    if (n < 100000) {
      return '${_convertHelper(n ~/ 1000)} Thousand ${_convertHelper(n % 1000)}'.trim();
    }
    if (n < 10000000) {
      return '${_convertHelper(n ~/ 100000)} Lakh ${_convertHelper(n % 100000)}'.trim();
    }
    return '${_convertHelper(n ~/ 10000000)} Crore ${_convertHelper(n % 10000000)}'.trim();
  }
}
