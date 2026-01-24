import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/chat_message.dart';
import 'home_screen.dart';
import 'company_screen.dart';
import 'saved_screen.dart';
import 'events_screen.dart';
import 'profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';


class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _loading = false;
  int _bottomIndex = 1;
  bool _rateLimited = false;
  String _userName = "there";


Future<void> _loadUserName() async {
  final prefs = await SharedPreferences.getInstance();
  setState(() {
    _userName = prefs.getString("userName") ?? "there";
  });
}
@override
void initState() {
  super.initState();
  _loadUserName();
}





  @override
void dispose() {
  _controller.dispose();
  _scrollController.dispose();
  super.dispose();
}


  // 🔹 Chatbot API URL
  static const String _baseUrl = "http://13.51.242.86:8000/chat";

  // 🔹 SAME LOGIC as ChatbotService.askQuestion()
 Future<String> _askQuestion(String question) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString("userId");

    debugPrint('🔍 Sending request to: $_baseUrl');
    debugPrint('🔍 User ID: $userId');
    debugPrint('🔍 Question: $question');

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        "Content-Type": "application/json",
        "X-User-Id": userId ?? "",
      },
      body: jsonEncode({"question": question}),
    ).timeout(const Duration(seconds: 30));

    debugPrint('✅ Response status: ${response.statusCode}');
    debugPrint('✅ Response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["answer"] ?? "No response";
    }

    // 🔒 RATE LIMIT HIT
    if (response.statusCode == 429) {
      setState(() {
        _rateLimited = true;
      });

      return "🚫 **Daily limit reached**\n\n"
             "You've used all **5 questions for today**.\n"
             "Please try again **tomorrow** ⏳";
    }

    if (response.statusCode == 401) {
      return "❌ Session expired. Please login again.";
    }

    // 🔴 Better error message with full response
    return "⚠️ Server error (${response.statusCode})\n\n"
           "Response: ${response.body.length > 200 ? response.body.substring(0, 200) + '...' : response.body}";

  } catch (e) {
    debugPrint('❌ Error: $e');
    return "❌ Connection failed: $e\n\n"
           "Check if backend is running:\n"
           "sudo systemctl status mcp-server";
  }
}


  void _scrollToBottom() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  });
}

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _loading = true;
    });
    _scrollToBottom(); 
    _controller.clear();

    final reply = await _askQuestion(text);

    setState(() {
      _messages.add(ChatMessage(text: reply, isUser: false));
      _loading = false;
    });
    _scrollToBottom(); 
  }

  Widget _buildAskAIHome() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(
      children: [
        const Spacer(flex: 2),

        

        const SizedBox(height: 24),

        /// GREETING
        Text(
          "Hi $_userName,",
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 8),

              Text(
        "What would you like to know about today’s markets?",
        textAlign: TextAlign.center, // ✅ CENTER TEXT
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w400,
          color: Colors.black54,
        ),
      ),


        const SizedBox(height: 32),

        _buildSuggestion("Help me understand today's market trend"),
        _buildSuggestion("Ask about 5 top volatile stocks today"),
        _buildSuggestion("Ask about best funds to start sip in"),

        const Spacer(flex: 3),
      ],
    ),
  );
}
Widget _buildSuggestion(String text) {
  return GestureDetector(
    onTap: () {
      _controller.text = text;
      _sendMessage();
    },
    child: Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.05),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 18, color: Color(0xFFF05151)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(fontSize: 14.5),
            ),
          ),
        ],
      ),
    ),
  );
}


  Widget _buildMessage(ChatMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: msg.isUser
              ? const Color(0xFFF05151)
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(14),
        ),
        child: MarkdownBody(
  data: msg.text,
  selectable: true,
  styleSheet: MarkdownStyleSheet(
    p: TextStyle(
      color: msg.isUser ? Colors.white : Colors.black87,
      fontSize: 15,
    ),
    strong: TextStyle(
      color: msg.isUser ? Colors.white : Colors.black87,
      fontWeight: FontWeight.bold,
    ),
    em: TextStyle(
      color: msg.isUser ? Colors.white : Colors.black87,
      fontStyle: FontStyle.italic,
    ),
    h3: TextStyle(
      color: msg.isUser ? Colors.white : Colors.black87,
      fontSize: 16,
      fontWeight: FontWeight.bold,
    ),
    listBullet: TextStyle(
      color: msg.isUser ? Colors.white : Colors.black87,
    ),
  ),
),

      ),
    );
  }
  

  Widget _buildInputBar() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(color: Colors.black12, blurRadius: 6),
      ],
    ),
    child: Row(
      children: [

        /// 📷 CAMERA ICON
        IconButton(
          icon: const Icon(
            Icons.camera_alt_outlined,
            color: Colors.grey,
          ),
          onPressed: () {
            // TODO: open camera / image picker later
          },
        ),

        /// TEXT FIELD
        Expanded(
          child: TextField(
            controller: _controller,
            enabled: !_rateLimited,
            decoration: InputDecoration(
              hintText: "Ask anything",
              hintStyle: GoogleFonts.poppins(color: Colors.grey),
              border: InputBorder.none,
            ),
          ),
        ),

        /// ➤ SEND BUTTON
        IconButton(
          icon: const Icon(
            Icons.send,
            color: Color(0xFFF05151),
          ),
          onPressed: (_loading || _rateLimited) ? null : _sendMessage,
        ),
      ],
    ),
  );
}


  BottomNavigationBarItem _navItem({
  required String label,
  required String active,
  required String inactive,
  required int index,
}) {
  final bool selected = _bottomIndex == index;

  return BottomNavigationBarItem(
    icon: SvgPicture.asset(
      selected ? active : inactive,
      height: 22,
    ),
    label: label,
    tooltip: label,
  );
}
@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFFF6F7FA),
    appBar: AppBar(
      title: const Text("Ask AI"),
      backgroundColor: const Color(0xFFF05151),
      actions: [
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
          child: const Padding(
            padding: EdgeInsets.only(right: 16),
            child: CircleAvatar(
  radius: 18,
  backgroundColor: Color(0xFFE0E0E0),
  child: Icon(
    Icons.person,
    size: 18,
    color: Color(0xFF757575),
  ),
),
          ),
        ),
      ],
    ),
    body: Column(
  children: [
   Expanded(
      child: _messages.isEmpty
          ? _buildAskAIHome()   // 👈 GOOGLE-STYLE HOME
          : ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (_, i) => _buildMessage(_messages[i]),
            ),
    ),

    if (_loading)
      const Padding(
        padding: EdgeInsets.all(8.0),
        child: CircularProgressIndicator(strokeWidth: 2),
      ),

    // 🔒 RATE LIMIT MESSAGE (ADD HERE)
    if (_rateLimited)
      Container(
        padding: const EdgeInsets.all(10),
        color: Colors.red.shade100,
        child: const Text(
          "🚫 Daily limit reached. Try again tomorrow.",
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),

    _buildInputBar(),
  ],
),

    bottomNavigationBar: Container(
  decoration: const BoxDecoration(
    color: Colors.white,
    border: Border(
      top: BorderSide(color: Color(0xFFE0E0E0), width: 0.8),
    ),
  ),
  child: BottomNavigationBar(
  currentIndex: _bottomIndex,
  type: BottomNavigationBarType.fixed,
  backgroundColor: Colors.white,
  elevation: 0,

  // 🔥 THIS FIXES BLUE TEXT
  selectedItemColor: const Color(0xFFEA6B6B),
  unselectedItemColor: Colors.black54,

  showUnselectedLabels: true,

  selectedLabelStyle: GoogleFonts.poppins(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.2,
  ),
  unselectedLabelStyle: GoogleFonts.poppins(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.2,
  ),
 onTap: (index) {
  if (index == _bottomIndex) return;

  Widget? destination;

  switch (index) {
    case 0:
      destination=const NewsFeedScreen();
      break;

    case 1:
      destination = const ChatbotScreen();
      break;

    case 2:
      destination = const CompanyScreen();
      break;

    case 3:
      destination = const EventsScreen();
      break;

    case 4:
      destination = const SavedNewsFeedScreen();
      break;

    default:
      return;
  }

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => destination!),
  );
},


  items: [
    _navItem(
      label: "NEWS",
      active: 'assets/icons/News Red.svg',
      inactive: 'assets/icons/News.svg',
      index: 0,
    ),
    _navItem(
      label: "ASK AI",
      active: 'assets/icons/Ask AI Red.svg',
      inactive: 'assets/icons/Ask AI.svg',
      index: 1,
    ),
    _navItem(
      label: "COMPANIES",
      active: 'assets/icons/Graph Red.svg',
      inactive: 'assets/icons/Graph.svg',
      index: 2,
    ),
    _navItem(
      label: "EVENTS",
      active: 'assets/icons/Calender Red.svg',
      inactive: 'assets/icons/Calender.svg',
      index: 3,
    ),
    _navItem(
      label: "SAVED",
      active: 'assets/icons/Save red.svg',
      inactive: 'assets/icons/Save.svg',
      index: 4,
    ),
  ],
),

),

  );
}
}

