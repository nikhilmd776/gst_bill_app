String numberToWords(int number) {
  if (number == 0) return 'Zero';
  const List<String> ones = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
    'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
    'Seventeen', 'Eighteen', 'Nineteen'
  ];
  const List<String> tens = [
    '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
  ];
  String word = '';
  if (number >= 10000000) {
    word += '${numberToWords(number ~/ 10000000)} Crore ';
    number %= 10000000;
  }
  if (number >= 100000) {
    word += '${numberToWords(number ~/ 100000)} Lakh ';
    number %= 100000;
  }
  if (number >= 1000) {
    word += '${numberToWords(number ~/ 1000)} Thousand ';
    number %= 1000;
  }
  if (number >= 100) {
    word += '${ones[number ~/ 100]} Hundred ';
    number %= 100;
  }
  if (number > 0) {
    if (number < 20) {
      word += ones[number];
    } else {
      word += tens[number ~/ 10];
      if (number % 10 > 0) word += ' ${ones[number % 10]}';
    }
  }
  return word.trim();
}