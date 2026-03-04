import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class NewsPreviewSheet extends StatelessWidget {
  final Map news;

  const NewsPreviewSheet({
    super.key,
    required this.news,
  });

  Future<void> openArticle() async {
    final url = news["link"];

    if (url != null) {
      await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    final title = news["title"] ?? "";
    final summary = news["summary"] ?? "";
    final publisher = news["publisher"] ?? "";
    final image = news["thumbnail"]?["resolutions"]?[0]?["url"];

    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // IMAGE
            if (image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  image,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),

            const SizedBox(height: 12),

            // TITLE
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 10),

            // SUMMARY
            Text(
              summary,
              style: GoogleFonts.poppins(
                fontSize: 15,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 14),

            Text(
              publisher,
              style: GoogleFonts.poppins(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 20),

            // BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: openArticle,
                child: Text(
                  "Read Full Article",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}