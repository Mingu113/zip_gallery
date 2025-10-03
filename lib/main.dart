import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
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
      _extractImages(archive);
    } catch (e) {
      throw Exception("Error processing ZIP: ${e.toString()}");
    }
  }

  void clearImages() {
    images.clear();
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

  String getFileName(String filePath) {
    String file = filePath.split(Platform.pathSeparator).last;
    String result = file.substring(0, file.lastIndexOf('.'));
    return result;
  }
}

void kPrint(String message) {
  if (kDebugMode) print(message);
}

class ZipImageReaderView extends StatelessWidget {
  ZipImageReaderView({super.key});

  final ZipImageReaderViewModel _viewModel = ZipImageReaderViewModel();

  // void showSnackBar(String message) {
  //   ScaffoldMessenger.of(
  //     context,
  //   ).showSnackBar(SnackBar(content: Text(message)));
  // }

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
              child: this,
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

  Widget _ui(BuildContext context) {
    if (_viewModel.isLoading) {
      kPrint("Is loading");
      return const Center(child: CircularProgressIndicator());
    } else if (_viewModel.images.isEmpty) {
      kPrint("Is empty");
      return Center(
        child: ElevatedButton(
          onPressed: () async => await chooseZip(),
          child: Text(AppLocalizations.of(context)!.chooseZIP),
        ),
      );
    } else {
      kPrint("Build gallery");
      return _buildGallery();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.appTitle),
        actions: [
          PopupMenuButton(
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 'zip',
                    child: ListTile(
                      leading: Icon(Icons.archive),
                      title: Text(AppLocalizations.of(context)!.chooseZIP),
                    ),
                  ),
                  if (_viewModel.images.isNotEmpty)
                    PopupMenuItem(
                      value: 'sort',
                      child: ListTile(
                        leading: Icon(Icons.sort),
                        title: Text(AppLocalizations.of(context)!.sortGallery),
                      ),
                    ),
                  if (_viewModel.images.isNotEmpty)
                    PopupMenuItem(
                      value: 'close',
                      child: ListTile(
                        leading: Icon(Icons.close),
                        title: Text(AppLocalizations.of(context)!.closeView),
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
                  SystemNavigator.pop();
                  break;
                case 'locale':
                  _testChangeLocale(context);
                  break;
              }
            },
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: ListenableBuilder(
        builder: (context, child) => _ui(context),
        listenable: _viewModel,
      ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 1,
            crossAxisSpacing: 1,
            mainAxisSpacing: 1,
            childAspectRatio: 3 / 4,
          ),
          itemCount: _viewModel.images.length,
          itemBuilder: (context, index) {
            return ImageItemWidget(
              image: _viewModel.images[index],
              index: index,
              onTap: () => openImage(context, index),
            );
          },
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
        // loadingBuilder:
        //     (context, event) => Center(
        //       child: CircularProgressIndicator(
        //         value: event?.cumulativeBytesLoaded.toDouble() ?? 0,
        //       ),
        //     ),
      ),
    );
  }
}
