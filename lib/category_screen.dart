import 'package:flutter/material.dart';
import 'main.dart';
import 'settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'search_screen.dart';
import 'package:open_file/open_file.dart';
import 'recent_screen.dart';
import 'dart:io';
import 'scanner_screen.dart';
import 'ocr_utils.dart';
import 'pdf_thumbnail.dart';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class Category {
  final String name;
  final IconData icon;
  final Color color;

  Category(this.name, this.icon, this.color);
}

class CategoryScreen extends StatefulWidget {
  final Function(bool) toggleTheme;

  const CategoryScreen({super.key, required this.toggleTheme});

  static final List<Category> categories = [
    Category("Identity", Icons.badge, Colors.blue),

    Category("Education", Icons.school, Colors.green),

    Category("Work", Icons.work, Colors.orange),

    Category("Certificates", Icons.workspace_premium, Colors.purple),

    Category("Others", Icons.folder, Colors.grey),
  ];

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  List<Map<String, String>> recent = [];
  Map<String, String> pdfThumbnails = {};
  List<Category> customCategories = [];
Future<void> loadCustomCategories() async {
  final prefs =
      await SharedPreferences.getInstance();

  List<String> names =
      prefs.getStringList(
            "custom_categories",
          ) ??
          [];

  customCategories =
      names.map((name) {
    return Category(
      name,
      Icons.folder,
      Colors.teal,
    );
  }).toList();

  setState(() {});
}
  Future<void> loadPdfThumbnail(String pdfPath) async {
  if (pdfThumbnails.containsKey(pdfPath)) {
    return;
  }

  String? thumbnail = await generatePdfThumbnail(pdfPath);

  if (thumbnail != null) {
    setState(() {
      pdfThumbnails[pdfPath] = thumbnail;
    });
  }
}
  Future<void> deleteCategory(
  String categoryName,
) async {

  bool? confirm =
      await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text(
          "Delete Category",
        ),

        content: Text(
          "Delete '$categoryName'?\n\nAll documents will be moved to Others.",
        ),

        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(
                context,
                false,
              );
            },
            child: const Text(
              "Cancel",
            ),
          ),

          TextButton(
            onPressed: () {
              Navigator.pop(
                context,
                true,
              );
            },
            child: const Text(
              "Delete",
            ),
          ),
        ],
      );
    },
  );

  if (confirm != true) return;

  final prefs =
      await SharedPreferences.getInstance();

  List<String> custom =
      prefs.getStringList(
            "custom_categories",
          ) ??
          [];

  List<String> categoryFiles =
      prefs.getStringList(
            categoryName,
          ) ??
          [];

  List<String> others =
      prefs.getStringList(
            "Others",
          ) ??
          [];

  others.addAll(categoryFiles);

  await prefs.setStringList(
    "Others",
    others,
  );

  await prefs.remove(
    categoryName,
  );

  custom.remove(
    categoryName,
  );

  await prefs.setStringList(
    "custom_categories",
    custom,
  );

  await loadCustomCategories();
}

  Future<void> showAddCategoryDialog() async {
  TextEditingController controller =
      TextEditingController();

  final result =
      await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title:
            const Text("New Category"),

        content: TextField(
          controller: controller,
          decoration:
              const InputDecoration(
            hintText:
                "Category name",
          ),
        ),

        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text(
              "Cancel",
            ),
          ),

          ElevatedButton(
            onPressed: () {
              Navigator.pop(
                context,
                controller.text.trim(),
              );
            },
            child: const Text(
              "Add",
            ),
          ),
        ],
      );
    },
  );

  if (result == null ||
      result.isEmpty) return;

  final prefs =
      await SharedPreferences.getInstance();

  List<String> categories =
      prefs.getStringList(
            "custom_categories",
          ) ??
          [];

  categories.add(result);

  await prefs.setStringList(
    "custom_categories",
    categories,
  );

  await loadCustomCategories();
}

  Future<String?> chooseCategory() async {
  return await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("Select Category"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
  ...CategoryScreen.categories,
  ...customCategories,
].map((cat) {
            return ListTile(
              leading: Icon(
                cat.icon,
                color: cat.color,
              ),
              title: Text(cat.name),
              onTap: () {
                Navigator.pop(
                  context,
                  cat.name,
                );
              },
            );
          }).toList(),
        ),
      );
    },
  );
}

Future<void> globalImportFiles() async {

  String? category =
      await chooseCategory();

  if (category == null) return;
  isScanning = true;
  FilePickerResult? result =
      await FilePicker.platform.pickFiles(
    allowMultiple: true,
  );

  if (result == null) {
  isScanning = false;
  return;
}

isScanning = false;

  final prefs =
      await SharedPreferences.getInstance();

  List<String> files =
      prefs.getStringList(category) ?? [];

  Directory appDir =
      await getApplicationDocumentsDirectory();

  for (var pickedFile in result.files) {

  File originalFile =
      File(pickedFile.path!);

  String? customName =
    await showImportRenameDialog(
  pickedFile.name,
);

if (customName == null ||
    customName.trim().isEmpty) {
  continue;
}

 String newPath =
    "${appDir.path}/$customName";

  File newFile =
      await originalFile.copy(newPath);

  String extractedText = "";

  String name =
      pickedFile.name.toLowerCase();

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

  files.add(newFile.path);
}

  await prefs.setStringList(
    category,
    files,
  );

  if (mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          "Imported to $category",
        ),
      ),
    );
  }

  loadRecent();
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


  void showAddDocumentOptions() {
  showModalBottomSheet(
    context: context,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.document_scanner,
              ),
              title: const Text(
                "Scan Document",
              ),
              onTap: () {
                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const ScannerScreen(),
                  ),
                ).then((_) {
                  loadRecent();
                });
              },
            ),

            ListTile(
              leading: const Icon(
                Icons.upload_file,
              ),
              title: const Text(
                "Import Files",
              ),
              onTap: () async {
                Navigator.pop(context);

                await globalImportFiles();
              },
            ),
          ],
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

  @override
  void initState() {
    super.initState();
    loadCustomCategories();
    loadRecent();
  }

  loadRecent() async {
    final prefs = await SharedPreferences.getInstance();

    final data = prefs.getStringList("recent") ?? [];

    List<String> cleanedRecent = [];

    recent = [];

    for (var e in data) {
      final parts = e.split("|");

      String name = parts[0];
      String path = parts[1];
      String category = parts[2];

      File file = File(path);

      if (await file.exists()) {
        cleanedRecent.add(e);

        recent.add({"name": name, "path": path, "category": category});
      }
    }

    // save cleaned list
    await prefs.setStringList("recent", cleanedRecent);

    setState(() {});
  }

  bool isImage(String name) {
    String ext = name.split('.').last.toLowerCase();
    return ["jpg", "jpeg", "png", "webp", "heic"].contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("VaultX"),
        backgroundColor: Colors.indigo.shade900,

        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      SettingsScreen(toggleTheme: widget.toggleTheme),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchScreen()),
              );
            },
          ),
        ],
      ),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              if (recent.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,

                  children: [
                    const Text(
                      "Recent Documents",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecentScreen(recent: recent),
                          ),
                        );
                      },

                      child: const Text("View All"),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Column(
  children: recent.take(3).map((doc) {
    return Card(
      margin: const EdgeInsets.only(
        bottom: 8,
      ),

      elevation: 3,

      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(12),
      ),

      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),

        leading: isImage(doc["name"]!)
    ? ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(doc["path"]!),
          width: 52,
          height: 52,
          fit: BoxFit.cover,
        ),
      )
    : doc["name"]!.toLowerCase().endsWith(".pdf")
        ? Builder(
            builder: (context) {
              if (!pdfThumbnails.containsKey(doc["path"]!)) {
                loadPdfThumbnail(doc["path"]!);
              }

              String? thumb = pdfThumbnails[doc["path"]!];

              if (thumb != null && File(thumb).existsSync()) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(thumb),
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                  ),
                );
              }

              return Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.picture_as_pdf,
                  color: Colors.indigo,
                ),
              );
            },
          )
        : Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              getFileIcon(doc["name"]!),
              color: Colors.indigo,
            ),
          ),

title: Text(
  doc["name"]!,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
),

subtitle: Text(
  doc["category"]!,
),

onTap: () async {
  await OpenFile.open(doc["path"]!);
  loadRecent();
},
      ),
    );
  }).toList(),
),

                const SizedBox(height: 20),
              ],

              const Text(
                "Categories",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              GridView.builder(
                shrinkWrap: true,

                physics: const NeverScrollableScrollPhysics(),

                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,

                  crossAxisSpacing: 16,

                  mainAxisSpacing: 16,
                ),

                itemCount:
    CategoryScreen.categories.length +
    customCategories.length +
    1,

                itemBuilder: (context, index) {
                  final allCategories = [
  ...CategoryScreen.categories,
  ...customCategories,
];
                if (index == allCategories.length) {
  return GestureDetector(
    onTap: showAddCategoryDialog,

    child: Card(
      elevation: 4,

      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,

        children: const [
          Icon(
            Icons.add_circle_outline,
            size: 50,
          ),

          SizedBox(height: 10),

          Text("Add Category"),
        ],
      ),
    ),
  );
}
                  final cat = allCategories[index];
                  bool isCustom = index >= CategoryScreen.categories.length;
                  
                  return GestureDetector(
  onLongPress: isCustom
      ? () {
          deleteCategory(
            cat.name,
          );
        }
      : null,

  onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HomeScreen(
                            category: cat.name,
                            accentColor: cat.color,
                          ),
                        ),
                      ).then((_) {
                        loadRecent();
                      });
                    },

                    child: Card(
                      elevation: 4,

                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,

                        children: [
  Icon(
    cat.icon,
    size: 50,
    color: cat.color,
  ),

  const SizedBox(height: 10),

  Text(
    cat.name,
    textAlign: TextAlign.center,
  ),

  const SizedBox(height: 4),

  FutureBuilder<SharedPreferences>(
    future:
        SharedPreferences.getInstance(),
    builder: (context, snapshot) {

      int count = 0;

      if (snapshot.hasData) {
        count = snapshot.data!
                .getStringList(
                  cat.name,
                )
                ?.length ??
            0;
      }

      return Text(
        "$count Document${count == 1 ? '' : 's'}",
        style: TextStyle(
          color:
              Colors.grey.shade600,
          fontSize: 12,
        ),
      );
    },
  ),
],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
  onPressed: showAddDocumentOptions,
  child: const Icon(Icons.add),
),
    );
  }
}
