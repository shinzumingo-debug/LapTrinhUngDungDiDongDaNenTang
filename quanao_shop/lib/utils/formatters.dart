import 'package:intl/intl.dart';

String formatPrice(dynamic price) {
  if (price == null) return '0 VNĐ';
  num numValue = num.tryParse(price.toString()) ?? 0;
  final formatter = NumberFormat('#,###', 'en_US');
  return '${formatter.format(numValue)} VNĐ';
}