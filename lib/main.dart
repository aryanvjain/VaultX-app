import 'dart:io';
import 'ocr_utils.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pin_lock.dart';
import 'settings.dart';
import 'scan_preview.dart';
import 'change_pin.dart';
import 'category_screen.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'scanner_screen.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;
import 'pdf_thumbnail.dart';
import 'package:share_plus/share_plus.dart';

bool isScanning = false;
bool isImporting = false;
void main() {
  runApp(const VaultXApp());
}


class VaultXApp extends StatefulWidget {
  const VaultXApp({super.key});

  @override
  State<VaultXApp> createState() => _VaultXAppState();
}

class _VaultXAppState extends State<VaultXApp> {
  bool isDarkMode = false;

  @override
  void initState() {
    super.initState();
    loadTheme();
  }

  loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDarkMode = prefs.getBool("darkMode") ?? false;
    });
  }

  toggleTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("darkMode", value);
    setState(() {
      isDarkMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,

      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.indigo,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.indigo.shade900,
          foregroundColor: Colors.white,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.indigo.shade900,
          foregroundColor: Colors.white,
        ),
      ),

      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.indigo,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.indigo.shade900,
          foregroundColor: Colors.white,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.indigo.shade900,
          foregroundColor: Colors.white,
        ),
      ),

      home: LockWrapperWithThemeToggle(toggleTheme: toggleTheme),
    );
  }
}

class LockWrapperWithThemeToggle extends StatelessWidget {
  final Function(bool) toggleTheme;

  const LockWrapperWithThemeToggle({super.key, required this.toggleTheme});

  @override
  Widget build(BuildContext context) {
    return LockWrapperWithToggle(toggleTheme: toggleTheme);
  }
}

class Document {
  String name;
  String path;
  String extractedText;
  String thumbnailPath;

  Document(
    this.name,
    this.path, [
    this.extractedText = "",
    this.thumbnailPath = "",
  ]);
}

class LockWrapperWithToggle extends StatefulWidget {
  final Function(bool) toggleTheme;

  const LockWrapperWithToggle({super.key, required this.toggleTheme});

  @override
  State<LockWrapperWithToggle> createState() => _LockWrapperWithToggleState();
}

class _LockWrapperWithToggleState extends State<LockWrapperWithToggle>
    with WidgetsBindingObserver {
  bool unlocked = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showLock();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool isLockScreenOpen = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && !isScanning && !isImporting) {
      unlocked = false;
    }

    if (state == AppLifecycleState.resumed && !unlocked && !isLockScreenOpen) {
      isLockScreenOpen = true;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        bool? result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PinLockScreen()),
        );

        if (result == true) {
          setState(() {
            unlocked = true;
          });
        }

        isLockScreenOpen = false;
      });
    }
  }

  showLock() async {
    isLockScreenOpen = true;
    bool? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PinLockScreen()),
    );

    if (result == true) {
      setState(() {
        unlocked = true;
      });
    }
    isLockScreenOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    if (!unlocked) {
      return const Scaffold(backgroundColor: Colors.white);
    }

    return CategoryScreen(toggleTheme: widget.toggleTheme);
  }
}

class HomeScreen extends StatefulWidget {
  final String category;
  final Color accentColor;

  const HomeScreen({
    super.key,
    required this.category,
    required this.accentColor,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}
Map<int, int> pageRotations = {};
class _HomeScreenState extends State<HomeScreen> {
  List<Document> documents = [];
  Map<String, String> pdfThumbnails = {};
  List<File> scannedImages = [];
  Set<int> selectedIndexes = {};
  bool selectionMode = false;

  Future<void> loadPdfThumbnail(
  String pdfPath,
) async {
  if (pdfThumbnails.containsKey(pdfPath)) {
    return;
  }

  String? thumbnail =
      await generatePdfThumbnail(
    pdfPath,
  );

  if (thumbnail != null) {
    setState(() {
      pdfThumbnails[pdfPath] =
          thumbnail;
    });
  }
}

  Future<List<Category>> getAllCategories() async {
  final prefs =
      await SharedPreferences.getInstance();

  List<String> names =
      prefs.getStringList(
            "custom_categories",
          ) ??
          [];

  List<Category> custom =
      names.map((name) {
    return Category(
      name,
      Icons.folder,
      Colors.teal,
    );
  }).toList();

  return [
    ...CategoryScreen.categories,
    ...custom,
  ];
}





  Future<String?> chooseCategory() async {
  return await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("Select Category"),

        content: SizedBox(
          width: double.maxFinite,

          child: ListView(
            shrinkWrap: true,

            children: CategoryScreen.categories.map((cat) {
              return ListTile(
                leading: Icon(cat.icon, color: cat.color),

                title: Text(cat.name),

                onTap: () {
                  Navigator.pop(context, cat.name);
                },
              );
            }).toList(),
          ),
        ),
      );
    },
  );
}

  IconData getFileIcon(String fileName) {
    String ext = fileName.split('.').last.toLowerCase();

    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;

      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;

      case 'doc':
      case 'docx':
        return Icons.description;

      case 'xls':
      case 'xlsx':
        return Icons.table_chart;

      case 'ppt':
      case 'pptx':
        return Icons.slideshow;

      default:
        return Icons.insert_drive_file;
    }
  }

  bool isImage(String name) {
    String ext = name.split('.').last.toLowerCase();
    return ["jpg", "jpeg", "png", "webp", "heic"].contains(ext);
  }

  String getFileSize(String path) {
  try {
    File file = File(path);

    if (!file.existsSync()) {
      return "Missing File";
    }

    int bytes = file.lengthSync();

    if (bytes < 1024) {
      return "$bytes B";
    } else if (bytes < 1024 * 1024) {
      return "${(bytes / 1024).toStringAsFixed(1)} KB";
    } else {
      return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
    }
  } catch (e) {
    return "Missing File";
  }
}
  String getFileDate(String path) {
  try {
    final date =
        File(path).lastModifiedSync();

    return
        "${date.day}/${date.month}/${date.year}";
  } catch (e) {
    return "";
  }
}

  void showRenameDialog() {
    TextEditingController controller = TextEditingController(
      text: documents[selectedIndexes.first].name,
    );

    showDialog(
      context: context,

      builder: (context) {
        return AlertDialog(
          title: const Text("Rename File"),

          content: TextField(
            controller: controller,

            decoration: const InputDecoration(hintText: "Enter new name"),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },

              child: const Text("Cancel"),
            ),

            TextButton(
              onPressed: () async {
                String newName = controller.text;

                if (newName.isEmpty) return;

                int index = selectedIndexes.first;
                File file = File(documents[index].path);

                String newPath = file.parent.path + "/" + newName;

                File newFile = await file.rename(newPath);

                setState(() {
                  documents[index] = Document(newName, newFile.path);

                  selectionMode = false;

                  selectedIndexes.clear();
                });

                await saveDocuments();

                Navigator.pop(context);
              },

              child: const Text("Rename"),
            ),
          ],
        );
      },
    );
  }


  Future<void> shareSelectedFile() async {
  if (selectedIndexes.isEmpty) return;

  int index = selectedIndexes.first;

  await Share.shareXFiles([
    XFile(
      documents[index].path,
    ),
  ]);

  setState(() {
    selectionMode = false;
    selectedIndexes.clear();
  });
}

  Future<void> moveSelectedFiles(String newCategory) async {
    final prefs = await SharedPreferences.getInstance();

    List<String> newCategoryFiles = prefs.getStringList(newCategory) ?? [];

    for (var index in selectedIndexes) {
      Document doc = documents[index];

      newCategoryFiles.add(doc.path);
    }

    await prefs.setStringList(newCategory, newCategoryFiles);

    documents.removeWhere(
      (doc) => selectedIndexes.contains(documents.indexOf(doc)),
    );

    setState(() {
      selectedIndexes.clear();
      selectionMode = false;
    });

    await saveDocuments();
  }

  void showMoveDialog() async {

  List<Category> allCategories =
      await getAllCategories();

  showModalBottomSheet(
    context: context,
    builder: (_) {
      return Column(
        mainAxisSize: MainAxisSize.min,

        children: allCategories.map((cat) {

          if (cat.name ==
              widget.category) {
            return Container();
          }

          return ListTile(
            leading: Icon(
              cat.icon,
              color: cat.color,
            ),

            title: Text(cat.name),

            onTap: () {
              moveSelectedFiles(
                cat.name,
              );

              Navigator.pop(
                context,
              );
            },
          );
        }).toList(),
      );
    },
  );
}
  String sortMode = "name";
  @override
  void initState() {
    super.initState();

    loadDocuments();
  }

  saveDocuments() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    List<String> paths = documents.map((doc) => doc.path).toList();

    prefs.setStringList(widget.category, paths);
  }

  loadDocuments() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();

  List<String>? paths = prefs.getStringList(widget.category);

  if (paths != null) {
    documents = paths
    .where((path) => File(path).existsSync())
    .map((path) {
      String name = path.split('/').last;

      return Document(name, path);
    })
    .toList();
    await prefs.setStringList(
  widget.category,
  documents.map((e) => e.path).toList(),
);

    

    sortDocuments();
    setState(() {});
  }
}

  void sortDocuments() {
    if (sortMode == "name") {
      documents.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    } else if (sortMode == "newest") {
      documents.sort(
        (a, b) => File(
          b.path,
        ).lastModifiedSync().compareTo(File(a.path).lastModifiedSync()),
      );
    } else if (sortMode == "oldest") {
      documents.sort(
        (a, b) => File(
          a.path,
        ).lastModifiedSync().compareTo(File(b.path).lastModifiedSync()),
      );
    }
  }

  void showSortDialog() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.sort_by_alpha),
              title: const Text("Name (A → Z)"),
              onTap: () {
                setState(() {
                  sortMode = "name";
                  sortDocuments();
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text("Newest first"),
              onTap: () {
                setState(() {
                  sortMode = "newest";
                  sortDocuments();
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text("Oldest first"),
              onTap: () {
                setState(() {
                  sortMode = "oldest";
                  sortDocuments();
                });
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  Future<String?> showImportRenameDialog(String originalName) async {
  TextEditingController controller =
      TextEditingController(
    text: originalName,
  );

  return await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("Rename File"),

        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "Enter file name",
          ),
        ),

        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("Cancel"),
          ),

          TextButton(
            onPressed: () {
              Navigator.pop(
                context,
                controller.text.trim(),
              );
            },
            child: const Text("Import"),
          ),
        ],
      );
    },
  );
}

  Future pickFile() async {
    isImporting = true;
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
    );
    isImporting = false;
    if (result != null) {
      print("ENTERED PICKFILE");
      Directory appDir = await getApplicationDocumentsDirectory();
      print("FOUND ${result.files.length} FILES");
      for (var pickedFile in result.files) {
        File originalFile = File(pickedFile.path!);
        print("SHOWING RENAME DIALOG");
        String? customName =
    await showImportRenameDialog(
  pickedFile.name,
);

if (customName == null ||
    customName.isEmpty) {
  continue;
}

        String newPath =
'${appDir.path}/${DateTime.now().millisecondsSinceEpoch}_$customName';

        File newFile = await originalFile.copy(newPath);

String extractedText = "";

String name = pickedFile.name.toLowerCase();

if (name.endsWith(".jpg") ||
    name.endsWith(".jpeg") ||
    name.endsWith(".png")) {

  extractedText =
      await extractTextFromImage(
        newFile.path,
      );
}

else if (name.endsWith(".pdf")) {

  extractedText =
      await extractTextFromPdf(
        newFile.path,
      );
}
if (extractedText.isNotEmpty) {

  await saveOCRText(
    newFile.path,
    extractedText,
  );
}

documents.add(
  Document(
    customName,
    newFile.path,
  ),
);
      }

      await saveDocuments();

      setState(() {});
    }
  }

 Future scanDocument() async {
  isScanning = true;

  final ImagePicker picker = ImagePicker();

  final XFile? photo = await picker.pickImage(
    source: ImageSource.camera,
  );

  isScanning = false;

  if (photo == null) return;

  scannedImages.add(File(photo.path));

  showScanOptions();
}

 void showScanOptions() {
  showModalBottomSheet(
    context: context,
    isDismissible: false,
    builder: (_) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              "${scannedImages.length} page(s) scanned",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.add_a_photo),
            title: const Text("Add Another Page"),
            onTap: () {
              Navigator.pop(context);
              scanDocument();
            },
          ),

          ListTile(
            leading: const Icon(Icons.preview),
            title: const Text("Preview & Create PDF"),
            onTap: () async {
              Navigator.pop(context);

              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ScanPreviewScreen(
                    scannedImages: scannedImages,
                  ),
                ),
              );

              if (result != null) {
  scannedImages = List<File>.from(result["pages"]);

  pageRotations =
      Map<int, int>.from(result["rotations"]);

  if (scannedImages.isNotEmpty) {
    createPdfFromScans();
  }
}
            },
          ),
        ],
      );
    },
  );
}

  Future createPdfFromScans() async {
    final pdf = pw.Document();

    for (int i = 0; i < scannedImages.length; i++){

      File imageFile = scannedImages[i];

int rotation = pageRotations[i] ?? 0;
      final bytes = imageFile.readAsBytesSync();
      final image = pw.MemoryImage(bytes);

      final decodedImage = await decodeImageFromList(bytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            decodedImage.width.toDouble(),
            decodedImage.height.toDouble(),
          ),
          build: (pw.Context context) {
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Transform.rotate(
  angle: rotation * 3.1415926535 / 180,
  child: pw.Image(
    image,
    fit: pw.BoxFit.cover,
  ),
),
            );
          },
        ),
      );
    }

    Directory appDir = await getApplicationDocumentsDirectory();

    DateTime now = DateTime.now();

String fileName =
    "Document_${now.day}_${now.month}_${now.year}.pdf";

    String path = "${appDir.path}/$fileName";

    File pdfFile = File(path);

    await pdfFile.writeAsBytes(await pdf.save());

    String combinedOCRText = "";

for (File image in scannedImages) {
  try {
    String text =
        await extractTextFromImage(
      image.path,
    );

    combinedOCRText += "$text\n";
  } catch (e) {
  }
}

await saveOCRText(
  path,
  combinedOCRText,
);

    documents.add(Document(fileName, path));

    scannedImages.clear(); // 🔥 IMPORTANT

    await saveDocuments();

    setState(() {});
  }

  openDocument(Document doc) async {
    OpenFile.open(doc.path);

    final prefs = await SharedPreferences.getInstance();

    List<String> recent = prefs.getStringList("recent") ?? [];

    recent.removeWhere((e) => e.split("|")[1] == doc.path);

    recent.insert(0, "${doc.name}|${doc.path}|${widget.category}");

    if (recent.length > 5) recent.removeLast();

    await prefs.setStringList("recent", recent);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      
      appBar: AppBar(
        title: Text(
          selectionMode
              ? "${selectedIndexes.length} selected"
              : widget.category,
        ),

        actions: [
          if (!selectionMode)
            IconButton(icon: const Icon(Icons.sort), onPressed: showSortDialog),

          if (selectionMode)
            IconButton(
              icon: Icon(
                selectedIndexes.length == documents.length
                    ? Icons.deselect
                    : Icons.select_all,
              ),
              onPressed: () {
                setState(() {
                  if (selectedIndexes.length == documents.length) {
                    selectedIndexes.clear();
                    selectionMode = false;
                  } else {
                    selectedIndexes = Set.from(
                      List.generate(documents.length, (i) => i),
                    );
                  }
                });
              },
            ),

          if (selectionMode && selectedIndexes.length == 1)
  IconButton(
    icon: const Icon(Icons.share),
    onPressed: () {
      shareSelectedFile();
    },
  ),

if (selectionMode && selectedIndexes.length == 1)
  IconButton(
    icon: const Icon(Icons.edit),
    onPressed: () {
      showRenameDialog();
    },
  ),

          if (selectionMode)
            IconButton(
              icon: const Icon(Icons.drive_file_move),
              onPressed: () {
                showMoveDialog();
              },
            ),

          if (selectionMode)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                bool? confirm = await showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text("Delete Files"),
                      content: Text(
                        "Delete ${selectedIndexes.length} selected file(s)? This action cannot be undone.",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context, false);
                          },
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context, true);
                          },
                          child: const Text("Delete"),
                        ),
                      ],
                    );
                  },
                );

                if (confirm != true) return;

                final prefs = await SharedPreferences.getInstance();
                List<String> recent = prefs.getStringList("recent") ?? [];

                for (var index in selectedIndexes) {
                  String path = documents[index].path;
                  File file = File(path);

                  if (await file.exists()) {
                    await file.delete();
                  }

                  recent.removeWhere((item) => item.contains(path));
                }

                documents.removeWhere(
                  (doc) => selectedIndexes.contains(documents.indexOf(doc)),
                );

                await prefs.setStringList("recent", recent);

                setState(() {
                  selectedIndexes.clear();
                  selectionMode = false;
                });

                await saveDocuments();
              },
            ),
        ],
      ),
      body: documents.isEmpty
    ? Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 90,
              color:
                  Colors.grey.shade400,
            ),

            const SizedBox(
              height: 16,
            ),

            const Text(
              "No Documents Yet",
              style: TextStyle(
                fontSize: 22,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              "Tap + to scan or import\nyour first document.",
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color:
                    Colors.grey.shade600,
              ),
            ),
          ],
        ),
      )
    : ListView.builder(
        itemCount: documents.length,

        itemBuilder: (context, index) {
          return Card(
  margin: const EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 6,
  ),
  elevation: 4,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  ),
  child: ListTile(
  contentPadding: const EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 8,
  ),
            title: Text(
              documents[index].name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            subtitle: Text(
  "${getFileSize(documents[index].path)} • ${getFileDate(documents[index].path)}",
),

            leading: Stack(
              children: [
                documents[index].name.toLowerCase().endsWith(".jpg") ||
                        documents[index].name.toLowerCase().endsWith(".jpeg") ||
                        documents[index].name.toLowerCase().endsWith(".png")
                    ? ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: Builder(
      builder: (context) {
        File file =
            File(documents[index].path);

        if (!file.existsSync()) {
          return const Icon(
            Icons.broken_image,
            size: 40,
          );
        }

        return Image.file(
          file,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        );
      },
    ),
  )
                    : documents[index].name
        .toLowerCase()
        .endsWith(".pdf")
    ? Builder(
        builder: (context) {
          loadPdfThumbnail(
  documents[index].path,
);

          String? thumb =
              pdfThumbnails[
                  documents[index].path];

          if (thumb != null &&
              File(thumb)
                  .existsSync()) {
            return ClipRRect(
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
              child: Image.file(
                File(thumb),
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            );
          }

          return Container(
            width: 52,
            height: 52,
            decoration:
                BoxDecoration(
              color: widget
                  .accentColor
                  .withOpacity(
                    0.1,
                  ),
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),
            child: Icon(
              Icons.picture_as_pdf,
              color:
                  widget.accentColor,
            ),
          );
        },
      )
    : Container(
        width: 52,
        height: 52,
        decoration:
            BoxDecoration(
          color: widget
              .accentColor
              .withOpacity(
                0.1,
              ),
          borderRadius:
              BorderRadius.circular(
            10,
          ),
        ),
        child: Icon(
          getFileIcon(
            documents[index].name,
          ),
          color:
              widget.accentColor,
          size: 30,
        ),
      ),

                Positioned(
                  right: -2,
                  bottom: -2,
                  child: AnimatedScale(
                    scale: selectedIndexes.contains(index) ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const CircleAvatar(
                      radius: 10,
                      backgroundColor: Colors.indigo,
                      child: Icon(Icons.check, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),

            tileColor: selectedIndexes.contains(index)
                ? Colors.blue.withOpacity(0.3)
                : null,

            onTap: () {
              if (selectionMode) {
                setState(() {
                  if (selectedIndexes.contains(index)) {
                    selectedIndexes.remove(index);
                  } else {
                    selectedIndexes.add(index);
                  }

                  if (selectedIndexes.isEmpty) {
                    selectionMode = false;
                  }
                });
              } else {
                openDocument(documents[index]);
              }
            },

            onLongPress: () {
  setState(() {
    selectionMode = true;
    selectedIndexes.add(index);
  });
},
),
);
        },
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (_) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.upload_file),
                    title: const Text("Import Files"),
                    onTap: () {
                      Navigator.pop(context);
                      pickFile();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.camera_alt),
                    title: const Text("Scan Document"),
                    onTap: () {
                      Navigator.pop(context);
                      scanDocument();
                    },
                  ),
                ],
              );
            },
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
