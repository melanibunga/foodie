/// Utilitas kalkulasi dan pemformatan tanggal minggu sesuai PRD §9 & §12.
abstract final class WeekUtils {
  static const List<String> monthNamesShort = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  static const List<String> dayNames = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  /// Mengembalikan tanggal hari Senin untuk minggu yang memuat [date].
  static DateTime getWeekStart(DateTime date) {
    final cleanDate = DateTime(date.year, date.month, date.day);
    final diff = cleanDate.weekday - DateTime.monday;
    return cleanDate.subtract(Duration(days: diff));
  }

  /// Mengembalikan 7 hari dalam minggu (Senin s.d. Minggu).
  static List<DateTime> getWeekDays(DateTime weekStart) {
    final monday = DateTime(weekStart.year, weekStart.month, weekStart.day);
    return List.generate(7, (index) => monday.add(Duration(days: index)));
  }

  /// Format tanggal ke kunci YYYY-MM-DD
  static String formatDateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Parse YYYY-MM-DD ke DateTime
  static DateTime parseDateKey(String key) {
    final parts = key.split('-');
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]) ?? 2026;
      final m = int.tryParse(parts[1]) ?? 1;
      final d = int.tryParse(parts[2]) ?? 1;
      return DateTime(y, m, d);
    }
    return DateTime.now();
  }

  /// Label minggu: "This Week", "Last Week", "Next Week", atau "10–16 Nov"
  static String getWeekLabel(DateTime weekStart, [DateTime? referenceDate]) {
    final now = referenceDate ?? DateTime.now();
    final currentWeekStart = getWeekStart(now);
    final diffDays = weekStart.difference(currentWeekStart).inDays;

    if (diffDays == 0) {
      return 'This Week';
    } else if (diffDays == -7) {
      return 'Last Week';
    } else if (diffDays == 7) {
      return 'Next Week';
    }

    final endDay = weekStart.add(const Duration(days: 6));
    final startMonth = monthNamesShort[weekStart.month - 1];
    final endMonth = monthNamesShort[endDay.month - 1];

    if (weekStart.month == endDay.month) {
      return '${weekStart.day}–${endDay.day} $endMonth';
    } else {
      return '${weekStart.day} $startMonth – ${endDay.day} $endMonth';
    }
  }
}
