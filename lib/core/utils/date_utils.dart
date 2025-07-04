import 'package:intl/intl.dart';

class AppDateUtils {
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy à HH:mm');
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _dayFormat = DateFormat('EEEE dd MMMM yyyy', 'fr_FR');

  /// Formate une date et heure complète
  static String formatDateTime(DateTime dateTime) {
    return _dateTimeFormat.format(dateTime);
  }

  /// Formate seulement la date
  static String formatDate(DateTime dateTime) {
    return _dateFormat.format(dateTime);
  }

  /// Formate seulement l'heure
  static String formatTime(DateTime dateTime) {
    return _timeFormat.format(dateTime);
  }

  /// Formate avec le nom du jour
  static String formatDayDate(DateTime dateTime) {
    return _dayFormat.format(dateTime);
  }

  /// Retourne une date relative (aujourd'hui, hier, etc.)
  static String formatRelativeDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (dateOnly == today) {
      return 'Aujourd\'hui à ${formatTime(dateTime)}';
    } else if (dateOnly == yesterday) {
      return 'Hier à ${formatTime(dateTime)}';
    } else if (now.difference(dateTime).inDays < 7) {
      return '${_getDayName(dateTime.weekday)} à ${formatTime(dateTime)}';
    } else {
      return formatDateTime(dateTime);
    }
  }

  /// Retourne le temps écoulé depuis une date
  static String formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'À l\'instant';
    } else if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else {
      return formatDate(dateTime);
    }
  }

  /// Retourne la durée entre deux dates
  static String formatDuration(DateTime start, DateTime end) {
    final duration = end.difference(start);
    
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes} min';
    } else if (duration.inHours < 24) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      return '${hours}h${minutes > 0 ? ' ${minutes}min' : ''}';
    } else {
      final days = duration.inDays;
      final hours = duration.inHours % 24;
      return '${days} jour${days > 1 ? 's' : ''}${hours > 0 ? ' ${hours}h' : ''}';
    }
  }

  /// Vérifie si une date est aujourd'hui
  static bool isToday(DateTime dateTime) {
    final now = DateTime.now();
    return dateTime.year == now.year &&
           dateTime.month == now.month &&
           dateTime.day == now.day;
  }

  /// Vérifie si une date est hier
  static bool isYesterday(DateTime dateTime) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return dateTime.year == yesterday.year &&
           dateTime.month == yesterday.month &&
           dateTime.day == yesterday.day;
  }

  /// Retourne le nom du jour en français
  static String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'Lundi';
      case 2: return 'Mardi';
      case 3: return 'Mercredi';
      case 4: return 'Jeudi';
      case 5: return 'Vendredi';
      case 6: return 'Samedi';
      case 7: return 'Dimanche';
      default: return '';
    }
  }

  /// Ajoute des jours ouvrables à une date
  static DateTime addBusinessDays(DateTime date, int days) {
    DateTime result = date;
    int addedDays = 0;
    
    while (addedDays < days) {
      result = result.add(const Duration(days: 1));
      if (result.weekday < 6) { // Lundi à Vendredi
        addedDays++;
      }
    }
    
    return result;
  }

  /// Retourne le début de la journée
  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Retourne la fin de la journée
  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  /// Retourne le début de la semaine (lundi)
  static DateTime startOfWeek(DateTime date) {
    final daysFromMonday = date.weekday - 1;
    return startOfDay(date.subtract(Duration(days: daysFromMonday)));
  }

  /// Retourne la fin de la semaine (dimanche)
  static DateTime endOfWeek(DateTime date) {
    final daysToSunday = 7 - date.weekday;
    return endOfDay(date.add(Duration(days: daysToSunday)));
  }
}