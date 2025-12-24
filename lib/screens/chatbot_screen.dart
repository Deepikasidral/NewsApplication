// import 'package:flutter/material.dart';
// import '../models/chat_message.dart';
// import '../services/chatbot_service.dart';

// class ChatbotScreen extends StatefulWidget {
//   const ChatbotScreen({super.key});

//   @override
//   State<ChatbotScreen> createState() => _ChatbotScreenState();
// }

// class _ChatbotScreenState extends State<ChatbotScreen> {
//   final TextEditingController _controller = TextEditingController();
//   final List<ChatMessage> _messages = [];
//   bool _loading = false;

//   Future<void> _sendMessage() async {
//     final text = _controller.text.trim();
//     if (text.isEmpty) return;

//     setState(() {
//       _messages.add(ChatMessage(text: text, isUser: true));
//       _loading = true;
//     });

//     _controller.clear();

//     final reply = await ChatbotService.askQuestion(text);

//     setState(() {
//       _messages.add(ChatMessage(text: reply, isUser: false));
//       _loading = false;
//     });
//   }

//   Widget _buildMessage(ChatMessage msg) {
//     return Align(
//       alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
//       child: Container(
//         margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
//         padding: const EdgeInsets.all(12),
//         constraints: const BoxConstraints(maxWidth: 280),
//         decoration: BoxDecoration(
//           color: msg.isUser
//               ? const Color(0xFFF05151)
//               : Colors.grey.shade200,
//           borderRadius: BorderRadius.circular(14),
//         ),
//         child: Text(
//           msg.text,
//           style: TextStyle(
//             color: msg.isUser ? Colors.white : Colors.black87,
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildInputBar() {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         boxShadow: [
//           BoxShadow(color: Colors.black12, blurRadius: 6),
//         ],
//       ),
//       child: Row(
//         children: [
//           Expanded(
//             child: TextField(
//               controller: _controller,
//               decoration: const InputDecoration(
//                 hintText: "Ask about news, companies, impact...",
//                 border: InputBorder.none,
//               ),
//             ),
//           ),
//           IconButton(
//             icon: const Icon(Icons.send, color: Color(0xFFF05151)),
//             onPressed: _loading ? null : _sendMessage,
//           )
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Ask AI"),
//         backgroundColor: const Color(0xFFF05151),
//       ),
//       body: Column(
//         children: [
//           Expanded(
//             child: ListView.builder(
//               reverse: false,
//               itemCount: _messages.length,
//               itemBuilder: (_, i) => _buildMessage(_messages[i]),
//             ),
//           ),
//           if (_loading)
//             const Padding(
//               padding: EdgeInsets.all(8.0),
//               child: CircularProgressIndicator(strokeWidth: 2),
//             ),
//           _buildInputBar(),
//         ],
//       ),
//     );
//   }
// }

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/chat_message.dart';

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

  @override
void dispose() {
  _controller.dispose();
  _scrollController.dispose();
  super.dispose();
}


  // 🔹 Chatbot API URL (same as service)
  static const String _baseUrl = "http://10.69.144.93:8001/chat";
  // 👉 If testing on real phone, replace with your LAN IP

  // 🔹 SAME LOGIC as ChatbotService.askQuestion()
  Future<String> _askQuestion(String question) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"question": question}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["answer"] ?? "No response";
      } else {
        return "Server error. Please try again.";
      }
    } catch (e) {
      return "Connection failed. Check backend.";
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
        child: Text(
          msg.text,
          style: TextStyle(
            color: msg.isUser ? Colors.white : Colors.black87,
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
              decoration: const InputDecoration(
                hintText: "Ask about news, companies, impact...",
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Color(0xFFF05151)),
            onPressed: _loading ? null : _sendMessage,
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ask AI"),
        backgroundColor: const Color(0xFFF05151),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController, // ✅ ADD
              reverse: false,
              itemCount: _messages.length,
              itemBuilder: (_, i) => _buildMessage(_messages[i]),
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          _buildInputBar(),
        ],
      ),
    );
  }
}

