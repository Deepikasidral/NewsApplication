// news_feed_screen.dart
import 'package:flutter/material.dart';

class Article {
  final String title;
  final String excerpt;
  final List<String> tags;
  final String sentiment;

  Article({
    required this.title,
    required this.excerpt,
    required this.tags,
    required this.sentiment,
  });
}

class NewsFeedScreen extends StatefulWidget {
  const NewsFeedScreen({super.key});

  @override
  State<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends State<NewsFeedScreen> {
  final List<Article> _articles = List.generate(
    6,
    (i) => Article(
      title: "RBI Raises Repo Rate by 25 bps to 6.75%",
      excerpt:
          "The Reserve Bank of India (RBI) has increased the repo rate by 25 basis points to 6.75% in today's policy meeting. The move aims to curb inflationary pressures, but could impact borrowing costs for corporates and retail loans.",
      tags: ["#RBI", "#InterestRates", "#BankingStocks"],
      sentiment: "Slightly Negative for markets",
    ),
  );

  int _bottomIndex = 0;
  int _tabIndex = 0;
  final _searchController = TextEditingController();

  Widget _buildTopSearchRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      child: Row(
        children: [
          // Search box
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF6B3B3), // coral/pink look
                borderRadius: BorderRadius.circular(28),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: "Search here...",
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  const Icon(Icons.search, color: Colors.black54),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // profile avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const CircleAvatar(
              radius: 20,
              backgroundImage: NetworkImage(
                'https://i.pravatar.cc/300', // placeholder avatar
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabsRow() {
    final tabs = ["Home", "Markets", "For you", "Sector Wise", "Trending"];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: SizedBox(
        height: 46,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: tabs.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, idx) {
            final isSelected = idx == _tabIndex;
            return GestureDetector(
              onTap: () => setState(() => _tabIndex = idx),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFEDECF0) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    tabs[idx],
                    style: TextStyle(
                      color: isSelected ? Colors.black87 : Colors.black54,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildArticleCard(Article a) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.06), blurRadius: 8)],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              a.title,
              style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),

            // Excerpt
            Text(
              a.excerpt,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade800, height: 1.35),
            ),
            const SizedBox(height: 10),

            // Read more button + tags row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF05151).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "READ MORE",
                    style: TextStyle(color: Color(0xFFF05151), fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: a.tags
                        .map((t) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(t, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Sentiment line
            RichText(
              text: TextSpan(
                text: "Sentiment: ",
                style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade700, fontSize: 13),
                children: [
                  TextSpan(
                    text: a.sentiment,
                    style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeed() {
    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 10, bottom: 90),
        itemCount: _articles.length,
        itemBuilder: (context, index) => _buildArticleCard(_articles[index]),
      ),
    );
  }

  BottomNavigationBarItem _navItem(IconData icon, String label) {
    return BottomNavigationBarItem(icon: Icon(icon), label: label);
  }

  @override
  Widget build(BuildContext context) {
    // scaffold with safe area and bottom nav
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA), // light background like screenshot
      body: SafeArea(
        child: Column(
          children: [
            _buildTopSearchRow(),
            const SizedBox(height: 6),
            _buildTabsRow(),
            const SizedBox(height: 10),
            _buildFeed(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomIndex,
        onTap: (i) => setState(() => _bottomIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFEA6B6B),
        unselectedItemColor: Colors.black54,
        backgroundColor: Colors.white,
        items: [
          _navItem(Icons.feed, "Feed"),
          _navItem(Icons.local_fire_department, "Trending"),
          _navItem(Icons.currency_bitcoin, "Crypto"),
          _navItem(Icons.bookmark, "Saved"),
        ],
      ),
    );
  }
}
