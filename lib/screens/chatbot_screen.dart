import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/chat_message.dart';
import 'home_screen.dart';
import 'company_screen.dart';
import 'saved_screen.dart';
import 'events_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';


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
  int _bottomIndex = 0;
  bool _rateLimited = false;


  @override
void dispose() {
  _controller.dispose();
  _scrollController.dispose();
  super.dispose();
}


  // 🔹 Chatbot API URL (same as service)
  static const String _baseUrl = "http://10.244.218.93:8000/chat";
  // 👉 If testing on real phone, replace with your LAN IP

  // 🔹 SAME LOGIC as ChatbotService.askQuestion()
 Future<String> _askQuestion(String question) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString("userId");

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        "Content-Type": "application/json",
        "X-User-Id": userId ?? "",
      },
      body: jsonEncode({"question": question}),
    );

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
             "You’ve used all **5 questions for today**.\n"
             "Please try again **tomorrow** ⏳";
    }

    if (response.statusCode == 401) {
      return "❌ Session expired. Please login again.";
    }

    return "⚠️ Server error. Please try again.";

  } catch (e) {
    return "❌ Connection failed. Please check your internet.";
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
          Expanded(
            child: TextField(
                controller: _controller,
                enabled: !_rateLimited,
              decoration: const InputDecoration(
                hintText: "Ask about news, companies, impact...",
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Color(0xFFF05151)),
           onPressed: (_loading || _rateLimited) ? null : _sendMessage,

          )
        ],
      ),
    );
  }
@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFFF6F7FA),
    appBar: AppBar(
      title: const Text("Ask AI"),
      backgroundColor: const Color(0xFFF05151),
    ),
    body: Column(
  children: [
    Expanded(
      child: ListView.builder(
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

    bottomNavigationBar: BottomNavigationBar(
      currentIndex: _bottomIndex,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFFEA6B6B),
      unselectedItemColor: Colors.black54,
      onTap: (index) {
        if (index == _bottomIndex) return;

        setState(() => _bottomIndex = index);

        switch (index) {
          case 0:
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NewsFeedScreen()));
            break;

          case 1:
            // INDEX screen (if exists)
            break;

          case 2:
            // ASK AI → already here
            break;

          case 3:
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CompanyScreen()));
            break;

          case 4:
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const EventsScreen()));
            break;

          case 5:
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SavedNewsFeedScreen()));
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.newspaper), label: "NEWS"),
        BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: "INDEX"),
        BottomNavigationBarItem(icon: Icon(Icons.smart_toy), label: "ASK AI"),
        BottomNavigationBarItem(icon: Icon(Icons.business), label: "COMPANIES"),
        BottomNavigationBarItem(icon: Icon(Icons.event_available), label: "EVENTS"),
        BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: "Saved"),
      ],
    ),
  );
}
}

