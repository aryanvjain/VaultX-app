import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdfx/pdfx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;

 Future<String> extractTextFromPdf(String pdfPath) async {
  // ---------- Try extracting embedded text first ----------
  try {
    final file = File(pdfPath);
    final bytes = await file.readAsBytes();

    final document = sfpdf.PdfDocument(inputBytes: bytes);

    final extractedText = sfpdf.PdfTextExtractor(document).extractText();

    document.dispose();

    if (extractedText.trim().isNotEmpty) {
      print("Using embedded PDF text");
      return extractedText;
    }
  } catch (e) {
    print("Embedded text extraction failed: $e");
  }

  // ---------- Fallback to OCR ----------
  print("No embedded text found. Starting OCR...");

  final recognizer = TextRecognizer();
  final pdf = await PdfDocument.openFile(pdfPath);

  String combinedText = "";

  for (int pageNumber = 1;
      pageNumber <= pdf.pagesCount;
      pageNumber++) {

    final page = await pdf.getPage(pageNumber);

    final pageImage = await page.render(
      width: page.width * 3,
      height: page.height * 3,
      format: PdfPageImageFormat.png,
    );

    await page.close();

    if (pageImage == null) continue;

    final tempDir = await getTemporaryDirectory();

    final imageFile = File(
      "${tempDir.path}/vaultx_page_$pageNumber.png",
    );

    await imageFile.writeAsBytes(pageImage.bytes);

    final inputImage = InputImage.fromFilePath(imageFile.path);

    final result = await recognizer.processImage(inputImage);

    combinedText += "${result.text}\n";

    if (await imageFile.exists()) {
      await imageFile.delete();
    }
  }

  await recognizer.close();
  await pdf.close();

  print("OCR completed");

  return combinedText.trim();
}

Future<String> extractTextFromImage(String imagePath) async {
  final inputImage = InputImage.fromFilePath(imagePath);

  final recognizer = TextRecognizer();

  final result =
      await recognizer.processImage(inputImage);

  await recognizer.close();

  return result.text;
}

Future<void> saveOCRText(
  String path,
  String text,
) async {
  final prefs =
      await SharedPreferences.getInstance();

  await prefs.setString(
    "ocr_$path",
    text,
  );
}

Future<String> getOCRText(
  String path,
) async {
  final prefs =
      await SharedPreferences.getInstance();

  return prefs.getString(
        "ocr_$path",
      ) ??
      "";
}