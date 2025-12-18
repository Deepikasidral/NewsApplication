
// lib/screens/events_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  int _selectedTab = 0;
  final List<String> _tabs = ["Today", "Upcoming"];
  
  bool _isLoading = true;
  List<CorporateEvent> _todayEvents = [];
  List<CorporateEvent> _upcomingEvents = [];

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('http://192.168.1.6:5000/api/events'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        
        // Parse events from backend
        final List<CorporateEvent> allEvents = (data['events'] as List)
            .map((event) => CorporateEvent.fromJson(event))
            .toList();

        // Separate into today and upcoming
        _todayEvents = allEvents.where((event) {
          final eventDate = DateTime(event.date.year, event.date.month, event.date.day);
          return eventDate.isAtSameMomentAs(today);
        }).toList();

        _upcomingEvents = allEvents.where((event) {
          final eventDate = DateTime(event.date.year, event.date.month, event.date.day);
          return eventDate.isAfter(today);
        }).toList();

        setState(() {
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load events');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // Handle error - you might want to show a snackbar
      print('Error fetching events: $e');
    }
  }

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
                  IconButton(
                    onPressed: _fetchEvents,
                    icon: const Icon(Icons.refresh, color: Color(0xFFF05151)),
                  ),
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
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFF05151)))
                  : _selectedTab == 0
                      ? _buildTodayEventsTab()
                      : _buildUpcomingEventsTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayEventsTab() {
    if (_todayEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_note, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              "No events for today",
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _fetchEvents,
              child: const Text(
                "Refresh",
                style: TextStyle(color: Color(0xFFF05151)),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Today's Events Section
            const Text(
              "Today's Events",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "${_todayEvents.length} event${_todayEvents.length > 1 ? 's' : ''} scheduled for today",
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 16),

            // Today's Events List
            ..._todayEvents.map((event) => _buildEventCard(event, isToday: true)),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingEventsTab() {
    if (_upcomingEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              "No upcoming events",
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _fetchEvents,
              child: const Text(
                "Refresh",
                style: TextStyle(color: Color(0xFFF05151)),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Upcoming Events",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "${_upcomingEvents.length} event${_upcomingEvents.length > 1 ? 's' : ''} scheduled",
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 16),

            ..._upcomingEvents.map((event) => _buildEventCard(event, isToday: false)),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(CorporateEvent event, {required bool isToday}) {
    final dateFormatted = DateFormat('MMM dd, yyyy').format(event.date);
    final timeFormatted = DateFormat('hh:mm a').format(event.date);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isToday ? const Color(0xFFF05151).withOpacity(0.3) : Colors.grey.shade200,
          width: isToday ? 2 : 1,
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
                  color: isToday 
                      ? const Color(0xFFF05151).withOpacity(0.1)
                      : const Color(0xFFF6F7FA),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  event.type,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isToday ? const Color(0xFFF05151) : Colors.black54,
                  ),
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE8E8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    "TODAY",
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
                timeFormatted,
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
}

class CorporateEvent {
  final String id;
  final String title;
  final DateTime date;
  final String description;
  final String type;
  final String tags;
  final String headline;

  CorporateEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.description,
    required this.type,
    required this.tags,
    required this.headline,
  });

  factory CorporateEvent.fromJson(Map<String, dynamic> json) {
    return CorporateEvent(
      id: json['_id'] ?? json['id'],
      title: json['title'],
      date: DateTime.parse(json['date']),
      description: json['description'],
      type: json['type'],
      tags: json['tags'],
      headline: json['headline'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'date': date.toIso8601String(),
      'description': description,
      'type': type,
      'tags': tags,
      'headline': headline,
    };
  }
}

