import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'pdf_thumbnail.dart';

class RecentScreen extends StatefulWidget {
  final List<Map<String, String>> recent;

  const RecentScreen({
    super.key,
    required this.recent,
  });

  @override
  State<RecentScreen> createState() => _RecentScreenState();
}

class _RecentScreenState extends State<RecentScreen> {
  Map<String, String> pdfThumbnails = {};

  Future<void> loadPdfThumbnail(String pdfPath) async {
  if (pdfThumbnails.containsKey(pdfPath)) {
    return;
  }

  String? thumbnail =
      await generatePdfThumbnail(pdfPath);

  if (thumbnail != null) {
    setState(() {
      pdfThumbnails[pdfPath] = thumbnail;
    });
  }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Recent Documents"),
        backgroundColor: Colors.indigo.shade900,
      ),
      body: widget.recent.isEmpty
          ? const Center(child: Text("No recent documents"))
          : ListView.builder(
              itemCount: widget.recent.length,
              itemBuilder: (context, index) {
                final doc = widget.recent[index];

                return Dismissible(
                  key: Key(doc["path"]!),

                  direction: DismissDirection.endToStart,

                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    color: Colors.red,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),

                  confirmDismiss: (direction) async {
                    return await showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text("Remove from Recent?"),
                          content: const Text(
                            "This will remove the document from recent history only.",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text("Cancel"),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text("Remove"),
                            ),
                          ],
                        );
                      },
                    );
                  },

                  onDismissed: (direction) async {
                    widget.recent.removeAt(index);

                    final prefs = await SharedPreferences.getInstance();

                    List<String> updated = widget.recent
                        .map(
                          (doc) =>
                              "${doc["name"]}|${doc["path"]}|${doc["category"]}",
                        )
                        .toList();

                    await prefs.setStringList("recent", updated);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Removed from Recent")),
                    );
                  },

                  child: ListTile(
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
    : doc["name"]!.toLowerCase().endsWith(".pdf")
        ? Builder(
            builder: (context) {
              if (!pdfThumbnails.containsKey(doc["path"]!)) {
  loadPdfThumbnail(doc["path"]!);
}

              String? thumb =
                  pdfThumbnails[doc["path"]!];

              if (thumb != null &&
                  File(thumb).existsSync()) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(
                    File(thumb),
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                );
              }

              return const Icon(
                Icons.picture_as_pdf,
                color: Colors.indigo,
              );
            },
          )
        : Icon(
            getFileIcon(doc["name"]!),
            color: Colors.indigo,
          ),  
                    title: Text(doc["name"]!),
                    subtitle: Text(doc["category"]!),
                    onTap: () async {
                      await OpenFile.open(doc["path"]!);
                    },
                  ),
                );
              },
            ),
    );
  }
}
