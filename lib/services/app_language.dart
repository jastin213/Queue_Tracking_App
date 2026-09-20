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

  final colonMatch = RegExp(r'^(.+):$').firstMatch(value);
  if (colonMatch != null) {
    final label = colonMatch.group(1)!;
    final translated = _translateToFilipino(label);
    if (translated != label) return '$translated:';
  }

  final nowServingMatch = RegExp(
    r'^Now Serving:\s*(.+)$',
    caseSensitive: false,
  ).firstMatch(value);
  if (nowServingMatch != null) {
    return 'Kasalukuyang tinatawag: ${nowServingMatch.group(1)}';
  }

  final fromLocationMatch = RegExp(
    r'^From\s+(.+)\s+to\s+NPJN$',
  ).firstMatch(value);
  if (fromLocationMatch != null) {
    return 'Mula ${fromLocationMatch.group(1)} papuntang NPJN';
  }

  final assignedQueueMatch = RegExp(
    r'^Please use your assigned queue number:\s*(.+)\.$',
  ).firstMatch(value);
  if (assignedQueueMatch != null) {
    return 'Gamitin lamang ang nakatalagang numero sa iyo: '
        '${assignedQueueMatch.group(1)}.';
  }

  final currentStatusMatch = RegExp(
    r'^Current queue status:\s*(.+)$',
  ).firstMatch(value);
  if (currentStatusMatch != null) {
    return 'Kasalukuyang status ng pila: '
        '${_translateToFilipino(currentStatusMatch.group(1)!)}';
  }

  final queueDateMatch = RegExp(r'^Queue\s+(.+)\s+•\s+(.+)$').firstMatch(value);
  if (queueDateMatch != null) {
    return 'Pila ${queueDateMatch.group(1)} • ${queueDateMatch.group(2)}';
  }

  final minutesMatch = RegExp(r'^(\d+)\s+mins?$').firstMatch(value);
  if (minutesMatch != null) return '${minutesMatch.group(1)} minuto';

  final hoursMinutesMatch = RegExp(
    r'^(\d+)\s+hrs?\s+(\d+)\s+mins?$',
  ).firstMatch(value);
  if (hoursMinutesMatch != null) {
    return '${hoursMinutesMatch.group(1)} oras at '
        '${hoursMinutesMatch.group(2)} minuto';
  }

  final basedOnPositionMatch = RegExp(
    r'^Based on position\s+(.+)\s+×\s+(\d+)\s+mins per customer$',
  ).firstMatch(value);
  if (basedOnPositionMatch != null) {
    return 'Batay sa posisyong ${basedOnPositionMatch.group(1)} × '
        '${basedOnPositionMatch.group(2)} minuto bawat customer';
  }

  final customersMatch = RegExp(r'^(\d+)\s+customers?$').firstMatch(value);
  if (customersMatch != null) return '${customersMatch.group(1)} customer';

  final leaveNowMatch = RegExp(
    r'^Leave your house now\. Your turn is estimated in\s+(.+)\.$',
  ).firstMatch(value);
  if (leaveNowMatch != null) {
    return 'Umalis na ngayon. Tinatayang ${leaveNowMatch.group(1)} bago ang '
        'iyong turn.';
  }

  final leaveInMatch = RegExp(
    r'^Leave your house in\s+(.+)\. Your turn is estimated in\s+(.+)\.$',
  ).firstMatch(value);
  if (leaveInMatch != null) {
    return 'Umalis makalipas ang ${leaveInMatch.group(1)}. Tinatayang '
        '${leaveInMatch.group(2)} bago ang iyong turn.';
  }

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
  'Completed - Failed': 'Tapos Na - Bumagsak',
  'Completed - Passed': 'Tapos Na - Pumasa',
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
  'No appointment queue number is assigned to your account for today.':
      'Walang nakatalagang numero sa pila sa iyong account para sa araw na ito.',
  'No current notifications': 'Walang bagong abiso',
  'No waiting queue for today': 'Walang naghihintay sa pila ngayong araw',
  'Normal': 'Normal',
  'Now Serving': 'Kasalukuyang Tinatawag',
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
  'Reset': 'Na-reset',
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
  'View selected file': 'Tingnan ang napiling file',
  'Voice language': 'Wika ng boses',
  'Voice Language': 'Wika ng Boses',
  'Voice queue alerts': 'Mga paalala sa pila gamit ang boses',
  'Voice Settings': 'Mga Setting ng Boses',
  'Voice Speed': 'Bilis ng Boses',
  'Waiting': 'Naghihintay',
  'Waiting Queue': 'Naghihintay sa Pila',
  'Skipped': 'Inilipat sa Dulo',
  'Walk-In Customer': 'Walk-In na Customer',
  'Welcome': 'Maligayang pagdating',
  'Welcome Admin': 'Maligayang pagdating, Admin',
  'Access denied. This account has no valid role.':
      'Hindi pinapayagan ang pag-access. Walang wastong tungkulin ang account na ito.',
  'Access denied. This account is not an admin.':
      'Hindi pinapayagan ang pag-access. Hindi admin ang account na ito.',
  'Account name updated.': 'Na-update na ang pangalan ng account.',
  'Account profile not found. Please contact support.':
      'Hindi nakita ang profile ng account. Makipag-ugnayan sa support.',
  'Admin Email': 'Email ng Admin',
  'Admin reason': 'Dahilan ng admin',
  'Admin Reminders': 'Mga Paalala para sa Admin',
  'After you book an appointment, your appointment status will appear here as Pending, Approved, or Rejected.':
      'Pagkatapos mag-book, makikita rito kung naghihintay, naaprubahan, o tinanggihan ang iyong appointment.',
  'Allowance for parking, traffic, and preparation':
      'Dagdag na oras para sa paradahan, trapiko, at paghahanda',
  'App Language': 'Wika ng App',
  'Appointment submitted successfully.':
      'Matagumpay na naisumite ang appointment.',
  'Appointments refreshed just now.': 'Na-refresh na ang mga appointment.',
  'Available': 'May Bakante',
  'Average': 'Karaniwan',
  'Bar graph': 'Bar graph',
  'Before booking an appointment, please confirm the following:':
      'Bago mag-book ng appointment, pakikumpirma ang sumusunod:',
  'Bring the original ID, OR, and CR for verification.':
      'Dalhin ang orihinal na ID, OR, at CR para sa beripikasyon.',
  'Certificate of Registration (CR)': 'Certificate of Registration (CR)',
  'Change account name': 'Palitan ang pangalan ng account',
  'Change email address': 'Palitan ang email address',
  'Check pending appointments daily.':
      'Suriin araw-araw ang mga naghihintay na appointment.',
  'Check your appointment status before traveling.':
      'Tingnan ang status ng appointment bago bumiyahe.',
  'Choose an option below.': 'Pumili ng opsyon sa ibaba.',
  'Choose Another': 'Pumili ng Iba',
  'Choose Appointment Date': 'Pumili ng Petsa ng Appointment',
  'Choose File': 'Pumili ng File',
  'Choose New Photo': 'Pumili ng Bagong Larawan',
  'Choose the admin interface language.':
      'Piliin ang wikang gagamitin sa interface ng admin.',
  'Choose the date, location, vehicle type, and queue code.':
      'Piliin ang petsa, lokasyon, uri ng sasakyan, at numero sa pila.',
  'Closed / Past': 'Sarado / Lumipas Na',
  'Complete all fields': 'Kumpletuhin ang lahat ng field',
  'Complete all fields and documents.':
      'Kumpletuhin ang lahat ng field at dokumento.',
  'Confirm Before Daily Reset': 'Kumpirmahin Bago ang Araw-araw na Reset',
  'Continue as a walk-in, or use your registered account.':
      'Magpatuloy bilang walk-in o gamitin ang iyong rehistradong account.',
  'Control the queue calling voice.':
      'Pamahalaan ang boses na ginagamit sa pagtawag ng pila.',
  'Control what appears on the customer display.':
      'Pamahalaan ang impormasyong makikita sa customer display.',
  'Current': 'Kasalukuyan',
  'Customer details updated successfully.':
      'Matagumpay na na-update ang detalye ng customer.',
  'Customer Information': 'Impormasyon ng Customer',
  'Customer Name': 'Pangalan ng Customer',
  'Display Announcement': 'Anunsyo sa Display',
  'Display announcement saved.': 'Na-save na ang anunsyo sa display.',
  'Display customer name on screen.':
      'Ipakita sa screen ang pangalan ng customer.',
  'Display estimated waiting time if available.':
      'Ipakita ang tinatayang oras ng paghihintay kapag available.',
  'Display Gas or Diesel label.': 'Ipakita kung Gas o Diesel ang sasakyan.',
  'Display Settings': 'Mga Setting ng Display',
  'Each document must be 10 MB or smaller.':
      'Ang bawat dokumento ay dapat 10 MB o mas maliit.',
  'EDIT DETAILS': 'I-EDIT ANG DETALYE',
  'Email (optional)': 'Email (opsyonal)',
  'Enter a plate number or name': 'Ilagay ang plaka o pangalan',
  'Enter display announcement': 'Ilagay ang anunsyo para sa display',
  'Enter your queue number': 'Ilagay ang iyong numero sa pila',
  'Estimated Queue Time': 'Tinatayang Oras ng Paghihintay',
  'Example: G001 or D001': 'Halimbawa: G001 o D001',
  'Fully booked': 'Puno Na',
  'Full Name': 'Buong Pangalan',
  'Get your queue number at the center, then track your position here without an account.':
      'Kunin ang iyong numero sa pila sa center, pagkatapos ay subaybayan ito rito kahit walang account.',
  'How This Was Calculated': 'Paano Ito Kinuwenta',
  'Image preview unavailable': 'Hindi maipakita ang preview ng larawan',
  'In-app appointment reminders': 'Mga paalala sa appointment sa app',
  'Invalid Queue Format': 'Maling Format ng Numero sa Pila',
  'Loading your appointment status...':
      'Kinukuha ang status ng iyong appointment...',
  'Login / Create Account': 'Mag-login / Gumawa ng Account',
  'Manage daily queue safety and limits.':
      'Pamahalaan ang kaligtasan at araw-araw na limitasyon ng pila.',
  'Message / feedback for customer': 'Mensahe / feedback para sa customer',
  'Minus safety buffer': 'Ibawas ang dagdag na oras',
  'Minus travel time': 'Ibawas ang oras ng biyahe',
  'Monthly served': 'Buwanang napagsilbihan',
  'Municipality': 'Munisipalidad',
  'No available queue code for this date.':
      'Walang available na numero sa pila para sa petsang ito.',
  'No detailed reason was recorded for this older appointment.':
      'Walang detalyadong dahilan na naitala para sa appointment na ito.',
  'No file uploaded': 'Walang na-upload na file',
  'No Passed or Failed records for this month.':
      'Walang tala ng pumasa o bumagsak para sa buwang ito.',
  'Not available': 'Hindi available',
  'Official Receipt (OR)': 'Official Receipt (OR)',
  'OPEN HERE': 'BUKSAN DITO',
  'OPEN NEW TAB': 'BUKSAN SA BAGONG TAB',
  'Open Display Page': 'Buksan ang Display Page',
  'Password must be at least 6 characters.':
      'Ang password ay dapat may hindi bababa sa 6 na character.',
  'PDF selected — tap to view': 'Napili ang PDF — pindutin para tingnan',
  'Peak': 'Pinakamataas',
  'Play a reminder when the tracked queue is near.':
      'Magpatugtog ng paalala kapag malapit na ang sinusubaybayang pila.',
  'Playing voice alert...': 'Pinapatugtog ang paalala...',
  'Please check your queue number.':
      'Pakitingnan muli ang iyong numero sa pila.',
  'Please coordinate with staff.': 'Makipag-ugnayan po sa staff.',
  'Please enter admin email and password.':
      'Ilagay ang email at password ng admin.',
  'Please enter only the queue number assigned to you. Using the correct code prevents confusion and ensures that you track your own queue.':
      'Ilagay lamang ang numero sa pila na nakatalaga sa iyo. Ang tamang numero ay nakaiiwas sa kalituhan at tinitiyak na sarili mong pila ang sinusubaybayan mo.',
  'Please login first before submitting an appointment.':
      'Mag-login muna bago magsumite ng appointment.',
  'Please review the booking policy before submitting your appointment.':
      'Basahin muna ang patakaran bago isumite ang appointment.',
  'Position': 'Posisyon',
  'Preferred language': 'Napiling wika',
  'Prevents accidental queue reset.':
      'Iniiwasan ang hindi sinasadyang pag-reset ng pila.',
  'Printable & Downloadable PDF Reports':
      'Mga PDF Report na Maaaring I-print at I-download',
  'Queue not found': 'Hindi nakita ang numero sa pila',
  'Queue Number': 'Numero sa Pila',
  'Queue record is incomplete.': 'Hindi kumpleto ang tala ng pila.',
  'Queue Results': 'Resulta ng Pila',
  'Queue Status': 'Status ng Pila',
  'Queue waiting time': 'Oras ng paghihintay sa pila',
  'Quick guide for daily operation.':
      'Maikling gabay para sa araw-araw na operasyon.',
  'Recommended leave time': 'Inirerekomendang oras ng pag-alis',
  'REJECT APPOINTMENT': 'TANGGIHAN ANG APPOINTMENT',
  'Rejected Appointments': 'Mga Tinanggihang Appointment',
  'Rejection reason': 'Dahilan ng pagtanggi',
  'Report Details': 'Detalye ng Ulat',
  'Required Documents': 'Mga Kailangang Dokumento',
  'Retake Photo': 'Kunan Muli',
  'REVIEW EXPIRED DOCUMENTS': 'SURIIN ANG MGA LUMANG DOKUMENTO',
  'Review': 'Basahin',
  'Review uploaded documents before approval.':
      'Suriin ang mga dokumentong na-upload bago aprubahan.',
  'Safely review uploads that have passed the 365-day period.':
      'Ligtas na suriin ang mga upload na lumampas na sa 365 araw.',
  'Safety Buffer': 'Dagdag na Oras para sa Kaligtasan',
  'Save Announcement': 'I-save ang Anunsyo',
  'Search plate number or customer name':
      'Maghanap gamit ang plaka o pangalan ng customer',
  'Seasonal Detection': 'Pagtukoy sa Panahong Mataas ang Dami',
  'Select a reason.': 'Pumili ng dahilan.',
  'Select app language': 'Pumili ng wika ng app',
  'Select voice language': 'Pumili ng wika ng boses',
  'Select voice speed': 'Pumili ng bilis ng boses',
  'Served': 'Napagsilbihan',
  'Served Customers': 'Mga Napagsilbihang Customer',
  'Show appointment decisions and queue reminders in the app.':
      'Ipakita sa app ang desisyon sa appointment at mga paalala sa pila.',
  'Show Customer Name': 'Ipakita ang Pangalan ng Customer',
  'Show Estimated Waiting Time': 'Ipakita ang Tinatayang Oras ng Paghihintay',
  'Show Vehicle Type': 'Ipakita ang Uri ng Sasakyan',
  'SMART LEAVE ADVICE': 'MATALINONG PAYO SA PAG-ALIS',
  'Sorry, you missed your queue.': 'Paumanhin, lumampas na ang iyong pila.',
  'Status': 'Status',
  'Tap to view': 'Pindutin para tingnan',
  'The appointment name is linked to the logged-in customer account.':
      'Ang pangalan sa appointment ay nakaugnay sa naka-login na customer account.',
  'The uploaded file link is invalid.':
      'Hindi wasto ang link ng na-upload na file.',
  'This is not your queue number': 'Hindi ito ang iyong numero sa pila',
  'This name is locked to your logged-in account so your appointment status will appear correctly.':
      'Ang pangalang ito ay nakatali sa iyong account upang tama ang pagpapakita ng status ng appointment.',
  'This queue number is no longer active.':
      'Hindi na aktibo ang numerong ito sa pila.',
  'Time Summary': 'Buod ng Oras',
  'Travel Time': 'Oras ng Biyahe',
  'Unable to check queue': 'Hindi masuri ang pila',
  'Unable to load analytics': 'Hindi makuha ang pagsusuri',
  'Unable to load appointment status': 'Hindi makuha ang status ng appointment',
  'Unable to locate this appointment.': 'Hindi makita ang appointment na ito.',
  'Unable to log out. Please try again.':
      'Hindi makapag-log out. Subukan muli.',
  'Unable to open the uploaded file. Please try again.':
      'Hindi mabuksan ang na-upload na file. Subukan muli.',
  'Unable to preview this image.':
      'Hindi maipakita ang preview ng larawang ito.',
  'Unable to read selected file. Please try again.':
      'Hindi mabasa ang napiling file. Subukan muli.',
  'Unable to refresh appointments. Please try again.':
      'Hindi ma-refresh ang mga appointment. Subukan muli.',
  'Unable to refresh. Please try again.': 'Hindi ma-refresh. Subukan muli.',
  'Unable to sign in with email': 'Hindi makapag-login gamit ang email',
  'Expired Valid IDs, Official Receipts, and Certificates of Registration can be archived and removed manually. Customer, appointment, plate, status, and report information is preserved.':
      'Maaaring i-archive at manwal na alisin ang mga lumang Valid ID, Official Receipt, at Certificate of Registration. Mananatili ang impormasyon ng customer, appointment, plaka, status, at ulat.',
  'Upload or capture a photo of each required document.':
      'Mag-upload o kumuha ng larawan ng bawat kailangang dokumento.',
  'Use format like G001 or D001': 'Gamitin ang format na G001 o D001',
  'Use Test Voice before calling customers.':
      'Subukan muna ang boses bago tumawag ng customer.',
  'Valid ID': 'Wastong ID',
  'VIEW ALL APPOINTMENTS': 'TINGNAN LAHAT NG APPOINTMENT',
  'Voice playback is unavailable on this device.':
      'Hindi available sa device na ito ang pagpapatugtog ng boses.',
  'Waiting again': 'Naghihintay Muli',
  'Walk-ins': 'Mga Walk-in',
  'You will return to the login page and can sign in again anytime.':
      'Babalik ka sa login page at maaari kang mag-login muli anumang oras.',
  'Your appointment is approved. Use your queue code when tracking your queue.':
      'Naaprubahan ang iyong appointment. Gamitin ang iyong numero sa pila para subaybayan ito.',
  'Your emission test has been marked as failed.':
      'Minarkahan bilang bumagsak ang iyong emission test.',
  'Your emission test has been marked as passed.':
      'Minarkahan bilang pumasa ang iyong emission test.',
  '1. Provide your full name.': '1. Ilagay ang iyong buong pangalan.',
  '2. Upload a valid ID, OR, and CR.':
      '2. Mag-upload ng wastong ID, OR, at CR.',
  '3. Be present when your queue is called.':
      '3. Naroon kapag tinawag ang iyong numero sa pila.',
  '4. Missed turns will be moved to the bottom of the queue.':
      '4. Ang hindi nakasipot sa tawag ay ililipat sa dulo ng pila.',
  'ACCOUNT': 'ACCOUNT',
  'Account Details': 'Detalye ng Account',
  'Account was not created. Document upload authorization is required.':
      'Hindi ginawa ang account. Kailangang tanggapin ang pahintulot sa pag-upload ng dokumento.',
  'AI-assisted review uses OCR to compare visible text only. It does not prove document authenticity, and the administrator must make the final decision.':
      'Gumagamit ang AI-assisted review ng OCR upang ihambing lamang ang nakikitang teksto. Hindi nito pinatutunayan na tunay ang dokumento, at ang admin pa rin ang gagawa ng huling desisyon.',
  'All queue codes are taken for this date. Please select another date.':
      'Puno na ang lahat ng numero sa pila para sa petsang ito. Pumili ng ibang petsa.',
  'APPROVE': 'APRUBAHAN',
  'Approved Appointments': 'Mga Naaprubahang Appointment',
  'Archive and Delete Documents?': 'I-archive at Burahin ang mga Dokumento?',
  'Authorized admin access only.': 'Para lamang sa awtorisadong admin.',
  'Create your customer account to book appointments and access queue tracking services.':
      'Gumawa ng customer account upang makapag-book ng appointment at magamit ang pagsubaybay sa pila.',
  'Daily Report Preview': 'Preview ng Araw-araw na Ulat',
  'Delete Customer Record?': 'Burahin ang Tala ng Customer?',
  'Enter your Firebase admin account.':
      'Ilagay ang iyong Firebase admin account.',
  'Expired Document Cleanup': 'Paglilinis ng mga Lumang Dokumento',
  'Failed Customers': 'Mga Customer na Bumagsak',
  'Files scheduled for removal': 'Mga File na Nakatakdang Alisin',
  'Monthly Report Preview': 'Preview ng Buwanang Ulat',
  'No approved customers for this date.':
      'Walang naaprubahang customer para sa petsang ito.',
  'No document is currently eligible for manual cleanup.':
      'Wala pang dokumentong maaaring alisin nang manwal.',
  'No expired uploads found': 'Walang nakitang lumang upload',
  'No seasonal peak month has been detected yet.':
      'Wala pang natutukoy na buwan na may seasonal peak.',
  'Passed Customers': 'Mga Customer na Pumasa',
  'Queue · Appointment · Tracking': 'Pila · Appointment · Pagsubaybay',
  'Refreshed just now': 'Kaka-refresh lamang',
  'REJECT': 'TANGGIHAN',
  'Review eligible uploads before permanently removing the files.':
      'Suriin muna ang mga kwalipikadong upload bago tuluyang alisin ang mga file.',
  'Review Expired Uploads': 'Suriin ang mga Lumang Upload',
  'Search Results — All Dates': 'Resulta ng Paghahanap — Lahat ng Petsa',
  'Unable to display this image.': 'Hindi maipakita ang larawang ito.',
  'Unable to download the PDF. Please try again.':
      'Hindi ma-download ang PDF. Subukan muli.',
  'Unable to load queue display': 'Hindi makuha ang queue display',
  'UP NEXT': 'SUSUNOD',
  'Use a real email address. You must open the verification link sent to that address before you can sign in.':
      'Gumamit ng tunay na email address. Buksan muna ang verification link na ipinadala roon bago makapag-login.',
  'Verify your email before signing in. We sent a verification link to your email address.':
      'I-verify muna ang iyong email bago mag-login. Nagpadala kami ng verification link sa iyong email address.',
  'Password reset email sent. Open the link to create a new password.':
      'Naipadala na ang password reset email. Buksan ang link upang gumawa ng bagong password.',
  'Select a date to view approved customers. Availability updates automatically from Pending and Approved appointments.':
      'Pumili ng petsa upang makita ang mga naaprubahang customer. Awtomatikong nag-a-update ang availability mula sa naghihintay at naaprubahang appointment.',
  'Tap any date to view its approved and pending appointments.':
      'Pindutin ang anumang petsa upang makita ang mga naaprubahan at naghihintay na appointment.',
  'Print a report or download a soft-copy PDF to save, email, or send to LTO. PDF exports include only Passed and Failed records.':
      'Mag-print ng ulat o mag-download ng PDF upang i-save, i-email, o ipadala sa LTO. Ang PDF ay naglalaman lamang ng mga tala ng pumasa at bumagsak.',
  'A month is highlighted when its served volume is more than 30% above the average of the other recorded months.':
      'Naka-highlight ang isang buwan kapag ang dami ng napagsilbihan ay mahigit 30% sa karaniwan ng ibang naitalang buwan.',
  'This queue code is already taken. Please select another available queue.':
      'May nakakuha na sa numerong ito. Pumili ng ibang available na numero sa pila.',
  'This queue code was already taken online. Please choose another queue.':
      'May nakakuha na online sa numerong ito. Pumili ng ibang numero sa pila.',
  'This result is advisory only. Compare the actual document images before approving, requesting a resubmission, or rejecting.':
      'Gabay lamang ang resultang ito. Ihambing ang aktuwal na mga larawan ng dokumento bago aprubahan, humiling ng muling pagsusumite, o tanggihan.',
  'A lightweight historical archive is saved first. Appointment and report records are not deleted.':
      'Magse-save muna ng maikling historical archive. Hindi buburahin ang mga tala ng appointment at ulat.',
  'I understand that uploaded documents cannot be recovered through the application after cleanup.':
      'Nauunawaan ko na hindi na mababawi sa app ang mga na-upload na dokumento pagkatapos linisin.',
  'Only appointments whose uploaded documents have reached their recorded expiration date appear here. Review and select records before cleanup. Essential appointment and report information is archived and preserved.':
      'Tanging mga appointment na lumampas na sa nakatalang expiration date ng dokumento ang makikita rito. Suriin at piliin muna ang mga tala bago linisin. I-a-archive at pananatilihin ang mahalagang impormasyon ng appointment at ulat.',
  'More completed monthly records may be needed before a reliable peak can be identified.':
      'Maaaring kailangan pa ng mas maraming kumpletong buwanang tala bago matukoy nang maaasahan ang peak month.',
  'Track Your Queue in Real Time': 'Subaybayan ang Iyong Pila nang Real Time',
  'Know your current queue position, estimated waiting time, and when your turn is getting close.':
      'Alamin ang iyong kasalukuyang posisyon, tinatayang oras ng paghihintay, at kung malapit na ang iyong turn.',
  'Book Ahead, Wait Less': 'Mag-book nang Maaga, Mas Maikling Maghintay',
  'Schedule your emission testing appointment and receive your queue number once your booking is approved.':
      'Itakda ang iyong emission testing appointment at tanggapin ang numero sa pila kapag naaprubahan ang booking.',
  'Get Ready at the Right Time': 'Maghanda sa Tamang Oras',
  'Receive alerts when your turn is approaching and get estimated travel-time guidance before leaving.':
      'Tumanggap ng paalala kapag malapit na ang iyong turn at tingnan ang tinatayang oras ng biyahe bago umalis.',
  'Skip': 'Laktawan',
  'Next': 'Susunod',
  'Get Started': 'Magsimula',
  'Smart Queue Management': 'Matalinong Pamamahala ng Pila',
  'Fast. Clear. Convenient.': 'Mabilis. Malinaw. Maginhawa.',
  'Preparing your queue experience': 'Inihahanda ang iyong queue experience',
  'Emission Testing Center': 'Emission Testing Center',
  'YOUR QUEUE': 'IYONG PILA',
  'Now Serving A8': 'Kasalukuyang Tinatawag A8',
  'About 20 minutes': 'Humigit-kumulang 20 minuto',
  '4 IN LINE': 'IKA-4 SA PILA',
  'APPOINTMENT': 'APPOINTMENT',
  'Confirmed': 'Kumpirmado',
  'Booking approved': 'Naaprubahan ang booking',
  'QUEUE': 'PILA',
  'TRAVEL GUIDANCE': 'GABAY SA BIYAHE',
  'Leave in 12 minutes': 'Umalis makalipas ang 12 minuto',
  '3 customers ahead': '3 customer ang nauuna',
};
