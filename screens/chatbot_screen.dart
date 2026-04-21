import 'dart:math';
import 'package:air_quality_app/config/app_themes.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../config/app_config.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isBotTyping = false;

  late AnimationController _typingDotController;
  late AnimationController _botIconPulseController;
  late Animation<double> _botIconPulse;

  @override
  void initState() {
    super.initState();

    _typingDotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _botIconPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _botIconPulse = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _botIconPulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      if (appState.chatHistory.isEmpty) {
        _sendWithTyping('Ahoj', appState);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingDotController.dispose();
    _botIconPulseController.dispose();
    super.dispose();
  }

  Future<void> _sendWithTyping(String message, AppState appState) async {
    setState(() => _isBotTyping = true);
    await appState.sendChatMessage(message);
    if (mounted) setState(() => _isBotTyping = false);
    _scrollToBottom();
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;
    _messageController.clear();
    final appState = context.read<AppState>();
    _sendWithTyping(message, appState);
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardTheme.color ??
        Theme.of(context).scaffoldBackgroundColor;
    final textColor = AppThemes.getTextColor(context);
    final accentColor =
        Color(AppConfig.instance.qualityColors['good']!); // teal-ish green

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ScaleTransition(
              scale: _botIconPulse,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.15),
                  border: Border.all(color: accentColor, width: 1.5),
                ),
                child:
                    Icon(Icons.smart_toy_rounded, size: 20, color: accentColor),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aethris AI',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isBotTyping
                      ? Text(
                          'píše...',
                          key: const ValueKey('typing'),
                          style: TextStyle(fontSize: 11, color: accentColor),
                        )
                      : Text(
                          'online',
                          key: const ValueKey('online'),
                          style:
                              TextStyle(fontSize: 11, color: Colors.green[400]),
                        ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline, color: textColor),
            onPressed: _showClearChatDialog,
            tooltip: 'Vymazat historii',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<AppState>(
              builder: (context, appState, child) {
                final chatHistory = appState.chatHistory;

                if (chatHistory.isEmpty && !_isBotTyping) {
                  return _buildEmptyState(accentColor, textColor);
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.all(AppConfig.instance.screenPadding),
                  itemCount: chatHistory.length + (_isBotTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_isBotTyping && index == chatHistory.length) {
                      return _buildTypingIndicator(cardColor, accentColor);
                    }
                    final message = chatHistory[index];
                    return _buildMessageBubble(
                        message, cardColor, textColor, accentColor);
                  },
                );
              },
            ),
          ),
          _buildInputArea(cardColor, textColor, accentColor),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color accentColor, Color textColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _botIconPulse,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.1),
                  border: Border.all(color: accentColor, width: 2),
                ),
                child:
                    Icon(Icons.smart_toy_rounded, size: 40, color: accentColor),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Začněte konverzaci',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Zeptejte se na kvalitu vzduchu, vliv na spánek nebo cokoli, co vás zajímá.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: textColor.withValues(alpha: 0.5), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(Color cardColor, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildBotAvatar(accentColor),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(
                  color: accentColor.withValues(alpha: 0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) => _buildDot(i, accentColor)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index, Color color) {
    return AnimatedBuilder(
      animation: _typingDotController,
      builder: (_, __) {
        // Stagger each dot by 0.2 of the cycle
        final offset = (index * 0.25);
        final t = (_typingDotController.value + offset) % 1.0;
        // Sine wave: up for first half, down for second
        final scale = 1.0 + 0.4 * sin(t * pi);
        final opacity = 0.4 + 0.6 * sin(t * pi).clamp(0.0, 1.0);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: opacity),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message, Color cardColor,
      Color textColor, Color accentColor) {
    final isUser = message.isUser;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(isUser ? 20 * (1 - value) : -20 * (1 - value), 0),
          child: child,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment:
                  isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isUser) ...[
                  _buildBotAvatar(accentColor),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isUser
                          ? accentColor.withValues(alpha: 0.15)
                          : cardColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isUser ? 20 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 20),
                      ),
                      border: Border.all(
                        color: isUser
                            ? accentColor.withValues(alpha: 0.5)
                            : accentColor.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.07),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      message.text,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
                if (isUser) ...[
                  const SizedBox(width: 8),
                  _buildUserAvatar(),
                ],
              ],
            ),
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(left: 44, top: 4),
                child: Text(
                  message.formattedTime,
                  style: TextStyle(
                      fontSize: 11, color: textColor.withValues(alpha: 0.4)),
                ),
              ),
            if (message.suggestions != null && message.suggestions!.isNotEmpty)
              _buildSuggestions(message.suggestions!, accentColor, textColor),
          ],
        ),
      ),
    );
  }

  Widget _buildBotAvatar(Color accentColor) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accentColor.withValues(alpha: 0.12),
        border: Border.all(color: accentColor, width: 1.5),
      ),
      child: Icon(Icons.smart_toy_rounded, size: 17, color: accentColor),
    );
  }

  Widget _buildUserAvatar() {
    final accentBlue = Colors.blue[400]!;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accentBlue.withValues(alpha: 0.12),
        border: Border.all(color: accentBlue, width: 1.5),
      ),
      child: Icon(Icons.person_rounded, size: 17, color: accentBlue),
    );
  }

  Widget _buildSuggestions(
      List<String> suggestions, Color accentColor, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 44, top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: suggestions.map((s) {
          return GestureDetector(
            onTap: () {
              _messageController.text = s;
              _sendMessage();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: accentColor.withValues(alpha: 0.4), width: 1.2),
              ),
              child: Text(
                s,
                style: TextStyle(
                  fontSize: 13,
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInputArea(Color cardColor, Color textColor, Color accentColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(
          top: BorderSide(
            color: accentColor.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  style: TextStyle(color: textColor, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Napište zprávu...',
                    hintStyle: TextStyle(
                        color: textColor.withValues(alpha: 0.4), fontSize: 15),
                    filled: true,
                    fillColor: Theme.of(context)
                        .scaffoldBackgroundColor
                        .withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                          color: accentColor.withValues(alpha: 0.3),
                          width: 1.2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                          color: accentColor.withValues(alpha: 0.3),
                          width: 1.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: accentColor, width: 1.8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                  textInputAction: TextInputAction.send,
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClearChatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vymazat historii'),
        content:
            const Text('Opravdu chcete vymazat celou historii konverzace?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zrušit'),
          ),
          TextButton(
            onPressed: () {
              context.read<AppState>().clearChatHistory();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Historie vymazána')),
              );
            },
            child: const Text('Vymazat'),
          ),
        ],
      ),
    );
  }
}
