import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ZipImageReaderViewModel extends ChangeNotifier {
  List<ArchiveFile> images = [];
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  String? _lastPath;
  String? get lastPath => _lastPath;
  int _crossAxis = 1;
  int get crossAxis => _crossAxis;
  List<FileSystemEntity>? _lastPathContents;
  List<FileSystemEntity>? get lastPathContents => _lastPathContents;
  bool get isReading => images.isNotEmpty;
  String? _comicName;
  String? get comicName => _comicName;
  int get comicLength => images.length;
  bool get isDebug => kDebugMode;

  // KEYWORDS:
  String get keyLastPath => "lastPath";
  String get keyGridCrossAxis => "axisCross";

  @override
  void notifyListeners() {
    kPrint("Notify listeners");
    super.notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    kPrint("Is loading: $isLoading");
    notifyListeners();
  }

  Future<void> getLastUsedPath() async {
    final prefs = await SharedPreferences.getInstance();
    _lastPath = prefs.getString(keyLastPath);
  }

  Future<void> setLastUsedPath(String path) async {
    if (Platform.isAndroid || Platform.isIOS) return;
    kPrint("Set last path $path");
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyLastPath, path);
    notifyListeners();
  }

  Future<void> getCrossAxis() async {
    final prefs = await SharedPreferences.getInstance();
    _crossAxis = prefs.getInt(keyGridCrossAxis) ?? 1;
  }

  Future<void> saveCrossAxis(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyGridCrossAxis, value);
    notifyListeners();
  }

  void setCrossAxis(int value) {
    _crossAxis = value;
  }

  Future<void> getDirectoryContents() async {
    setLoading(true);
    kPrint("Get Directoory contents");
    await getLastUsedPath();
    if (lastPath == null || (lastPath ?? "").isEmpty) {
      setLoading(false);
      return;
    }
    Directory directory = Directory(lastPath!);
    List<FileSystemEntity> contents = directory.listSync().toList();
    List<FileSystemEntity> result = [];
    for (var entity in contents) {
      if (isEntityAZip(entity)) {
        result.add(entity);
      }
    }
    _lastPathContents = result;
    kPrint(
      "From ${directory.path} discovered ${contents.length} entities, got ${result.length} entities",
    );
    setLoading(false);
  }

  bool isEntityAZip(FileSystemEntity entity) {
    return entity.path.toLowerCase().endsWith('zip');
  }

  Future<void> _extractImages(Archive archive) async {
    setLoading(true);
    const imageExtensions = {'.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp'};
    for (final file in archive) {
      if (file.isFile) {
        final filename = file.name.toLowerCase();
        if (imageExtensions.any(filename.endsWith)) {
          images.add(file);
        }
      }
    }
    setLoading(false);
  }

  Future<void> loadImageFromZip(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception("ZIP file not found");
      }
      kPrint("Picked file: ${file.path}");
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      await _extractImages(archive);
      await setLastUsedPath(getPathName(filePath));
      _comicName = getFileName(filePath);
    } catch (e) {
      throw Exception("Error processing ZIP: ${e.toString()}");
    }
  }

  Future<void> clearImages() async {
    images.clear();
    await getDirectoryContents();
    notifyListeners();
  }

  Future<void> clearLastPathContents() async {
    _lastPath = null;
    await setLastUsedPath("");
    lastPathContents?.clear();
    notifyListeners();
  }

  void sortImage() {
    // Check if file's name is not in correct format (integer only)
    if (int.tryParse(getFileName(images.first.name)) == null) return;
    images.sort((a, b) {
      int e1 = int.parse(getFileName(a.name));
      int e2 = int.parse(getFileName(b.name));
      return e1.compareTo(e2);
    });
    notifyListeners();
  }

  Future<void> clearCache() async {
    if (!(Platform.isAndroid || Platform.isIOS)) return;
    kPrint("Delete temp cache");
    Directory tempDir = await getTemporaryDirectory();
    if (isDebug) {
      var size = tempDir
          .listSync(recursive: true)
          .toList()
          .fold(0, (int sum, file) => sum += file.statSync().size);
      kPrint("Temp cache is $size bytes in size");
    }
    tempDir.deleteSync(recursive: true);
  }

  static String getFileName(String filePath) {
    String file = filePath.split(Platform.pathSeparator).last;
    String result = file.substring(0, file.lastIndexOf('.'));
    return result;
  }

  static String getPathName(String filePath) {
    int end = filePath.lastIndexOf(Platform.pathSeparator);
    String result = filePath.substring(0, end);
    return result;
  }
}

void kPrint(Object? message) {
  if (kDebugMode) print(message);
}
