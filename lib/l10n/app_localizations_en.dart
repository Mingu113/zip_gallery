// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get errorZipProcessing => 'Error processing ZIP';

  @override
  String get errorZipNotFound => 'Error: ZIP file not found';

  @override
  String get appTitle => 'ZIP Gallery';

  @override
  String get chooseZIP => 'Choose ZIP file';

  @override
  String get sortGallery => 'Sort';

  @override
  String get sortGalleryDescription => 'The images will be sorted';

  @override
  String get closeView => 'Stop viewing';

  @override
  String get changeLocale => 'Change locale/language';

  @override
  String get exit => 'Exit';
}
