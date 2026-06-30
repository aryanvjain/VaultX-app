import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'ocr_utils.dart';


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

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  List<Map<String, String>> allDocs = [];
  List<Map<String, String>> filteredDocs = [];

  @override
  void initState() {
    super.initState();
    loadDocuments();
  }


  Future<String> getOCRText(String path) async {
  final prefs = await SharedPreferences.getInstance();

  return prefs.getString(
        "ocr_$path",
      ) ??
      "";
}

  Future<void> loadDocuments() async {
    final prefs = await SharedPreferences.getInstance();

    List<String> categories = [
  "Identity",
  "Education",
  "Work",
  "Certificates",
  "Others",
];

List<String> customCategories =
    prefs.getStringList(
          "custom_categories",
        ) ??
        [];

categories.addAll(
  customCategories,
);

    List<Map<String, String>> temp = [];

    for (String category in categories) {
      List<String>? files = prefs.getStringList(category);

      if (files != null) {
        for (String path in files) {
          String name = path.split('/').last;

          temp.add({"name": name, "path": path, "category": category});
        }
      }
    }

    setState(() {
      allDocs = temp;
      filteredDocs = temp;
    });
  }

  Future<void> search(String query) async {
  query = query.toLowerCase();

  List<Map<String, String>> results = [];

  for (var doc in allDocs) {
    final name =
        doc["name"]!.toLowerCase();

    final ocrText =
        (await getOCRText(
      doc["path"]!,
    ))
            .toLowerCase();

    if (name.contains(query) ||
        ocrText.contains(query)) {
      results.add(doc);
    }
  }

  setState(() {
    filteredDocs = results;
  });
}

  void openFile(String path) {
    OpenFile.open(path);
  }

  bool isImage(String name) {
    String ext = name.split('.').last.toLowerCase();
    return ["jpg", "jpeg", "png", "webp", "heic"].contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Search"),

        backgroundColor: Colors.indigo.shade900,
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),

            child: TextField(
              onChanged: search,

              decoration: InputDecoration(
                hintText: "Search documents...",

                prefixIcon: const Icon(Icons.search),

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          Expanded(
            child: filteredDocs.isEmpty
                ? Center(
  child: Column(
    mainAxisAlignment:
        MainAxisAlignment.center,
    children: [
      Icon(
        Icons.search_off,
        size: 80,
        color: Colors.grey.shade400,
      ),

      const SizedBox(height: 16),

      const Text(
        "No Documents Found",
        style: TextStyle(
          fontSize: 20,
          fontWeight:
              FontWeight.bold,
        ),
      ),

      const SizedBox(height: 8),

      Text(
        "Try a different keyword\nor search phrase.",
        textAlign: TextAlign.center,
        style: TextStyle(
          color:
              Colors.grey.shade600,
        ),
      ),
    ],
  ),
)
                : ListView.builder(
                    itemCount: filteredDocs.length,

                    itemBuilder: (context, index) {
                      final doc = filteredDocs[index];

                      return ListTile(
                        leading: isImage(doc["name"]!)
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.file(
                                  File(doc["path"]!),
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Icon(
                                getFileIcon(doc["name"]!),
                                color: Colors.indigo,
                              ),
                        title: Text(doc["name"]!),
                        subtitle: Text(doc["category"]!),

                        onTap: () {
                          openFile(doc["path"]!);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
