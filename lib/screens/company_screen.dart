import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'company_news_screen.dart';

class CompanyScreen extends StatefulWidget {
  const CompanyScreen({super.key});

  @override
  State<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends State<CompanyScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _filteredCompanies = [];
  bool _isLoading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applySearch);
    _fetchCompanies();
  }

  @override
  void dispose() {
    _searchController.removeListener(_applySearch);
    _searchController.dispose();
    super.dispose();
  }

  void _applySearch() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredCompanies = List.from(_companies));
      return;
    }

    setState(() {
      _filteredCompanies = _companies.where((company) {
        final companyName = (company["NAME OF COMPANY"] ?? "").toLowerCase();
        final symbol = (company["SYMBOL"] ?? "").toLowerCase();
        return companyName.contains(query) || symbol.contains(query);
      }).toList();
    });
  }

  Future<void> _fetchCompanies() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final resp = await http.get(Uri.parse("http://192.168.1.7:5000/api/companies"));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        setState(() {
          _companies = (data as List).cast<Map<String, dynamic>>();
          _filteredCompanies = List.from(_companies);
        });
      } else {
        final errorBody = resp.body;
        setState(() {
          _error = "Failed to fetch companies from DB\nStatus: ${resp.statusCode}\nError: $errorBody";
        });
      }
    } catch (e) {
      setState(() {
        _error = "DB fetch failed: $e";
      });
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      appBar: AppBar(
        title: const Text("Companies"),
        backgroundColor: const Color(0xFFEA6B6B),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF6B3B3),
                  borderRadius: BorderRadius.circular(28),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: "Search companies...",
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const Icon(Icons.search, color: Colors.black54),
                  ],
                ),
              ),
            ),
            // Company List
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
                                onPressed: _fetchCompanies,
                                child: const Text("Retry"),
                              ),
                            ],
                          ),
                        )
                      : _filteredCompanies.isEmpty
                          ? const Center(child: Text("No companies found"))
                          : RefreshIndicator(
                              onRefresh: _fetchCompanies,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                itemCount: _filteredCompanies.length,
                                itemBuilder: (context, index) {
                                  final company = _filteredCompanies[index];
                                  final companyName = company["NAME OF COMPANY"] ?? "Unknown";
                                  final symbol = company["SYMBOL"] ?? "";

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14.0, vertical: 8),
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => CompanyNewsScreen(
                                              companyName: companyName,
                                            ),
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(14),
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
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    companyName,
                                                    style: const TextStyle(
                                                      fontSize: 16.5,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  if (symbol.isNotEmpty) ...[
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      "Symbol: $symbol",
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.grey.shade600,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            Icon(
                                              Icons.arrow_forward_ios,
                                              size: 16,
                                              color: Colors.grey.shade400,
                                            ),
                                          ],
                                        ),
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