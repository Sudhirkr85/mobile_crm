import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _isListening = false;
  bool _isLoading = false;
  bool _isSpeaking = false;
  bool _speechAvailable = false;
  String _selectedLang = 'hindi';
  String _userDisplayName = '';

  late AnimationController _voicePulseController;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
    _loadUserName();
    _voicePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  Future<void> _loadUserName() async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    var userName = apiService.userName;

    if ((userName == null || userName.trim().isEmpty) &&
        await apiService.tryAutoLogin()) {
      userName = apiService.userName;
    }

    final firstName = (userName ?? '').trim().split(' ').first;
    if (!mounted) return;

    setState(() {
      _userDisplayName = firstName;
      _messages
        ..clear()
        ..add(
          _ChatMessage(
            text: _buildWelcomeMessage(firstName),
            isUser: false,
            lang: _selectedLang,
          ),
        );
    });
  }

  String _buildWelcomeMessage(String firstName) {
    final hour = DateTime.now().hour;
    var salutation = 'Good Morning';
    var icon = '🌅';
    if (hour >= 12 && hour < 17) {
      salutation = 'Good Afternoon';
      icon = '☀️';
    } else if (hour >= 17 && hour < 22) {
      salutation = 'Good Evening';
      icon = '🌆';
    } else if (hour >= 22 || hour < 5) {
      salutation = 'Hello';
      icon = '🌙';
    }

    final namePart = firstName.isNotEmpty ? ' $firstName' : '';
    if (_selectedLang == 'english') {
      return '$salutation$namePart! $icon\n\nI am your Jiya AI assistant. You can speak 🎙️ or type 💬 to ask anything. What would you like to check today?';
    }

    return '$salutation$namePart! $icon\n\nMain aapki Jiya AI assistant hoon. Aap mujhse bolkar 🎙️ ya likhkar 💬 puch sakte hain. Aapko aaj kya jankari chahiye ya kaunsa kaam karna hai?';
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (e) => debugPrint('Speech error: $e'),
      onStatus: (status) {
        if (status == 'notListening' && mounted) {
          _setListeningState(false);
        }
      },
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<bool> _ensureSpeechReady() async {
    if (_speechAvailable) {
      return true;
    }

    final initialized = await _speech.initialize(
      onError: (e) => debugPrint('Speech error: $e'),
      onStatus: (status) {
        if (status == 'notListening' && mounted) {
          _setListeningState(false);
        }
      },
    );

    if (!mounted) {
      return initialized;
    }

    setState(() {
      _speechAvailable = initialized;
    });

    return initialized;
  }

  Future<void> _initTts() async {
    await _tts.setLanguage(_selectedLang == 'hindi' ? 'hi-IN' : 'en-IN');
    await _tts.setSpeechRate(0.52);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    _tts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _isSpeaking = false);
      }
    });
  }

  Future<void> _startListening() async {
    final ready = await _ensureSpeechReady();
    if (!ready) {
      _addBotMessage(
        _selectedLang == 'hindi'
            ? 'Voice input start nahi hua. Microphone permission ya speech support check kijiye.'
            : 'Voice input could not start. Please check microphone permission or speech support.',
      );
      return;
    }

    final available = await _speech.hasPermission;
    if (!available) {
      _addBotMessage(
        _selectedLang == 'hindi'
            ? 'Microphone permission missing hai. App settings mein allow karke phir try kijiye.'
            : 'Microphone permission is missing. Allow it from app settings and try again.',
      );
      return;
    }

    final started = await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _controller.text = result.recognizedWords;
          _controller.selection = TextSelection.collapsed(
            offset: _controller.text.length,
          );
        });

        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          _sendMessage();
        }
      },
      listenOptions: stt.SpeechListenOptions(
        localeId: _selectedLang == 'hindi' ? 'hi_IN' : 'en_IN',
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        listenMode: stt.ListenMode.confirmation,
      ),
    );

    if (!started) {
      _addBotMessage(
        _selectedLang == 'hindi'
            ? 'Voice input start nahi hua. Device speech service ko check kijiye.'
            : 'Voice input did not start. Please check the device speech service.',
      );
      return;
    }

    if (mounted) {
      _setListeningState(true);
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    _setListeningState(false);
  }

  void _setListeningState(bool value) {
    if (!mounted) return;

    if (value) {
      _voicePulseController.repeat(reverse: true);
    } else {
      _voicePulseController.stop();
      _voicePulseController.value = 0;
    }

    setState(() => _isListening = value);
  }

  Future<void> _speakText(String text, String lang) async {
    if (_isSpeaking) {
      await _tts.stop();
      if (mounted) {
        setState(() => _isSpeaking = false);
      }
      return;
    }

    final cleanText = text
        .replaceAll('**', '')
        .replaceAll('*', '')
        .replaceAll('#', '')
        .replaceAll('•', ',')
        .replaceAll('\n', '. ');

    await _tts.setLanguage(lang == 'hindi' ? 'hi-IN' : 'en-IN');
    await _tts.setSpeechRate(lang == 'hindi' ? 0.5 : 0.45);
    if (mounted) {
      setState(() => _isSpeaking = true);
    }
    await _tts.speak(cleanText.substring(0, cleanText.length.clamp(0, 500)));
  }

  String _sanitizeAssistantMessage(String text) {
    return text
        .replaceAll('**', '')
        .replaceAll('__', '')
        .replaceAllMapped(RegExp(r'^\s*#+\s*', multiLine: true), (_) => '')
        .replaceAll('`', '');
  }

  void _addBotMessage(
    String text, {
    String? lang,
    Map<String, dynamic>? action,
    Map<String, dynamic>? rawData,
  }) {
    final cleanText = _sanitizeAssistantMessage(text);
    setState(() {
      _messages.add(
        _ChatMessage(
          text: cleanText,
          isUser: false,
          lang: lang ?? _selectedLang,
          action: action,
          rawData: rawData,
        ),
      );
    });
    _scrollToBottom();
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
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    if (_isListening) {
      await _stopListening();
    }

    setState(() {
      _messages.add(_ChatMessage(text: query, isUser: true, lang: _selectedLang));
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.postRequest(
        '/chat',
        data: {
          'query': query,
          'language': _selectedLang,
          'inputMode': _selectedLang == 'hindi' ? 'hinglish' : 'english',
          'responseStyle': _selectedLang == 'hindi'
              ? 'Understand Hinglish typed in English letters and reply in natural Hindi using English letters unless the user asks otherwise.'
              : 'Reply in clear, proper English.',
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'];
        final message = data['message'] ?? 'Koi response nahi mila.';
        final lang = data['language'] ?? _selectedLang;
        final action = data['action'] as Map<String, dynamic>?;
        final rawData = data['rawData'] as Map<String, dynamic>?;
        _addBotMessage(message, lang: lang, action: action, rawData: rawData);
      } else {
        _addBotMessage(
          _selectedLang == 'hindi'
              ? 'Server se response nahi mila. Dobara try kijiye.'
              : 'No response came back from the server. Please try again.',
        );
      }
    } catch (e) {
      final errMsg = ApiService.getReadableError(e);
      _addBotMessage(
        _selectedLang == 'hindi' ? 'Error: $errMsg' : 'Error: $errMsg',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _speech.stop();
    _tts.stop();
    _voicePulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Jiya AI Assistant',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF22C55E),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'Online • Aapki Personal Assistant',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          _buildLanguageToggle(),
        ],
      ),
      body: Column(
        children: [
          _buildQuickChips(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return _buildTypingIndicator();
                }
                return _buildMessageBubble(_messages[index], index);
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildLanguageToggle() {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _langPill('EN', 'english'),
          _langPill('HI', 'hindi'),
        ],
      ),
    );
  }

  Widget _langPill(String label, String lang) {
    final isActive = _selectedLang == lang;
    return GestureDetector(
      onTap: () {
        if (_selectedLang == lang) return;
        setState(() {
          _selectedLang = lang;
          if (_messages.isNotEmpty && !_messages.first.isUser) {
            _messages[0] = _ChatMessage(
              text: _buildWelcomeMessage(_userDisplayName),
              isUser: false,
              lang: _selectedLang,
              action: _messages.first.action,
            );
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isActive ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white60,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChips() {
    final chips = _selectedLang == 'english'
        ? [
            ('📊 Overview', 'show today\'s CRM overview & statistics', Colors.indigo),
            ('📅 Follow-ups', 'show today\'s follow-ups', Colors.orange),
            ('💰 Pending Fees', 'show students with pending fees', Colors.teal),
            ('⭐ Interested Leads', 'show interested leads', Colors.amber),
            ('🆕 Enquiries', 'show new enquiries', Colors.blue),
            ('✍️ Draft Message', 'draft a fee reminder message', Colors.pink),
            ('💳 Payments', 'show payment & collection report', Colors.green),
          ]
        : [
            ('📊 Overview', 'aaj ka summary aur overview dikhao', Colors.indigo),
            ('📅 Follow-ups', 'aaj ke follow ups batao', Colors.orange),
            ('💰 Pending Fees', 'pending fee wale students dikhao', Colors.teal),
            ('⭐ Interested Leads', 'interested leads dikhao', Colors.amber),
            ('🆕 Enquiries', 'new enquiries dikhao', Colors.blue),
            ('✍️ Draft Message', 'fee reminder message draft karo', Colors.pink),
            ('💳 Payments', 'aaj ka payment aur collection report dikhao', Colors.green),
          ];

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final color = chips[i].$3;
          return GestureDetector(
            onTap: () {
              _controller.text = chips[i].$2;
              _sendMessage();
            },
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.28)),
                ),
                child: Text(
                  chips[i].$1,
                  style: TextStyle(
                    color: color.shade800,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg, int index) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bubbleMaxWidth = screenWidth < 420 ? screenWidth * 0.82 : screenWidth * 0.85;

    // If it's the initial welcome message, show the rich starter hero
    if (index == 0 && !msg.isUser) {
      return _buildWelcomeHeroCard(msg);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!msg.isUser) ...[
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
              child: Column(
                crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth < 420 ? 13 : 15,
                      vertical: screenWidth < 420 ? 10 : 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: msg.isUser
                          ? const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: msg.isUser ? null : const Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(msg.isUser ? 18 : 4),
                        bottomRight: Radius.circular(msg.isUser ? 4 : 18),
                      ),
                      border: msg.isUser ? null : Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SelectableText(
                          msg.text,
                          style: TextStyle(
                            color: msg.isUser ? Colors.white : const Color(0xFF1E293B),
                            fontSize: 13.5,
                            height: 1.55,
                          ),
                        ),
                        if (msg.action != null && msg.action!['mobile'] != null) ...[
                          const SizedBox(height: 10),
                          _buildActionLauncherButton(msg.action!),
                        ],
                        if (!msg.isUser && msg.rawData != null)
                          _buildLeadCardsFromRawData(msg.rawData!),
                      ],
                    ),
                  ),
                  if (!msg.isUser)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => _speakText(msg.text, msg.lang),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isSpeaking ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
                                    color: const Color(0xFF6366F1),
                                    size: 13,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isSpeaking ? 'Stop' : 'Listen',
                                    style: const TextStyle(
                                      color: Color(0xFF6366F1),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: msg.text));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Message copied to clipboard!'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF64748B).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.copy_rounded, color: Color(0xFF64748B), size: 12),
                                  SizedBox(width: 4),
                                  Text(
                                    'Copy',
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
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
          if (msg.isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeroCard(_ChatMessage msg) {
    final isHindi = _selectedLang == 'hindi';

    final starters = isHindi
        ? [
            ('📊 Overview & Stats', 'aaj ka summary aur overview dikhao', const Color(0xFF6366F1)),
            ('📋 Staff Attendance', 'aaj ki staff attendance report dikhao', const Color(0xFF0891B2)),
            ('💳 Payment Report', 'aaj ka payment aur collection report dikhao', const Color(0xFF059669)),
            ('📅 Today\'s Follow-ups', 'aaj ke follow ups batao', const Color(0xFFF59E0B)),
            ('💰 Pending Fees', 'pending fee wale students dikhao', const Color(0xFF0D9488)),
            ('✍️ Draft Reminder', 'fee reminder message draft karo', const Color(0xFFE11D48)),
          ]
        : [
            ('📊 CRM Overview', 'show today\'s CRM overview & statistics', const Color(0xFF6366F1)),
            ('📋 Staff Attendance', 'show today\'s staff attendance report', const Color(0xFF0891B2)),
            ('💳 Payment Report', 'show payment & collection report', const Color(0xFF059669)),
            ('📅 Today\'s Follow-ups', 'show today\'s follow-ups', const Color(0xFFF59E0B)),
            ('💰 Pending Fees', 'show students with pending fees', const Color(0xFF0D9488)),
            ('✍️ Draft Reminder', 'draft a fee reminder message', const Color(0xFFE11D48)),
          ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userDisplayName.isNotEmpty
                          ? 'Namaste, $_userDisplayName!'
                          : 'Welcome to SSSAM AI!',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const Text(
                      'Ask any CRM question or tap a starter below',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            msg.text,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          const Text(
            '⚡ Quick Starters',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 2.5,
            ),
            itemCount: starters.length,
            itemBuilder: (context, i) {
              final item = starters[i];
              return GestureDetector(
                onTap: () {
                  _controller.text = item.$2;
                  _sendMessage();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: item.$3.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: item.$3.withValues(alpha: 0.25)),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.$1,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: item.$3,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionLauncherButton(Map<String, dynamic> action) {
    final type = action['type']?.toString().toLowerCase();
    final mobile = action['mobile']?.toString() ?? '';
    final name = action['name'] ?? '';

    final isCall = type == 'call';
    final color = isCall ? Colors.blue : Colors.green;
    final icon = isCall ? Icons.phone : Icons.chat;
    final label = isCall ? 'Call $name' : 'WhatsApp $name';

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          final launched = await _launchAssistantAction(
            type: isCall ? 'call' : 'whatsapp',
            mobile: mobile,
            actionText: action['text']?.toString(),
          );

          if (!launched && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _selectedLang == 'hindi'
                      ? 'Action open nahi hua. Number ya app permission check kijiye.'
                      : 'Could not open the action. Please check the number or app permission.',
                ),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeadCardsFromRawData(Map<String, dynamic> rawData) {
    List<Map<String, dynamic>> items = [];

    // Extract enquiries
    if (rawData['enquiries'] is List) {
      for (var e in rawData['enquiries']) {
        if (e is Map<String, dynamic> && e['mobile'] != null) {
          items.add({
            'name': e['name'] ?? 'Enquiry',
            'mobile': e['mobile'],
            'course': e['course'] ?? '',
            'status': e['status'] ?? 'NEW',
            'extra': e['followUpDate'] != null ? 'Follow-up: ${e['followUpDate']}' : '',
            'type': 'ENQUIRY'
          });
        }
      }
    }

    // Extract admissions
    if (rawData['admissions'] is List) {
      for (var a in rawData['admissions']) {
        if (a is Map<String, dynamic> && a['mobile'] != null) {
          items.add({
            'name': a['name'] ?? 'Student',
            'mobile': a['mobile'],
            'course': a['course'] ?? '',
            'status': a['status'] ?? 'ACTIVE',
            'extra': a['pendingAmount'] != null ? 'Pending Fee: ₹${a['pendingAmount']}' : '',
            'type': 'ADMISSION'
          });
        }
      }
    }

    // Extract followups
    if (rawData['followups'] is List) {
      for (var f in rawData['followups']) {
        if (f is Map<String, dynamic> && f['mobile'] != null) {
          items.add({
            'name': f['name'] ?? 'Lead',
            'mobile': f['mobile'],
            'course': f['course'] ?? '',
            'status': f['status'] ?? 'PENDING',
            'extra': 'Time: ${f['followUpTime'] ?? 'N/A'}',
            'type': 'FOLLOWUP'
          });
        }
      }
    }

    // Extract pending fee students
    if (rawData['students'] is List) {
      for (var s in rawData['students']) {
        if (s is Map<String, dynamic> && s['mobile'] != null) {
          items.add({
            'name': s['name'] ?? 'Student',
            'mobile': s['mobile'],
            'course': s['course'] ?? '',
            'status': 'PENDING FEE',
            'extra': 'Pending Dues: ₹${s['pendingAmount']}',
            'type': 'FEE'
          });
        }
      }
    }

    // Extract mobile_search single item
    if (rawData['type'] == 'mobile_search') {
      final e = rawData['enquiry'];
      final a = rawData['admission'];
      if (a != null && a['mobile'] != null) {
        items.add({
          'name': a['name'] ?? 'Student',
          'mobile': a['mobile'],
          'course': a['course'] ?? '',
          'status': a['status'] ?? 'ACTIVE',
          'extra': 'Pending Fee: ₹${a['pendingAmount'] ?? 0}',
          'type': 'ADMISSION'
        });
      }
      if (e != null && e['mobile'] != null) {
        items.add({
          'name': e['name'] ?? 'Enquiry',
          'mobile': e['mobile'],
          'course': e['course'] ?? '',
          'status': e['status'] ?? 'NEW',
          'extra': e['followUpDate'] != null ? 'Follow-up: ${e['followUpDate']}' : '',
          'type': 'ENQUIRY'
        });
      }
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        ...items.map((item) {
          final name = item['name'];
          final mobile = item['mobile'].toString();
          final course = item['course'];
          final status = item['status'] ?? '';
          final extra = item['extra'] ?? '';
          final cleanExtra = (extra as String).replaceAll(RegExp(r'Time:\s*[^•|]+', caseSensitive: false), '').replaceAll(RegExp(r'Follow-up:\s*[^•|]+', caseSensitive: false), '').trim();

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Name + Course + Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '👤 $name',
                              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            if (course.isNotEmpty) ...[
                              const TextSpan(text: ' • ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                              TextSpan(
                                text: course,
                                style: const TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status.toString().toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF0369A1),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                // Row 2: Mobile + Context Extra Info (NO TIME)
                Row(
                  children: [
                    Text(
                      '📱 $mobile',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                    if (cleanExtra.isNotEmpty) ...[
                      const Text(' • ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      Expanded(
                        child: Text(
                          cleanExtra,
                          style: const TextStyle(color: Color(0xFFEA580C), fontSize: 11, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                // Row 3: Micro Action Strip
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _launchAssistantAction(type: 'call', mobile: mobile),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.phone, size: 11, color: Colors.white),
                              SizedBox(width: 3),
                              Text('Call', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: InkWell(
                        onTap: () => _launchAssistantAction(type: 'whatsapp', mobile: mobile),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat, size: 11, color: Colors.white),
                              SizedBox(width: 3),
                              Text('WhatsApp', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Future<bool> _launchAssistantAction({
    required String type,
    required String mobile,
    String? actionText,
  }) async {
    final cleanMobile = mobile.replaceAll(RegExp(r'\D'), '');

    if (cleanMobile.isEmpty) {
      return false;
    }

    if (type == 'call') {
      final uri = Uri.parse('tel:$cleanMobile');
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    var waMobile = cleanMobile;
    if (waMobile.length == 10) {
      waMobile = '91$waMobile';
    }

    var waUrl = 'https://wa.me/$waMobile';
    final messageText = actionText?.trim();
    if (messageText != null && messageText.isNotEmpty) {
      waUrl += '?text=${Uri.encodeComponent(messageText)}';
    }

    final uri = Uri.parse(waUrl);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 600 + i * 200),
                  builder: (context, value, child) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Transform.translate(
                        offset: Offset(0, -4 * (value < 0.5 ? value * 2 : (1 - value) * 2)),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: const Color(0xFF667eea).withValues(alpha: 0.7),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: bottomInset > 0 ? 10 : safeBottomPadding + 10,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _isListening
                ? Container(
                    key: const ValueKey('listening-indicator'),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFF1F2), Color(0xFFFFE4E6)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFDA4AF), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF43F5E).withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF43F5E).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.mic_rounded,
                            color: Color(0xFFE11D48),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedLang == 'hindi'
                                    ? 'Sun raha hoon... bolte rahiye'
                                    : 'Listening... speak now',
                                style: const TextStyle(
                                  color: Color(0xFF9F1239),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                _selectedLang == 'hindi'
                                    ? 'Rukne ke liye mic icon dabaye'
                                    : 'Tap mic button to stop',
                                style: const TextStyle(
                                  color: Color(0xFFBE123C),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(4, (index) {
                            return AnimatedBuilder(
                              animation: _voicePulseController,
                              builder: (context, child) {
                                final phase = index * 0.25;
                                final val = ((_voicePulseController.value + phase) % 1.0);
                                final height = 6.0 + (val < 0.5 ? val * 2 : (1 - val) * 2) * 12.0;
                                return Container(
                                  width: 3.5,
                                  height: height,
                                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE11D48),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                );
                              },
                            );
                          }),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: _isListening ? _stopListening : _startListening,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _voicePulseController,
                      builder: (context, child) {
                        final pulse = _voicePulseController.value;
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_isListening) ...[
                              Container(
                                width: 40 + (pulse * 14),
                                height: 40 + (pulse * 14),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFF43F5E).withValues(alpha: (1 - pulse) * 0.35),
                                ),
                              ),
                              Container(
                                width: 40 + (pulse * 6),
                                height: 40 + (pulse * 6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFFB7185).withValues(alpha: (1 - pulse) * 0.45),
                                ),
                              ),
                            ],
                            child!,
                          ],
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: _isListening
                              ? const LinearGradient(
                                  colors: [Color(0xFFF43F5E), Color(0xFFD946EF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: _isListening ? null : const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isListening ? Colors.transparent : const Color(0xFFE2E8F0),
                            width: 1.2,
                          ),
                          boxShadow: _isListening
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFF43F5E).withValues(alpha: 0.45),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : [],
                        ),
                        child: Icon(
                          _isListening ? Icons.mic : Icons.mic_none_rounded,
                          color: _isListening ? Colors.white : const Color(0xFF64748B),
                          size: 21,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: Color(0xFF1E293B), fontSize: 14),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: _isListening
                        ? (_selectedLang == 'hindi' ? '🎙️ Sun raha hoon...' : '🎙️ Listening to voice...')
                        : (_selectedLang == 'hindi'
                            ? 'Hinglish mein puchho... jaise: aaj ke follow up dikhao'
                            : 'Ask in English... e.g. show today\'s follow-ups'),
                    hintStyle: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: Color(0xFF667eea), width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _isLoading ? null : _sendMessage,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF667eea).withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final String lang;
  final Map<String, dynamic>? action;
  final Map<String, dynamic>? rawData;

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.lang,
    this.action,
    this.rawData,
  });
}
