import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class CompanyNewsScreen extends StatefulWidget {
  final String companyName;

  const CompanyNewsScreen({super.key, required this.companyName});

  @override
  State<CompanyNewsScreen> createState() => _CompanyNewsScreenState();
}

class _CompanyNewsScreenState extends State<CompanyNewsScreen> {
  List<Map<String, dynamic>> _news = [];
  bool _isLoading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchCompanyNews();
  }

  Future<void> _fetchCompanyNews() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // URL encode the company name
      final encodedName = Uri.encodeComponent(widget.companyName);
      final resp = await http.get(
          Uri.parse("http://192.168.1.7:5000/api/filtered-news/company/$encodedName"));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        setState(() {
          _news = (data as List).cast<Map<String, dynamic>>();
        });
      } else {
        final errorBody = resp.body;
        setState(() {
          _error =
              "Failed to fetch news\nStatus: ${resp.statusCode}\nError: $errorBody";
        });
      }
    } catch (e) {
      setState(() {
        _error = "DB fetch failed: $e";
      });
    }

    setState(() => _isLoading = false);
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "Date not available";
    try {
      // Try parsing the date format: "Friday, Oct 17, 2025 18:08:38"
      final date = DateFormat("EEEE, MMM dd, yyyy HH:mm:ss").parse(dateString);
      return DateFormat.yMMMd().add_jm().format(date);
    } catch (e) {
      // If parsing fails, return the original string
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      appBar: AppBar(
        title: const Text("Company News"),
        backgroundColor: const Color(0xFFEA6B6B),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Company Name Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFEA6B6B),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Company:",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.companyName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // News List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error.isNotEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _error,
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _fetchCompanyNews,
                                child: const Text("Retry"),
                              ),
                            ],
                          ),
                        )
                      : _news.isEmpty
                          ? const Center(child: Text("No news found for this company"))
                          : RefreshIndicator(
                              onRefresh: _fetchCompanyNews,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                itemCount: _news.length,
                                itemBuilder: (context, index) {
                                  final article = _news[index];
                                  final headline = article["Headline"] ?? "No headline";
                                  final publishedAt = article["PublishedAt"] ?? "";
                                  final summary = article["summary"] ?? "";

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14.0, vertical: 8),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: Colors.grey.shade200),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.grey.withOpacity(0.06),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Headline
                                          Text(
                                            headline,
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          // Published Date
                                          Row(
                                            children: [
                                              Icon(Icons.calendar_today,
                                                  size: 14,
                                                  color: Colors.grey.shade600),
                                              const SizedBox(width: 6),
                                              Text(
                                                _formatDate(publishedAt),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          // Summary
                                          if (summary.isNotEmpty) ...[
                                            const Text(
                                              "Summary:",
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFFEA6B6B),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              summary,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade800,
                                                height: 1.5,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}