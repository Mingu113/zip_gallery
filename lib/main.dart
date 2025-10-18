import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_gallery/l10n/app_localizations.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'dart:io';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ZipImageReaderView(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      darkTheme: ThemeData.dark(useMaterial3: true),
      scrollBehavior: ScrollBehavior(),
      theme: ThemeData.dark(useMaterial3: true),
      themeMode: ThemeMode.system,
    );
  }
}

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
    if (kDebugMode) {
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

class ZipImageReaderView extends StatefulWidget {
  const ZipImageReaderView({super.key});

  @override
  State<ZipImageReaderView> createState() => _ZipImageReaderViewState();
}

class _ZipImageReaderViewState extends State<ZipImageReaderView> {
  final ZipImageReaderViewModel _viewModel = ZipImageReaderViewModel();

  @override
  void initState() {
    _viewModel.clearCache();
    _viewModel.getDirectoryContents();
    _viewModel.getCrossAxis();
    super.initState();
  }

  // void showSnackBar(String message) {
  void _testChangeLocale(BuildContext context) {
    Locale currentLcoale = Localizations.localeOf(context);
    Locale newLocale = Locale('en');
    if (currentLcoale.languageCode == 'en') newLocale = Locale('vi');

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder:
            (BuildContext context) => Localizations.override(
              context: context,
              locale: newLocale,
              child: ZipImageReaderView(),
            ),
      ),
    );
  }

  void openImage(BuildContext context, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => FullScreenImageView(
              images: _viewModel.images,
              initialIndex: index,
            ),
      ),
    );
  }

  Widget lastPathContentScreen() {
    List<FileSystemEntity> contents = _viewModel.lastPathContents ?? [];
    kPrint(_viewModel.lastPath);
    kPrint(contents.length);
    return SliverList.builder(
      itemCount: contents.length,
      // padding: EdgeInsets.only(bottom: 8),
      itemBuilder: (context, index) {
        String filePath = contents[index].path;
        return InkWell(
          onTap: () => _viewModel.loadImageFromZip(filePath),
          child: ListTile(
            title: Text(ZipImageReaderViewModel.getFileName(filePath)),
          ),
        );
      },
    );
  }

  Widget _ui(BuildContext context) {
    if (_viewModel.isLoading) {
      kPrint("Is loading");
      return SliverToBoxAdapter(
        child: const Center(child: CircularProgressIndicator()),
      );
    } else if (!_viewModel.isReading) {
      kPrint("Is empty");
      if (_viewModel.lastPath != null) {
        kPrint("Last path is not null");
        return lastPathContentScreen();
      }
      return SliverToBoxAdapter(
        child: Center(
          child: ElevatedButton(
            onPressed: () async => await chooseZip(),
            child: Text(AppLocalizations.of(context)!.chooseZIP),
          ),
        ),
      );
    } else {
      kPrint("Build gallery");
      return _buildGallery();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: true,
      top: true,
      child: Scaffold(
        body: ListenableBuilder(
          builder:
              (context, child) => CustomScrollView(
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    stretch: true,
                    expandedHeight: 150,
                    leading:
                        _viewModel.isReading
                            ? Center(child: Text("${_viewModel.comicLength}"))
                            : null,
                    flexibleSpace: FlexibleSpaceBar(
                      expandedTitleScale: 1,
                      title: Text(
                        _viewModel.isReading
                            ? _viewModel._comicName!
                            : AppLocalizations.of(context)!.appTitle,
                      ),
                    ),
                    actions: [_appPopupMenuButton(context)],
                  ),
                  _ui(context),
                ],
              ),
          listenable: _viewModel,
        ),
      ),
    );
  }

  PopupMenuButton<String> _appPopupMenuButton(BuildContext context) {
    return PopupMenuButton(
      itemBuilder:
          (context) => [
            PopupMenuItem(
              value: 'zip',
              child: ListTile(
                leading: Icon(Icons.archive),
                title: Text(AppLocalizations.of(context)!.chooseZIP),
              ),
            ),
            if (_viewModel.isReading) ...[
              PopupMenuItem(
                value: 'sort',
                child: ListTile(
                  leading: Icon(Icons.sort),
                  title: Text(AppLocalizations.of(context)!.sortGallery),
                ),
              ),
              PopupMenuItem(
                value: 'close',
                child: ListTile(
                  leading: Icon(Icons.close),
                  title: Text(AppLocalizations.of(context)!.closeView),
                ),
              ),
            ],
            if (!_viewModel.isReading &&
                (_viewModel.lastPathContents ?? []).isNotEmpty)
              PopupMenuItem(
                value: 'clearLastPathContents',
                child: ListTile(
                  leading: Icon(Icons.clear_all),
                  title: Text(
                    AppLocalizations.of(context)!.clearLastPathContents,
                  ),
                ),
              ),
            PopupMenuItem(
              value: 'showCrossAxisSlider',
              child: ListTile(
                leading: Icon(Icons.onetwothree),
                title: Text(AppLocalizations.of(context)!.showAxisCountDialog),
              ),
            ),
            PopupMenuItem(
              value: 'exit',
              child: ListTile(
                leading: Icon(Icons.exit_to_app),
                title: Text(AppLocalizations.of(context)!.exit),
              ),
            ),
            if (kDebugMode)
              PopupMenuItem(
                value: 'locale',
                child: ListTile(
                  leading: Icon(Icons.language),
                  title: Text(AppLocalizations.of(context)!.changeLocale),
                ),
              ),
          ],
      onSelected: (value) async {
        switch (value) {
          case 'zip':
            await chooseZip();
            break;
          case 'close':
            _viewModel.clearImages();
            break;
          case 'sort':
            _viewModel.sortImage();
            break;
          case 'exit':
            await _viewModel.clearCache();
            await SystemNavigator.pop();
            break;
          case 'locale':
            _testChangeLocale(context);
            break;
          case 'clearLastPathContents':
            await _viewModel.clearLastPathContents();
            break;
          case 'showCrossAxisSlider':
            await showDialog(
              context: context,
              builder: (context) => _crossAxisDialog(),
            );
            break;
        }
      },
      icon: const Icon(Icons.more_vert),
    );
  }

  SimpleDialog _crossAxisDialog() {
    return SimpleDialog(
      title: Text(AppLocalizations.of(context)!.showAxisCountDialog),
      contentPadding: EdgeInsetsGeometry.all(10),
      children: [
        Row(
          children: [
            Text("1"),
            Expanded(
              child: Slider.adaptive(
                value: _viewModel.crossAxis.toDouble(),
                max: 10,
                min: 1,
                divisions: 10,
                label: _viewModel.crossAxis.toString(),
                onChanged: (value) {
                  _viewModel.setCrossAxis(value.toInt());
                },
                onChangeEnd: (value) async {
                  await _viewModel.saveCrossAxis(value.toInt());
                },
              ),
            ),
            Text("10"),
          ],
        ),
        CloseButton(onPressed: () => Navigator.pop(context)),
      ],
    );
  }

  Future<void> chooseZip() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result?.files.single.path != null) {
      _viewModel.clearImages();
      await _viewModel.loadImageFromZip(result!.files.single.path!);
    }
  }

  Widget _buildGallery() {
    return SliverGrid.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _viewModel.crossAxis,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
        childAspectRatio: 3 / 4,
      ),
      itemCount: _viewModel.comicLength,
      itemBuilder: (context, index) {
        return ImageItemWidget(
          image: _viewModel.images[index],
          index: index,
          onTap: () => openImage(context, index),
        );
      },
    );
  }
}

class ImageItemWidget extends StatefulWidget {
  final ArchiveFile image;
  final int index;
  final VoidCallback onTap;

  const ImageItemWidget({
    super.key,
    required this.image,
    required this.index,
    required this.onTap,
  });

  @override
  State<ImageItemWidget> createState() => _ImageItemWidgetState();
}

class _ImageItemWidgetState extends State<ImageItemWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return GestureDetector(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Hero(
          tag: 'image-${widget.index}-${widget.image.hashCode}',
          child: Image.memory(
            Uint8List.fromList(widget.image.content),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class FullScreenImageView extends StatefulWidget {
  final List<ArchiveFile> images;
  final int initialIndex;

  const FullScreenImageView({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<FullScreenImageView> createState() => _FullScreenImageViewState();
}

class _FullScreenImageViewState extends State<FullScreenImageView> {
  late int _currentIndex;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int get _itemCount => widget.images.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          '${_currentIndex + 1}/$_itemCount',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton.outlined(
            onPressed:
                () => _pageController.previousPage(
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                ),
            icon: Icon(Icons.arrow_back_ios),
          ),
          IconButton.outlined(
            onPressed:
                () => _pageController.nextPage(
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                ),
            icon: Icon(Icons.arrow_forward_ios),
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: PhotoViewGallery.builder(
        pageController: _pageController,
        itemCount: _itemCount,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        builder: (context, index) {
          return PhotoViewGalleryPageOptions(
            imageProvider: MemoryImage(
              Uint8List.fromList(widget.images[index].content),
            ),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 4,
            initialScale: PhotoViewComputedScale.contained,
            heroAttributes: PhotoViewHeroAttributes(
              tag: 'image-$index-${widget.images[index].hashCode}',
            ),
          );
        },
        scrollPhysics: const BouncingScrollPhysics(),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
      ),
    );
  }
}
