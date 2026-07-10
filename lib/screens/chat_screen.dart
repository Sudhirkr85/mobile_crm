import 'package:flutter/material.dart';
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
    final greetingName = firstName.isNotEmpty ? ' $firstName' : '';
    if (_selectedLang == 'english') {
      return 'Hello$greetingName! Welcome to the SSSAM AI Assistant.\n\nIn English mode, I will reply in proper English. If you switch to Hindi mode, you can type or speak in Hinglish and I will respond in natural Hindi written in English letters.\n\nYou can use the Guide / Help chip to see example prompts.';
    }

    return 'Namaste$greetingName! SSSAM AI Assistant mein aapka swagat hai.\n\nHindi mode mein aap Hinglish mein type ya bol sakte hain aur main Hindi style mein reply dunga. English mode mein main proper English use karunga.\n\nGuide / Help chip se examples dekh sakte hain.';
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
    await _tts.setLanguage('hi-IN');
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
  }) {
    final cleanText = _sanitizeAssistantMessage(text);
    setState(() {
      _messages.add(
        _ChatMessage(
          text: cleanText,
          isUser: false,
          lang: lang ?? _selectedLang,
          action: action,
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
        _addBotMessage(message, lang: lang, action: action);
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
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Assistant',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4ade80),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Online • Groq AI',
                      style: TextStyle(color: Colors.blueGrey, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                _langChip('HI', 'hindi'),
                const SizedBox(width: 4),
                _langChip('EN', 'english'),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildQuickChips(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return _buildTypingIndicator();
                }
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _langChip(String label, String lang) {
    final isActive = _selectedLang == lang;
    return GestureDetector(
      onTap: () {
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
              ? const LinearGradient(colors: [Color(0xFF667eea), Color(0xFF764ba2)])
              : null,
          color: isActive ? null : Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? Colors.transparent : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChips() {
    final chips = [
      ('Guide / Help', 'help'),
      ('Aaj Follow-ups', 'aaj ke follow up'),
      ('Pending Fees', 'pending fees'),
      ('Saved Notes', 'saved notes dikhao'),
    ];

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          return GestureDetector(
            onTap: () {
              _controller.text = chips[i].$2;
              _sendMessage();
            },
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF667eea).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF667eea).withValues(alpha: 0.4)),
                ),
                child: Text(
                  chips[i].$1,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bubbleMaxWidth = screenWidth < 420 ? screenWidth * 0.72 : screenWidth * 0.78;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!msg.isUser) ...[
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
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
              child: Column(
              crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth < 420 ? 12 : 14,
                    vertical: screenWidth < 420 ? 9 : 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: msg.isUser
                        ? const LinearGradient(
                            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: msg.isUser ? null : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
                      bottomRight: Radius.circular(msg.isUser ? 4 : 16),
                    ),
                    border: msg.isUser ? null : Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SelectableText(
                        msg.text,
                        style: TextStyle(
                          color: msg.isUser ? Colors.white : Colors.white.withValues(alpha: 0.88),
                          fontSize: 13.5,
                          height: 1.55,
                        ),
                      ),
                      if (msg.action != null && msg.action!['mobile'] != null) ...[
                        const SizedBox(height: 8),
                        _buildActionLauncherButton(msg.action!),
                      ],
                    ],
                  ),
                ),
                if (!msg.isUser)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: GestureDetector(
                      onTap: () => _speakText(msg.text, msg.lang),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isSpeaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
                            color: const Color(0xFF667eea),
                            size: 14,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _isSpeaking ? 'Stop' : 'Speak',
                            style: const TextStyle(color: Color(0xFF667eea), fontSize: 11),
                          ),
                        ],
                      ),
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
              color: const Color(0xFF1E293B),
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
                            color: const Color(0xFF667eea).withOpacity(0.7),
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
        color: Color(0xFF1E293B),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _isListening
                ? Container(
                    key: const ValueKey('listening-indicator'),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFf5576c).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFf5576c).withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        FadeTransition(
                          opacity: Tween<double>(begin: 0.45, end: 1).animate(_voicePulseController),
                          child: const Icon(Icons.graphic_eq_rounded, color: Color(0xFFff8fab), size: 18),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Sun raha hoon... bolte rahiye',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(3, (index) {
                            return AnimatedBuilder(
                              animation: _voicePulseController,
                              builder: (context, child) {
                                final scale =
                                    0.55 + (((_voicePulseController.value + (index * 0.18)) % 1.0) * 0.85);
                                return Transform.scale(scale: scale, child: child);
                              },
                              child: Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFff8fab),
                                  shape: BoxShape.circle,
                                ),
                              ),
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
                child: ScaleTransition(
                  scale: Tween<double>(begin: 1, end: 1.08).animate(
                    CurvedAnimation(parent: _voicePulseController, curve: Curves.easeInOut),
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: _isListening
                          ? const LinearGradient(colors: [Color(0xFFf5576c), Color(0xFFf093fb)])
                          : null,
                      color: _isListening ? null : Colors.white12,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isListening ? Colors.transparent : Colors.white24,
                      ),
                      boxShadow: _isListening
                          ? [
                              BoxShadow(
                                color: const Color(0xFFf5576c).withValues(alpha: 0.4),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ]
                          : [],
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: _isListening
                        ? 'Sun raha hoon...'
                        : (_selectedLang == 'hindi'
                            ? 'Hinglish mein puchho... jaise: aaj ke follow up dikhao'
                            : 'Ask in proper English...'),
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.07),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
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

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.lang,
    this.action,
  });
}
