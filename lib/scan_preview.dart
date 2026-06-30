import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image/image.dart' as img;
class ScanPreviewScreen extends StatefulWidget {
  final List<File> scannedImages;

  const ScanPreviewScreen({
    super.key,
    required this.scannedImages,
  });

  @override
  State<ScanPreviewScreen> createState() => _ScanPreviewScreenState();
}

class _ScanPreviewScreenState extends State<ScanPreviewScreen> {
  late List<File> pages;
  Map<int, int> pageRotations = {};

  @override
  void initState() {
    super.initState();
    pages = List.from(widget.scannedImages);
  }

 void rotatePage(int index, bool clockwise) {
  setState(() {
    int current = pageRotations[index] ?? 0;

    current += clockwise ? 90 : -90;

    pageRotations[index] = current;
  });
}

  Future cropPage(int index) async {
  final cropped = await ImageCropper().cropImage(
    sourcePath: pages[index].path,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: "Crop Page",
      ),
    ],
  );

  if (cropped == null) return;

  setState(() {
    pages[index] = File(cropped.path);
  });
}

 void showPageOptions(int index) {
  showModalBottomSheet(
    context: context,
    builder: (_) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.crop),
            title: const Text("Crop"),
            onTap: () {
              Navigator.pop(context);
              cropPage(index);
            },
          ),

          ListTile(
            leading: const Icon(Icons.rotate_left),
            title: const Text("Rotate Left"),
            onTap: () {
              Navigator.pop(context);
              rotatePage(index, false);
            },
          ),

         ListTile(
          leading: const Icon(Icons.rotate_right),
          title: const Text("Rotate Right"),
          onTap: () {
            Navigator.pop(context);
            rotatePage(index, true);
          },
        ),

          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text("Delete Page"),
            onTap: () {
              setState(() {
                pages.removeAt(index);
pageRotations.remove(index);
              });

              Navigator.pop(context);
            },
          ),
        ],
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${pages.length} Pages"),
      ),

      body: pages.isEmpty
    ? const Center(
        child: Text("No pages remaining"),
      )
    : ReorderableListView.builder(
    padding: const EdgeInsets.all(16),

    itemCount: pages.length,

    onReorder: (oldIndex, newIndex) {
      setState(() {
        if (newIndex > oldIndex) {
          newIndex--;
        }

        final item = pages.removeAt(oldIndex);

        pages.insert(newIndex, item);
      });
    },

    itemBuilder: (context, index) {
      return Container(
        key: ValueKey(pages[index].path),

        margin: const EdgeInsets.only(bottom: 24),

        child: GestureDetector(
          onTap: () {
            showPageOptions(index);
          },

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),

                child: Row(
                  children: [
                    Text(
                      "Page ${index + 1}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const Spacer(),

                    const Icon(Icons.drag_handle),
                  ],
                ),
              ),

              Container(
                width: double.infinity,

                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 6,
                      color: Colors.black12,
                    ),
                  ],
                ),

                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),

                  child:Transform.rotate(
  angle: ((pageRotations[index] ?? 0) * 3.1415926535) / 180,

  child: Image.file(
    pages[index],
    fit: BoxFit.fitWidth,
  ),
)
                ),
              ),
            ],
          ),
        ),
      );
    },
  ),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12),
        child: ElevatedButton(
          onPressed: () {
            Navigator.pop(
  context,
  {
    "pages": pages,
    "rotations": pageRotations,
  },
);
          },
          child: const Text("Create PDF"),
        ),
      ),
    );
  }
}