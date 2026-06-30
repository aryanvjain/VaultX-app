import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

import 'category_screen.dart';
import 'scan_preview.dart';
import 'main.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  List<File> scannedImages = [];
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
}

  Future createPdfFromScans() async {
  final pdf = pw.Document();

  for (int i = 0; i < scannedImages.length; i++) {
    File imageFile = scannedImages[i];

    int rotation = pageRotations[i] ?? 0;

    final bytes = imageFile.readAsBytesSync();

    final image = pw.MemoryImage(bytes);

    final decodedImage =
        await decodeImageFromList(bytes);

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
              angle:
                  rotation * 3.1415926535 / 180,
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

 TextEditingController nameController =
    TextEditingController(
  text:
      "Document_${DateTime.now().day}_${DateTime.now().month}_${DateTime.now().year}",
);

String? customName =
    await showDialog<String>(
  context: context,
  builder: (context) {
    return AlertDialog(
      title: const Text(
        "Save Document",
      ),

      content: TextField(
        controller:
            nameController,
        decoration:
            const InputDecoration(
          hintText:
              "Document Name",
        ),
      ),

      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(
              context,
            );
          },
          child: const Text(
            "Cancel",
          ),
        ),

        ElevatedButton(
          onPressed: () {
            Navigator.pop(
              context,
              nameController.text
                  .trim(),
            );
          },
          child: const Text(
            "Save",
          ),
        ),
      ],
    );
  },
);

if (customName == null ||
    customName.isEmpty) {
  return;
}

Directory appDir =
    await getApplicationDocumentsDirectory();

String fileName =
    "$customName.pdf";

String path =
    "${appDir.path}/$fileName";

File pdfFile =
    File(path);

await pdfFile.writeAsBytes(
  await pdf.save(),
);

  String? selectedCategory =
      await chooseCategory();

  if (selectedCategory == null) return;

  final prefs =
      await SharedPreferences.getInstance();

  List<String> files =
      prefs.getStringList(selectedCategory) ?? [];

  files.add(path);

  await prefs.setStringList(
    selectedCategory,
    files,
  );

  scannedImages.clear();

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Saved to $selectedCategory",
        ),
      ),
    );

    Navigator.pop(context, true);
  }
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
                scannedImages =
                    List<File>.from(result["pages"]);

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
        ),
      );
    },
  );
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

  @override
void initState() {
  super.initState();

  loadCustomCategories();

  WidgetsBinding.instance.addPostFrameCallback((_) {
    scanDocument();
  });
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan Document"),
      ),

      body: const SizedBox.shrink(),
    );
  }
}