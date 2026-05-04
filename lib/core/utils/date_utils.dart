import 'package:intl/intl.dart';

class AppDateUtils {
  AppDateUtils._();

  static final _dateFormat = DateFormat('dd MMM yyyy', 'id_ID');
  static final _dateTimeFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
  static final _folderDateFormat = DateFormat('yyyy-MM-dd');
  static final _timestampFormat = DateFormat('yyyyMMdd_HHmmss');

  static String formatDate(DateTime date) => _dateFormat.format(date);

  static String formatDateTime(DateTime dateTime) =>
      _dateTimeFormat.format(dateTime);

  static String toFolderDate(DateTime date) => _folderDateFormat.format(date);

  static String toTimestamp(DateTime dateTime) =>
      _timestampFormat.format(dateTime);

  static bool isDeadlinePassed(DateTime deadline) =>
      DateTime.now().isAfter(deadline);

  static int daysUntilDeadline(DateTime deadline) =>
      deadline.difference(DateTime.now()).inDays;
}
