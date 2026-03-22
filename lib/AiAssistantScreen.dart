import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'api_config.dart';

// ── Message model ──────────────────────────────────────────────────────────────
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.time,
  });
}

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen>
    with TickerProviderStateMixin {

  final TextEditingController _inputController  = TextEditingController();
  final ScrollController       _scrollController = ScrollController();

  List<ChatMessage> messages     = [];
  bool              isTyping     = false;
  bool              isListening  = false; // kept for mic button UI state
  String            userStandard = "class10";

  // Novie bounce animation
  late AnimationController _bounceController;
  late Animation<double>   _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _loadUserStandard();
    _setupAnimation();
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  // ── Novie bounce animation ─────────────────────────────────────────────────
  void _setupAnimation() {
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
  }

  // ── load student standard from Firestore ──────────────────────────────────
  Future<void> _loadUserStandard() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .get();
      if (doc.exists) {
        setState(() {
          userStandard = doc["standard"]?.toString() ?? "class10";
        });
      }
    } catch (_) {}
  }

  // ── welcome message from Novie ─────────────────────────────────────────────
  void _addWelcomeMessage() {
    final standard = userStandard.contains("12") ? "Class 12" : "Class 10";
    messages.add(ChatMessage(
      text: "Hi! I'm Novie, your AI assistant 🤖\nI'm here to help you with your $standard Maths and Science topics.\nAsk me anything!",
      isUser: false,
      time:   DateTime.now(),
    ));
  }

  // ── send message ───────────────────────────────────────────────────────────
  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    _inputController.clear();

    setState(() {
      messages.add(ChatMessage(
        text:   text.trim(),
        isUser: true,
        time:   DateTime.now(),
      ));
      isTyping = true;
    });

    _scrollToBottom();

    // build chat history for context (last 6 messages)
    final history = messages
        .where((m) => m.text != messages.last.text)
        .take(6)
        .map((m) => {
      "role":    m.isUser ? "user" : "assistant",
      "content": m.text,
    })
        .toList();

    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/chat"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "message":      text.trim(),
          "standard":     userStandard,
          "chat_history": history,
          "language":     "english",
        }),
      );

      if (response.statusCode == 200) {
        final data  = jsonDecode(response.body);
        final reply = data["reply"] as String? ??
            "Sorry, I couldn't understand that. Please try again!";

        setState(() {
          messages.add(ChatMessage(
            text:   reply,
            isUser: false,
            time:   DateTime.now(),
          ));
          isTyping = false;
        });
      } else {
        _addErrorMessage();
      }
    } catch (e) {
      _addErrorMessage();
    }

    _scrollToBottom();
  }

  void _addErrorMessage() {
    setState(() {
      messages.add(ChatMessage(
        text:   "Sorry, I'm having trouble connecting. Please check your internet and try again!",
        isUser: false,
        time:   DateTime.now(),
      ));
      isTyping = false;
    });
  }

  // ── voice input — coming soon ──────────────────────────────────────────────
  Future<void> _startListening() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Voice input coming soon!"),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _stopListening() async {}

  // ── scroll to bottom ───────────────────────────────────────────────────────
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve:    Curves.easeOut,
        );
      }
    });
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final standard = userStandard.contains("12") ? "Class 12" : "Class 10";

    return Scaffold(
      body: Container(
        width:  double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0E3D), Color(0xFF081062), Color(0xFF0D47A1)],
            begin:  Alignment.topCenter,
            end:    Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [

              // ── header ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    IconButton(
                      icon:      const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Novie — AI Assistant",
                      style: TextStyle(
                        color:      Colors.white,
                        fontSize:   20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color:        Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        standard,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Novie avatar ──────────────────────────────────────────
              AnimatedBuilder(
                animation: _bounceAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _bounceAnimation.value),
                    child:  child,
                  );
                },
                child: Container(
                  height: 130,
                  width:  130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                    border: Border.all(
                      color: const Color(0xFF4FC3F7).withOpacity(0.4),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:        const Color(0xFF4FC3F7).withOpacity(0.2),
                        blurRadius:   20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      "assets/images/novie.png",
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.smart_toy_rounded,
                        size:  70,
                        color: Color(0xFF4FC3F7),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 6),

              if (isTyping)
                const Text(
                  "Novie is thinking...",
                  style: TextStyle(
                    color:     Color(0xFF4FC3F7),
                    fontSize:  13,
                    fontStyle: FontStyle.italic,
                  ),
                ),

              const SizedBox(height: 10),

              // ── chat messages ─────────────────────────────────────────
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding:    const EdgeInsets.symmetric(horizontal: 16),
                  itemCount:  messages.length + (isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == messages.length) {
                      return _buildTypingBubble();
                    }
                    return _buildMessageBubble(messages[index]);
                  },
                ),
              ),

              // ── input bar ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                ),
                child: Row(
                  children: [

                    // mic button — coming soon
                    GestureDetector(
                      onTap: isListening ? _stopListening : _startListening,
                      child: Container(
                        width:  44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isListening
                              ? Colors.red.withOpacity(0.8)
                              : Colors.white.withOpacity(0.15),
                        ),
                        child: Icon(
                          isListening ? Icons.mic : Icons.mic_none,
                          color: Colors.white,
                          size:  22,
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // text input
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color:        Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.2)),
                        ),
                        child: TextField(
                          controller:      _inputController,
                          style:           const TextStyle(
                              color: Colors.white, fontSize: 14),
                          maxLines:        null,
                          textInputAction: TextInputAction.send,
                          onSubmitted:     _sendMessage,
                          decoration: const InputDecoration(
                            hintText:       "Ask Novie anything...",
                            hintStyle:      TextStyle(
                                color: Colors.white38, fontSize: 14),
                            border:         InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // send button
                    GestureDetector(
                      onTap: () => _sendMessage(_inputController.text),
                      child: Container(
                        width:  44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)],
                          ),
                        ),
                        child: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size:  20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── message bubble ─────────────────────────────────────────────────────────
  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
        isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [

          if (!isUser) ...[
            Container(
              width:  30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4FC3F7).withOpacity(0.2),
              ),
              child: const Icon(
                  Icons.smart_toy_rounded,
                  color: Color(0xFF4FC3F7),
                  size:  18),
            ),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF0288D1)
                    : Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(16),
                  topRight:    const Radius.circular(16),
                  bottomLeft:  Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser
                    ? null
                    : Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  color:    isUser
                      ? Colors.white
                      : Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  height:   1.5,
                ),
              ),
            ),
          ),

          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width:  30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.15),
              ),
              child: const Icon(
                  Icons.person, color: Colors.white70, size: 18),
            ),
          ],
        ],
      ),
    );
  }

  // ── typing bubble ──────────────────────────────────────────────────────────
  Widget _buildTypingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width:  30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF4FC3F7).withOpacity(0.2),
            ),
            child: const Icon(
                Icons.smart_toy_rounded,
                color: Color(0xFF4FC3F7),
                size:  18),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color:        Colors.white.withOpacity(0.12),
              borderRadius: const BorderRadius.only(
                topLeft:     Radius.circular(16),
                topRight:    Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft:  Radius.circular(4),
              ),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children:     List.generate(3, (i) => _dot(i)),
            ),
          ),
        ],
      ),
    );
  }

  // ── animated typing dot ────────────────────────────────────────────────────
  Widget _dot(int index) {
    return TweenAnimationBuilder<double>(
      tween:    Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 200)),
      builder:  (context, value, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width:  8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color.lerp(
              Colors.white30,
              const Color(0xFF4FC3F7),
              value,
            ),
          ),
        );
      },
    );
  }
}