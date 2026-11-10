import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../services/db_helper.dart';
import '../services/chat_parser.dart';
import '../services/notification_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  Timer? _tickerTimer;
  int _offsetDelta = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadState();
    _startClockTicker();
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    _offsetDelta = prefs.getInt('offset_delta') ?? 0;
    final list = await DBHelper.instance.getDeliveredMessages();
    if (mounted) {
      setState(() {
        _messages.addAll(list);
      });
      _scrollToBottom();
    }
  }

  void _startClockTicker() {
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_offsetDelta == 0) return;

      final virtualTargetTime = DateTime.now().millisecondsSinceEpoch - _offsetDelta;
      final pending = await DBHelper.instance.getPendingMessagesUpTo(virtualTargetTime);

      if (pending.isNotEmpty) {
        for (var msg in pending) {
          await DBHelper.instance.markAsDelivered(msg.id!);
          if (mounted) {
            setState(() {
              _messages.add(msg);
            });
          }
          if (!msg.isMe) {
            NotificationService().showDiscreetNotification();
          }
        }
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickAndIngestFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() => _isLoading = true);
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        
        final parsedList = ChatParser.parse(content, "Majd");

        if (parsedList.isNotEmpty) {
          await DBHelper.instance.clearAll();
          await DBHelper.instance.insertMessages(parsedList);

          final firstMsgTime = parsedList.first.originalTimestamp.millisecondsSinceEpoch;
          final currentTime = DateTime.now().millisecondsSinceEpoch;
          final calculatedOffset = currentTime - firstMsgTime;

          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('offset_delta', calculatedOffset);

          setState(() {
            _offsetDelta = calculatedOffset;
            _messages.clear();
            _isLoading = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('تم استيراد \${parsedList.length} رسالة وجدولة البث اللحظي')),
            );
          }
        } else {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تعذر قراءة الرسائل، يرجى التأكد من صيغة الملف')),
            );
          }
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () {},
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey[850],
                  child: const Icon(Icons.person, color: Colors.white, size: 22),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Maryam', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                Text('Active now', style: TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined, color: Colors.white),
            tooltip: 'استيراد ملف المحادثة (.txt)',
            onPressed: _pickAndIngestFile,
          ),
          IconButton(icon: const Icon(Icons.call_outlined, color: Colors.white), onPressed: () {}),
          IconButton(icon: const Icon(Icons.videocam_outlined, color: Colors.white), onPressed: () {}),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? const Center(
                          child: Text(
                            'اضغط على أيقونة الرفع بالأعلى لاختيار ملف المحادثة',
                            style: TextStyle(color: Colors.white38, fontSize: 14),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            return _buildInstagramBubble(msg);
                          },
                        ),
                ),
                _buildFakeInputBar(),
              ],
            ),
    );
  }

  Widget _buildInstagramBubble(ChatMessage msg) {
    final alignment = msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleDecoration = msg.isMe
        ? BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF833AB4), Color(0xFF405DE6)],
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
            ),
            borderRadius: BorderRadius.circular(20).copyWith(
              bottomRight: const Radius.circular(4),
            ),
          )
        : BoxDecoration(
            color: const Color(0xFF262626),
            borderRadius: BorderRadius.circular(20).copyWith(
              bottomLeft: const Radius.circular(4),
            ),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: bubbleDecoration,
            child: Text(
              msg.message,
              style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.25),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
            child: Text(
              DateFormat('h:mm a').format(msg.originalTimestamp),
              style: const TextStyle(color: Colors.white30, fontSize: 9.5),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFakeInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: Colors.black,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF262626),
            borderRadius: BorderRadius.circular(25),
          ),
          height: 46,
          child: Row(
            children: [
              Container(
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.blueAccent),
                padding: const EdgeInsets.all(5),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Message...', style: TextStyle(color: Colors.white38, fontSize: 14)),
              ),
              const Icon(Icons.mic_none, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              const Icon(Icons.image_outlined, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              const Icon(Icons.favorite_border, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
