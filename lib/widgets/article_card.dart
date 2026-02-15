import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/article.dart';

class ArticleCard extends StatelessWidget {
  final Article article;
  final Set<String> savedIds;
  final Function(String) onToggleSave;
  final Function(String) onOpenTradingView;
  final Function(List<String>) onFetchCompanies;
  final Function(String) onFetchSector;
  final Function(List<String>) onFetchCommodities;
  final Function(Article) onOpenFullStory;

  const ArticleCard({
    super.key,
    required this.article,
    required this.savedIds,
    required this.onToggleSave,
    required this.onOpenTradingView,
    required this.onFetchCompanies,
    required this.onFetchSector,
    required this.onFetchCommodities,
    required this.onOpenFullStory,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormatted =
        DateFormat.yMMMd().add_jm().format(article.date);

    Color sentimentColor(String s) {
      switch (s.toLowerCase()) {
        case "very bullish":
          return const Color(0xFF0F9D58);
        case "bullish":
          return const Color(0xFF5AD079);
        case "neutral":
          return const Color(0xFFA6A49A);
        case "bearish":
          return const Color(0xFFEB6969);
        case "very bearish":
          return const Color(0xFFD93025);
        default:
          return Colors.grey;
      }
    }

    Color impactColor(String i) {
      switch (i.toLowerCase()) {
        case "very high":
          return const Color(0xFFFFB000);
        case "high":
          return const Color(0xFFFF9B5B);
        case "mild":
          return const Color(0xFFFFCD79);
        case "negligible":
          return const Color(0xFFFFCEAF);
        default:
          return Colors.grey;
      }
    }

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onOpenFullStory(article),
        child: Container(
          margin:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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

              Text(
                article.title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    article.summary,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              if (article.companies.isNotEmpty)
                Text(
                  "Companies: ${article.companies.join(', ')}",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),

              const SizedBox(height: 8),

              if (article.sentiment.isNotEmpty)
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: "Sentiment: ",
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: article.sentiment,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: sentimentColor(article.sentiment),
                        ),
                      ),
                    ],
                  ),
                ),

              if (article.impact.isNotEmpty)
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: "Impact: ",
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: article.impact,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: impactColor(article.impact),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 14),

              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [

                  Text(
                    dateFormatted,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),

                  Row(
                    children: [

                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(),
                        icon: Image.asset(
                          "assets/tradingview.png",
                          height: 32,
                          width: 32,
                        ),
                        onPressed: () =>
                            onFetchCompanies(article.companies),
                      ),

                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(),
                        icon: Icon(
                          savedIds.contains(article.id)
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          size: 32,
                          color:
                              savedIds.contains(article.id)
                                  ? Colors.red
                                  : Colors.grey,
                        ),
                        onPressed: () =>
                            onToggleSave(article.id),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
