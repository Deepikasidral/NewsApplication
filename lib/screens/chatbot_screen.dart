import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/chat_message.dart';
import 'home_screen.dart';
import 'saved_screen.dart';
import 'events_screen.dart';
import 'profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';
import 'index_screen.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';


class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _loading = false;
  int _bottomIndex = 2;
  bool _rateLimited = false;
  String _userName = "there";
  InterstitialAd? _interstitialAd;
  bool _isShowingAd = false;

  static const String _sessionKey = "current_session_id";
  static const String _chatCacheKey = "session_chat_messages";
  static const int _maxMessages = 20;
  String? _currentSessionId;

Future<void> _initSession() async {
  final prefs = await SharedPreferences.getInstance();
  final savedSessionId = prefs.getString(_sessionKey);
  final now = DateTime.now().millisecondsSinceEpoch;
  
  if (savedSessionId != null) {
    final parts = savedSessionId.split('_');
    if (parts.length == 2) {
      final timestamp = int.tryParse(parts[1]) ?? 0;
      final hoursSince = (now - timestamp) / (1000 * 60 * 60);
      
      if (hoursSince < 24) {
        _currentSessionId = savedSessionId;
        await _loadCachedMessages();
        return;
      }
    }
  }
  
  _currentSessionId = 'session_$now';
  await prefs.setString(_sessionKey, _currentSessionId!);
  await prefs.remove(_chatCacheKey);
}

Future<void> _loadCachedMessages() async {
  final prefs = await SharedPreferences.getInstance();
  final cached = prefs.getString(_chatCacheKey);
  if (cached != null) {
    final List<dynamic> decoded = jsonDecode(cached);
    setState(() {
      _messages.addAll(decoded.map((e) => ChatMessage.fromJson(e)).toList());
    });
  }
}

Future<void> _saveChatToCache() async {
  final prefs = await SharedPreferences.getInstance();
  final messagesToSave = _messages.length > _maxMessages 
      ? _messages.sublist(_messages.length - _maxMessages) 
      : _messages;
  final encoded = jsonEncode(messagesToSave.map((e) => e.toJson()).toList());
  await prefs.setString(_chatCacheKey, encoded);
}


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
  _initSession();
  _loadInterstitialAd();
}

void _loadInterstitialAd() {
  InterstitialAd.load(
    adUnitId: 'ca-app-pub-6088749573646337/6577319196',
    request: const AdRequest(),
    adLoadCallback: InterstitialAdLoadCallback(
      onAdLoaded: (ad) {
        _interstitialAd = ad;
      },
      onAdFailedToLoad: (error) {
        debugPrint("Interstitial ad load failed: $error");
      },
    ),
  );
}





  @override
void dispose() {
  _controller.dispose();
  _scrollController.dispose();
  _interstitialAd?.dispose();
  super.dispose();
}


  // 🔹 ChatGPT API Configuration
  static final String _openAiApiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
  static const String _openAiApiUrl = "https://api.openai.com/v1/chat/completions";

  // 🔹 ChatGPT API Implementation
  Future<String> _askQuestion(String question) async {
    try {
      // Build conversation history in OpenAI format
      List<Map<String, String>> messages = [
        {
          "role": "system",
          "content": "You are a specialized financial AI assistant for a stock market news application. Your ONLY purpose is to help users with:\n\n"
                     "1. Stock market analysis and trends\n"
                     "2. Company financial information and performance\n"
                     "3. Investment strategies and portfolio advice\n"
                     "4. Market indices (NIFTY, BANK NIFTY, Sensex, etc.)\n"
                     "5. Sector analysis and commodity markets\n"
                     "6. Financial news interpretation\n"
                     "7. Trading concepts and terminology\n"
                     "8. Mutual funds, SIPs, and investment products\n"
                     "9. Risk management and diversification\n"
                     "10. Economic indicators and their impact on markets\n\n"
                     "STRICT RULES:\n"
                     "- ONLY answer questions related to finance, stocks, investments, and markets\n"
                     "- If asked about anything else (sports, entertainment, general knowledge, coding, etc.), politely decline and redirect to financial topics\n"
                     "- Do NOT provide personal financial advice - always add disclaimers\n"
                     "- Focus on Indian stock market (NSE, BSE) but can discuss global markets when relevant\n"
                     "- Keep responses clear, concise, and actionable\n"
                     "- Use bullet points for better readability\n\n"
                     "If a question is outside your scope, respond with: \"I'm a financial assistant specialized in stock markets and investments. I can only help with finance-related questions. Please ask me about stocks, markets, investments, or financial news.\""
        }
      ];

      // Add conversation history
      for (var msg in _messages) {
        messages.add({
          "role": msg.isUser ? "user" : "assistant",
          "content": msg.text
        });
      }

      // Add current question
      messages.add({
        "role": "user",
        "content": question
      });

      debugPrint('🔍 Sending request to ChatGPT API');
      debugPrint('🔍 Question: $question');
      debugPrint('🔍 History length: ${messages.length}');

      final response = await http.post(
        Uri.parse(_openAiApiUrl),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $_openAiApiKey",
        },
        body: jsonEncode({
          "model": "gpt-3.5-turbo",
          "messages": messages,
          "max_tokens": 1000,
          "temperature": 0.7,
        }),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception('⏱️ Request timeout - ChatGPT is taking too long to respond');
        },
      );

      debugPrint('✅ Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final answer = data['choices']?[0]?['message']?['content'];
        
        if (answer != null && answer.isNotEmpty) {
          debugPrint('✅ Got response from ChatGPT');
          return answer.trim();
        } else {
          return "❌ No response from ChatGPT. Please try again.";
        }
      }

      // Handle rate limiting
      if (response.statusCode == 429) {
        setState(() {
          _rateLimited = true;
        });
        return "🚫 **Rate limit reached**\n\n"
               "Too many requests. Please wait a moment and try again.";
      }

      // Handle authentication errors
      if (response.statusCode == 401) {
        return "❌ **Authentication Error**\n\n"
               "Invalid API key. Please contact support.";
      }

      // Handle other errors
      final errorData = jsonDecode(response.body);
      final errorMessage = errorData['error']?['message'] ?? 'Unknown error';
      
      return "⚠️ **ChatGPT Error (${response.statusCode})**\n\n"
             "$errorMessage";

    } on http.ClientException catch (e) {
      debugPrint('❌ Network Error: $e');
      return "❌ **Network Error**\n\n"
             "Cannot connect to ChatGPT API.\n\n"
             "**Possible causes:**\n"
             "• No internet connection\n"
             "• Network firewall blocking OpenAI\n"
             "• DNS resolution issues";
    } on TimeoutException catch (e) {
      debugPrint('❌ Timeout Error: $e');
      return "⏱️ **Request Timeout**\n\n"
             "ChatGPT is taking too long to respond.\n\n"
             "**Try:**\n"
             "• Ask a simpler question\n"
             "• Check your internet connection\n"
             "• Wait a moment and try again";
    } catch (e) {
      debugPrint('❌ Unexpected Error: $e');
      return "❌ **Unexpected Error**\n\n"
             "$e\n\n"
             "Please try again or contact support.";
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
    await _saveChatToCache();

    final reply = await _askQuestion(text);

    setState(() {
      _messages.add(ChatMessage(text: reply, isUser: false));
      _loading = false;
    });
    _scrollToBottom();
    await _saveChatToCache();
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
  super.build(context);
  return Scaffold(
    backgroundColor: const Color(0xFFF6F7FA),
    appBar: AppBar(
      title: const Text("Ask AI"),
      backgroundColor: const Color(0xFFF05151),
      actions: [
        if (_messages.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'New Chat',
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove(_chatCacheKey);
              _currentSessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
              await prefs.setString(_sessionKey, _currentSessionId!);
              setState(() {
                _messages.clear();
                _rateLimited = false;
              });
            },
          ),
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
              destination = const NewsFeedScreen();
              break;
            case 1:
              destination = const IndexScreen();
              break;
            case 2:
              destination = const ChatbotScreen();
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

  if (_interstitialAd != null && !_isShowingAd) {
    _isShowingAd = true;
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _isShowingAd = false;
        _loadInterstitialAd();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => destination!),
          );
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _isShowingAd = false;
        _loadInterstitialAd();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => destination!),
          );
        }
      },
    );
    _interstitialAd!.show();
  } else {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => destination!),
    );
  }
},
        items: [
          _navItem(label: "NEWS", active: 'assets/icons/News Red.svg', inactive: 'assets/icons/News.svg', index: 0),
          _navItem(label: "INDEX", active: 'assets/icons/Index red.svg', inactive: 'assets/icons/Index.svg', index: 1),
          _navItem(label: "ASK AI", active: 'assets/icons/Ask AI Red.svg', inactive: 'assets/icons/Ask AI.svg', index: 2),
          _navItem(label: "EVENTS", active: 'assets/icons/Calender Red.svg', inactive: 'assets/icons/Calender.svg', index: 3),
          _navItem(label: "SAVED", active: 'assets/icons/Save red.svg', inactive: 'assets/icons/Save.svg', index: 4),
        ],
),

),

  );
}
}

