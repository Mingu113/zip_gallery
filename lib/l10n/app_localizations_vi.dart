// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get errorZipProcessing => 'Lỗi khi xử lý tập tin ZIP';

  @override
  String get errorZipNotFound => 'Lỗi: Không tìm thấy tập tin ZIP';

  @override
  String get appTitle => 'Xem ảnh từ ZIP';

  @override
  String get chooseZIP => 'Chọn tập tin ZIP';

  @override
  String get sortGallery => 'Sắp xếp';

  @override
  String get sortGalleryDescription =>
      'Các hình ảnh sẽ được sắp xếp theo tên của tập tin';

  @override
  String get closeView => 'Ngừng xem';

  @override
  String get changeLocale => 'Đổi ngôn ngữ';

  @override
  String get exit => 'Thoát';

  @override
  String get clearLastPathContents => 'Xóa danh sách tập tin';
}
