import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String englishLanguage = 'English';
const String filipinoLanguage = 'Filipino';

const _appLanguageKey = 'app_language';
const _legacyCustomerLanguageKey = 'customer_app_language';

final ValueNotifier<String> appLanguageNotifier = ValueNotifier(
  englishLanguage,
);

bool get isAppLanguageFilipino => appLanguageNotifier.value == filipinoLanguage;

Future<void> initializeAppLanguage() async {
  try {
    final preferences = await SharedPreferences.getInstance();
    final savedLanguage =
        preferences.getString(_appLanguageKey) ??
        preferences.getString(_legacyCustomerLanguageKey) ??
        englishLanguage;
    appLanguageNotifier.value = savedLanguage == filipinoLanguage
        ? filipinoLanguage
        : englishLanguage;
  } catch (_) {
    appLanguageNotifier.value = englishLanguage;
  }
}

Future<void> setAppLanguage(String value) async {
  final language = value == filipinoLanguage
      ? filipinoLanguage
      : englishLanguage;
  appLanguageNotifier.value = language;
  try {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_appLanguageKey, language);
    await preferences.setString(_legacyCustomerLanguageKey, language);
  } catch (_) {}
}

String appText(String english, [String? filipino]) {
  if (!isAppLanguageFilipino) return english;
  if (filipino != null && filipino.trim().isNotEmpty) return filipino;
  return _translateToFilipino(english);
}

String _translateToFilipino(String value) {
  final exact = _filipinoTranslations[value];
  if (exact != null) return exact;

  final welcomeMatch = RegExp(r'^Welcome,\s*(.+)$').firstMatch(value);
  if (welcomeMatch != null) {
    return 'Maligayang pagdating, ${welcomeMatch.group(1)}';
  }

  final positionMatch = RegExp(
    r'^Position\s+(\d+)\s+in line$',
  ).firstMatch(value);
  if (positionMatch != null) {
    return 'Pang-${positionMatch.group(1)} sa pila';
  }

  final queueMatch = RegExp(r'^Queue\s+(.+)$').firstMatch(value);
  if (queueMatch != null) return 'Numero sa pila ${queueMatch.group(1)}';

  final recordsMatch = RegExp(r'^(\d+) records?$').firstMatch(value);
  if (recordsMatch != null) return '${recordsMatch.group(1)} tala';

  return value;
}

const Map<String, String> _filipinoTranslations = {
  'Account Login': 'Pag-login sa Account',
  'Account Settings': 'Mga Setting ng Account',
  'Admin Appointment Dashboard': 'Dashboard ng Appointment ng Admin',
  'Admin Control Panel': 'Control Panel ng Admin',
  'Admin Login': 'Pag-login ng Admin',
  'Admin Settings': 'Mga Setting ng Admin',
  'Analytics': 'Pagsusuri',
  'Appointment Availability': 'Mga Available na Appointment',
  'Appointment Confirmation': 'Kumpirmasyon ng Appointment',
  'Appointment Details': 'Detalye ng Appointment',
  'Appointment Notifications': 'Mga Abiso sa Appointment',
  'Appointment Overview': 'Buod ng mga Appointment',
  'Appointment Policy': 'Patakaran sa Appointment',
  'Appointment Reminders': 'Mga Paalala sa Appointment',
  'Appointments': 'Mga Appointment',
  'Approved': 'Naaprubahan',
  'Approved Customers': 'Mga Naaprubahang Customer',
  'BACK': 'BUMALIK',
  'Book Appointment': 'Mag-book ng Appointment',
  'CANCEL': 'KANSELAHIN',
  'CHECK': 'TINGNAN',
  'CHOOSE ANOTHER SLOT': 'PUMILI NG IBANG ORAS',
  'CLOSE': 'ISARA',
  'Change': 'Palitan',
  'Change Date': 'Palitan ang Petsa',
  'Completed': 'Tapos Na',
  'CONTINUE AS WALK-IN': 'MAGPATULOY BILANG WALK-IN',
  'CONTINUE WITH GOOGLE': 'MAGPATULOY GAMIT ANG GOOGLE',
  'Create Account': 'Gumawa ng Account',
  'Customer Home': 'Home ng Customer',
  'Customer Portal': 'Portal ng Customer',
  'Customer Registration': 'Pagrehistro ng Customer',
  'Customer Settings': 'Mga Setting ng Customer',
  'Daily Queue Limit': 'Araw-araw na Limitasyon ng Pila',
  'Daily Report': 'Araw-araw na Ulat',
  'Date': 'Petsa',
  'DELETE': 'BURAHIN',
  'DIESEL': 'DIESEL',
  'Display Page': 'Pahina ng Display',
  'Document Retention': 'Pagpapanatili ng Dokumento',
  'DOWNLOAD': 'I-DOWNLOAD',
  'Edit': 'I-edit',
  'Email': 'Email',
  'English': 'English',
  'Failed': 'Bagsak',
  'Fast': 'Mabilis',
  'Filipino': 'Filipino',
  'Forgot Password?': 'Nakalimutan ang Password?',
  'Full name': 'Buong pangalan',
  'GAS': 'GAS',
  'Generate Queue': 'Gumawa ng Numero sa Pila',
  'I UNDERSTAND': 'NAUUNAWAAN KO',
  'In-app appointment reminders': 'Mga paalala sa appointment sa app',
  'Line graph': 'Line graph',
  'Loading analytics...': 'Kinukuha ang pagsusuri...',
  'Loading queue display...': 'Kinukuha ang display ng pila...',
  'Loading report records...': 'Kinukuha ang mga tala ng ulat...',
  'LOG OUT': 'MAG-LOG OUT',
  'Log out?': 'Mag-log out?',
  'LOGIN': 'MAG-LOGIN',
  'Login or Create Account': 'Mag-login o Gumawa ng Account',
  'Manual 365-Day Retention Cleanup': 'Manwal na 365-Araw na Cleanup',
  'Monthly Report': 'Buwanang Ulat',
  'Monthly Trend': 'Buwanang Takbo',
  'My Appointment Status': 'Status ng Aking Appointment',
  'Name': 'Pangalan',
  'New email address': 'Bagong email address',
  'No account yet?': 'Wala pang account?',
  'No appointment found': 'Walang nakitang appointment',
  'No current notifications': 'Walang bagong abiso',
  'No waiting queue for today': 'Walang naghihintay sa pila ngayong araw',
  'Normal': 'Normal',
  'NOW SERVING': 'KASALUKUYANG TINATAWAG',
  'OK': 'OK',
  'OPEN SCANNER': 'BUKSAN ANG SCANNER',
  'OR SIGN IN WITH EMAIL': 'O MAG-LOGIN GAMIT ANG EMAIL',
  'Passed': 'Pumasa',
  'Password': 'Password',
  'Pending': 'Naghihintay',
  'Pending Appointments': 'Mga Naghihintay na Appointment',
  'Plate Number': 'Numero ng Plaka',
  'Please enter credentials': 'Ilagay ang email at password',
  'Please prepare. Your turn is near.':
      'Maghanda na po. Malapit na po kayong tawagin.',
  'Please proceed to the testing area.':
      'Maaari na po kayong pumunta sa testing area.',
  'PRINT': 'I-PRINT',
  'Queue Alert': 'Abiso sa Pila',
  'Queue Date': 'Petsa',
  'Queue Panel': 'Panel ng Pila',
  'Queue Settings': 'Mga Setting ng Pila',
  'Refresh': 'I-refresh',
  'Rejected': 'Tinanggihan',
  'Reports': 'Mga Ulat',
  'RESET APP PASSWORD': 'I-RESET ANG PASSWORD NG APP',
  'Reset Password': 'I-reset ang Password',
  'REVIEW DETAILS': 'TINGNAN ANG DETALYE',
  'SAVE': 'I-SAVE',
  'SAVE CHANGES': 'I-SAVE ANG MGA PAGBABAGO',
  'Scan Valid ID': 'I-scan ang Wastong ID',
  'Search': 'Maghanap',
  'Seasonal Peak Months': 'Mga Buwan na Mataas ang Dami',
  'Select Analytics Month': 'Pumili ng Buwan para sa Pagsusuri',
  'SEND RESET LINK': 'IPADALA ANG RESET LINK',
  'SEND VERIFICATION': 'IPADALA ANG BERIPIKASYON',
  'Settings': 'Mga Setting',
  'Slow': 'Mabagal',
  'SUBMIT APPOINTMENT': 'IPASA ANG APPOINTMENT',
  'Submitted Documents': 'Mga Isinumiteng Dokumento',
  'Test Voice': 'Subukan ang Boses',
  'Test voice alert': 'Subukan ang paalala sa boses',
  'Track My Queue': 'Subaybayan ang Aking Pila',
  'Track Queue': 'Subaybayan ang Pila',
  'TRY AGAIN': 'SUBUKAN MULI',
  'UPDATE': 'I-UPDATE',
  'VIEW': 'TINGNAN',
  'VIEW ALL APPOINTMENTS': 'TINGNAN LAHAT NG APPOINTMENT',
  'View selected file': 'Tingnan ang napiling file',
  'Voice language': 'Wika ng boses',
  'Voice Language': 'Wika ng Boses',
  'Voice queue alerts': 'Mga paalala sa pila gamit ang boses',
  'Voice Settings': 'Mga Setting ng Boses',
  'Voice Speed': 'Bilis ng Boses',
  'Waiting': 'Naghihintay',
  'Waiting Queue': 'Naghihintay sa Pila',
  'Walk-In Customer': 'Walk-In na Customer',
  'Welcome': 'Maligayang pagdating',
  'Welcome Admin': 'Maligayang pagdating, Admin',
};
