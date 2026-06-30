import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

Future<String?> generatePdfThumbnail(
  String pdfPath,
) async {
  try {
    final document =
        await PdfDocument.openFile(
      pdfPath,
    );

    final page =
        await document.getPage(1);

    final pageImage =
        await page.render(
      width: page.width,
      height: page.height,
      format: PdfPageImageFormat.png,
    );

    await page.close();
    await document.close();

    if (pageImage == null) return null;

    final appDir =
        await getApplicationDocumentsDirectory();

    final thumbnailPath =
        "${appDir.path}/${DateTime.now().millisecondsSinceEpoch}_thumb.png";

    final file =
        File(thumbnailPath);

    await file.writeAsBytes(
      pageImage.bytes,
    );

    return thumbnailPath;
  } catch (e) {
    return null;
  }
}