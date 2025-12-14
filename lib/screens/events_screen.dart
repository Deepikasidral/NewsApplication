// lib/screens/events_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  int _selectedTab = 0;
  final List<String> _tabs = ["Corporate Events", "Macro Events"];

  // Sample data - In real app, fetch from API
  final List<CorporateEvent> _upcomingEvents = [
    CorporateEvent(
      title: "Reliance Industries AGM",
      date: DateTime.now().add(const Duration(days: 2)),
      time: "10:00 AM",
      description: "Annual General Meeting for shareholders",
      type: "AGM",
      highlight: true,
    ),
    CorporateEvent(
      title: "TCS Quarterly Results",
      date: DateTime.now().add(const Duration(days: 1)),
      time: "3:00 PM",
      description: "Q4 FY2024 Results Announcement",
      type: "Results",
      highlight: true,
    ),
    CorporateEvent(
      title: "Infosys Board Meeting",
      date: DateTime.now().add(const Duration(days: 3)),
      time: "11:30 AM",
      description: "Board meeting to discuss expansion plans",
      type: "Board Meeting",
      highlight: true,
    ),
  ];

  final List<CorporateEvent> _otherCorporateEvents = [
    CorporateEvent(
      title: "HDFC Bank Investor Meet",
      date: DateTime.now().add(const Duration(days: 5)),
      time: "2:00 PM",
      description: "Meeting with institutional investors",
      type: "Investor Meet",
      highlight: false,
    ),
    CorporateEvent(
      title: "ITC Product Launch",
      date: DateTime.now().add(const Duration(days: 7)),
      time: "6:00 PM",
      description: "Launch of new FMCG product line",
      type: "Product Launch",
      highlight: false,
    ),
    CorporateEvent(
      title: "Asian Paints Factory Inauguration",
      date: DateTime.now().add(const Duration(days: 10)),
      time: "9:00 AM",
      description: "New manufacturing plant inauguration",
      type: "Inauguration",
      highlight: false,
    ),
    CorporateEvent(
      title: "Bajaj Auto Earnings Call",
      date: DateTime.now().add(const Duration(days: 4)),
      time: "4:30 PM",
      description: "Quarterly earnings conference call",
      type: "Earnings Call",
      highlight: false,
    ),
  ];

  final List<MacroEvent> _macroEvents = [
    MacroEvent(
      title: "RBI Monetary Policy Meeting",
      date: DateTime.now().add(const Duration(days: 3)),
      impact: "High",
      description: "Interest rate decision and policy stance",
      country: "India",
    ),
    MacroEvent(
      title: "US Fed Interest Rate Decision",
      date: DateTime.now().add(const Duration(days: 5)),
      impact: "Very High",
      description: "Federal Reserve rate decision and guidance",
      country: "USA",
    ),
    MacroEvent(
      title: "Union Budget 2024",
      date: DateTime.now().add(const Duration(days: 15)),
      impact: "High",
      description: "Annual budget announcement",
      country: "India",
    ),
    MacroEvent(
      title: "Eurozone Inflation Data",
      date: DateTime.now().add(const Duration(days: 2)),
      impact: "Medium",
      description: "CPI and inflation rate announcement",
      country: "Eurozone",
    ),
    MacroEvent(
      title: "OPEC Meeting",
      date: DateTime.now().add(const Duration(days: 8)),
      impact: "High",
      description: "Oil production quota discussions",
      country: "Global",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Back Button and Title
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F7FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 18,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    "Events Calendar",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  const CircleAvatar(
                    radius: 20,
                    backgroundImage: NetworkImage('https://i.pravatar.cc/300'),
                  ),
                ],
              ),
            ),

            // Tabs
            Container(
              height: 60,
              color: Colors.white,
              child: Row(
                children: _tabs.asMap().entries.map((entry) {
                  final index = entry.key;
                  final tab = entry.value;
                  final selected = _selectedTab == index;
                  
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = index),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: selected ? const Color(0xFFF05151) : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            tab,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                              color: selected ? const Color(0xFFF05151) : Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Content based on selected tab
            Expanded(
              child: _selectedTab == 0
                  ? _buildCorporateEventsTab()
                  : _buildMacroEventsTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCorporateEventsTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Upcoming Corporate Events Section
            const Text(
              "Upcoming Corporate Events",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Actions today highlight",
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 16),

            // Upcoming Events List
            ..._upcomingEvents.map((event) => _buildEventCard(event)),

            const SizedBox(height: 24),

            // Other Corporate Events Section
            const Text(
              "Other Corporate Events",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 16),

            ..._otherCorporateEvents.map((event) => _buildEventCard(event)),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroEventsTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Macro Events",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Important economic events and announcements",
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 16),

            ..._macroEvents.map((event) => _buildMacroEventCard(event)),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(CorporateEvent event) {
    final dateFormatted = DateFormat('MMM dd, yyyy').format(event.date);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: event.highlight ? const Color(0xFFF05151).withOpacity(0.3) : Colors.grey.shade200,
          width: event.highlight ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: event.highlight 
                      ? const Color(0xFFF05151).withOpacity(0.1)
                      : const Color(0xFFF6F7FA),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  event.type,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: event.highlight ? const Color(0xFFF05151) : Colors.black54,
                  ),
                ),
              ),
              if (event.highlight) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE8E8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    "TODAY'S HIGHLIGHT",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF05151),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              const Icon(
                Icons.notifications_none,
                color: Colors.black54,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            event.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            event.description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 16,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                dateFormatted,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.access_time,
                size: 16,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                event.time,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF05151).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroEventCard(MacroEvent event) {
    final dateFormatted = DateFormat('MMM dd, yyyy').format(event.date);
    
    Color impactColor;
    switch (event.impact.toLowerCase()) {
      case 'very high':
        impactColor = const Color(0xFFF05151);
        break;
      case 'high':
        impactColor = const Color(0xFFFF9800);
        break;
      default:
        impactColor = const Color(0xFF4CAF50);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  event.country,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: impactColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "Impact: ${event.impact}",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: impactColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            event.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            event.description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 16,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                dateFormatted,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.public,
                size: 18,
                color: Colors.black54,
              ),
              const SizedBox(width: 4),
              Text(
                "Global Impact",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CorporateEvent {
  final String title;
  final DateTime date;
  final String time;
  final String description;
  final String type;
  final bool highlight;

  CorporateEvent({
    required this.title,
    required this.date,
    required this.time,
    required this.description,
    required this.type,
    required this.highlight,
  });
}

class MacroEvent {
  final String title;
  final DateTime date;
  final String impact;
  final String description;
  final String country;

  MacroEvent({
    required this.title,
    required this.date,
    required this.impact,
    required this.description,
    required this.country,
  });
}