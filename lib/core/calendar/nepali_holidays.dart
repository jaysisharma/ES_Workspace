import 'package:nepali_utils/nepali_utils.dart';

class NepaliHolidayInfo {
  final String nameEnglish;
  final String nameNepali;
  final bool isPublicHoliday;

  const NepaliHolidayInfo({
    required this.nameEnglish,
    required this.nameNepali,
    this.isPublicHoliday = true,
  });
}

/// Official Nepali Holidays, Festivals, and Saturday detection engine.
class NepaliHolidays {
  NepaliHolidays._();

  /// Recurring fixed BS holidays mapped by month and day (MM-DD)
  static const Map<String, NepaliHolidayInfo> _fixedBsHolidays = {
    '01-01': NepaliHolidayInfo(
      nameEnglish: 'Nepali New Year (Nawa Barsha)',
      nameNepali: 'नयाँ वर्ष (बैशाख १)',
      isPublicHoliday: true,
    ),
    '01-18': NepaliHolidayInfo(
      nameEnglish: 'International Labor Day',
      nameNepali: 'मजदुर दिवस',
      isPublicHoliday: true,
    ),
    '06-03': NepaliHolidayInfo(
      nameEnglish: 'Constitution Day (Samvidhan Diwas)',
      nameNepali: 'संविधान दिवस',
      isPublicHoliday: true,
    ),
    '09-27': NepaliHolidayInfo(
      nameEnglish: 'National Unity Day (Prithvi Jayanti)',
      nameNepali: 'पृथ्वी जयन्ती / राष्ट्रिय एकता दिवस',
      isPublicHoliday: true,
    ),
    '10-16': NepaliHolidayInfo(
      nameEnglish: 'Martyrs Day (Sahid Diwas)',
      nameNepali: 'शहीद दिवस',
      isPublicHoliday: true,
    ),
    '11-07': NepaliHolidayInfo(
      nameEnglish: 'National Democracy Day (Prajatantra Diwas)',
      nameNepali: 'राष्ट्रिय प्रजातन्त्र दिवस',
      isPublicHoliday: true,
    ),
  };

  /// Specific year BS holiday mappings (e.g. 2081, 2082 BS) for lunar festivals
  static const Map<String, NepaliHolidayInfo> _specificYearHolidays = {
    // 2081 BS
    '2081-02-10': NepaliHolidayInfo(nameEnglish: 'Buddha Jayanti / Ubhauli', nameNepali: 'बुद्ध जयन्ती', isPublicHoliday: true),
    '2081-05-03': NepaliHolidayInfo(nameEnglish: 'Janai Purnima / Raksha Bandhan', nameNepali: 'जनै पूर्णिमा', isPublicHoliday: true),
    '2081-05-10': NepaliHolidayInfo(nameEnglish: 'Gai Jatra', nameNepali: 'गाईजात्रा', isPublicHoliday: false),
    '2081-05-11': NepaliHolidayInfo(nameEnglish: 'Krishna Janmashtami', nameNepali: 'कृष्ण जन्माष्टमी', isPublicHoliday: true),
    '2081-05-21': NepaliHolidayInfo(nameEnglish: 'Haritalika Teej', nameNepali: 'हरितालिका तीज', isPublicHoliday: true),
    '2081-06-17': NepaliHolidayInfo(nameEnglish: 'Ghatasthapana (Dashain Starts)', nameNepali: 'घटस्थापना', isPublicHoliday: true),
    '2081-06-24': NepaliHolidayInfo(nameEnglish: 'Maha Saptami (Fulpati)', nameNepali: 'फूलपाती', isPublicHoliday: true),
    '2081-06-25': NepaliHolidayInfo(nameEnglish: 'Maha Ashtami', nameNepali: 'महाअष्टमी', isPublicHoliday: true),
    '2081-06-26': NepaliHolidayInfo(nameEnglish: 'Maha Navami', nameNepali: 'महानवमी', isPublicHoliday: true),
    '2081-06-27': NepaliHolidayInfo(nameEnglish: 'Vijaya Dashami (Tika)', nameNepali: 'विजया दशमी', isPublicHoliday: true),
    '2081-07-15': NepaliHolidayInfo(nameEnglish: 'Laxmi Puja (Tihar)', nameNepali: 'लक्ष्मी पूजा', isPublicHoliday: true),
    '2081-07-16': NepaliHolidayInfo(nameEnglish: 'Govardhan Puja / Mha Puja', nameNepali: 'गोवर्धन पूजा / म्ह पूजा', isPublicHoliday: true),
    '2081-07-17': NepaliHolidayInfo(nameEnglish: 'Bhai Tika (Tihar)', nameNepali: 'भाइटीका', isPublicHoliday: true),
    '2081-07-22': NepaliHolidayInfo(nameEnglish: 'Chhath Parva', nameNepali: 'छठ पर्व', isPublicHoliday: true),
    '2081-11-14': NepaliHolidayInfo(nameEnglish: 'Maha Shivaratri', nameNepali: 'महाशिवरात्रि', isPublicHoliday: true),
    '2081-11-29': NepaliHolidayInfo(nameEnglish: 'Fagu Purnima (Holi - Hilly)', nameNepali: 'फागु पूर्णिमा (होली)', isPublicHoliday: true),
    '2081-11-30': NepaliHolidayInfo(nameEnglish: 'Fagu Purnima (Holi - Terai)', nameNepali: 'होली (तराई)', isPublicHoliday: true),

    // 2082 BS
    '2082-01-29': NepaliHolidayInfo(nameEnglish: 'Buddha Jayanti', nameNepali: 'बुद्ध जयन्ती', isPublicHoliday: true),
    '2082-05-23': NepaliHolidayInfo(nameEnglish: 'Gai Jatra', nameNepali: 'गाईजात्रा', isPublicHoliday: false),
    '2082-05-24': NepaliHolidayInfo(nameEnglish: 'Krishna Janmashtami', nameNepali: 'कृष्ण जन्माष्टमी', isPublicHoliday: true),
    '2082-06-08': NepaliHolidayInfo(nameEnglish: 'Haritalika Teej', nameNepali: 'हरितालिका तीज', isPublicHoliday: true),
    '2082-07-04': NepaliHolidayInfo(nameEnglish: 'Ghatasthapana', nameNepali: 'घटस्थापना', isPublicHoliday: true),
    '2082-07-11': NepaliHolidayInfo(nameEnglish: 'Fulpati (Dashain)', nameNepali: 'फूलपाती', isPublicHoliday: true),
    '2082-07-12': NepaliHolidayInfo(nameEnglish: 'Maha Ashtami', nameNepali: 'महाअष्टमी', isPublicHoliday: true),
    '2082-07-13': NepaliHolidayInfo(nameEnglish: 'Maha Navami', nameNepali: 'महानवमी', isPublicHoliday: true),
    '2082-07-14': NepaliHolidayInfo(nameEnglish: 'Vijaya Dashami', nameNepali: 'विजया दशमी', isPublicHoliday: true),
    '2082-08-03': NepaliHolidayInfo(nameEnglish: 'Laxmi Puja (Tihar)', nameNepali: 'लक्ष्मी पूजा', isPublicHoliday: true),
    '2082-08-04': NepaliHolidayInfo(nameEnglish: 'Govardhan Puja', nameNepali: 'गोवर्धन पूजा', isPublicHoliday: true),
    '2082-08-05': NepaliHolidayInfo(nameEnglish: 'Bhai Tika', nameNepali: 'भाइटीका', isPublicHoliday: true),
    '2082-08-10': NepaliHolidayInfo(nameEnglish: 'Chhath Parva', nameNepali: 'छठ पर्व', isPublicHoliday: true),
    '2082-11-04': NepaliHolidayInfo(nameEnglish: 'Maha Shivaratri', nameNepali: 'महाशिवरात्रि', isPublicHoliday: true),
    '2082-11-19': NepaliHolidayInfo(nameEnglish: 'Fagu Purnima (Holi)', nameNepali: 'होली पर्व', isPublicHoliday: true),
  };

  /// Returns true if the given BS date is a Saturday (Sanibar).
  static bool isSaturday(NepaliDateTime date) {
    // In nepali_utils: 7 = Saturday
    return date.weekday == 7;
  }

  /// Looks up holiday information for a given BS date.
  static NepaliHolidayInfo? getHoliday(NepaliDateTime date) {
    final yearKey = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    if (_specificYearHolidays.containsKey(yearKey)) {
      return _specificYearHolidays[yearKey];
    }

    final monthDayKey = '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    if (_fixedBsHolidays.containsKey(monthDayKey)) {
      return _fixedBsHolidays[monthDayKey];
    }

    return null;
  }

  /// Returns true if the given BS date is an official public holiday.
  static bool isPublicHoliday(NepaliDateTime date) {
    if (isSaturday(date)) return true;
    final holiday = getHoliday(date);
    return holiday != null && holiday.isPublicHoliday;
  }
}
