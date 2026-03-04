import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'news_preview_sheet.dart';

class YahooNewsCard extends StatelessWidget {
  final Map news;

  const YahooNewsCard({
    super.key,
    required this.news,
  });

  @override
  Widget build(BuildContext context) {

    final title = news["title"] ?? "";
    final summary = news["summary"] ?? "";
    final publisher = news["publisher"] ?? "";
    final image = news["thumbnail"]?["resolutions"]?[0]?["url"];

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      splashColor: Colors.red.withOpacity(0.08),

      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(18),
            ),
          ),
          builder: (_) => NewsPreviewSheet(news: news),
        );
      },

      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // IMAGE (if exists)
            if (image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  image,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),

            if (image != null) const SizedBox(height: 12),

            // TITLE
            Text(
              title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 10),

            // SUMMARY
            if (summary.isNotEmpty)
              Text(
                summary,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  height: 1.5,
                ),
              ),

            const SizedBox(height: 12),

            // FOOTER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [

                Text(
                  publisher,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),

                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.grey.shade500,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}