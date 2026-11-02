import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class AdminChatScreen extends StatefulWidget {
  final int customerId;
  final String customerName;
  const AdminChatScreen({super.key, required this.customerId, required this.customerName});

  @override
  State<AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<AdminChatScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _loadMessages());
  }

  void _loadMessages() async {
    List<dynamic> msgs = await ApiService.getChatMessages(widget.customerId);
    if (mounted) {
      setState(() {
        _messages = msgs.map((m) => {
          'isAdmin': m['NguoiGui'] == 'Admin',
          'text': m['NoiDung'],
          'time': DateFormat('HH:mm').format(DateTime.parse(m['ThoiGian'])),
        }).toList();
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _sendMessage() async {
    if (_msgCtrl.text.trim().isEmpty) return;
    String text = _msgCtrl.text.trim();
    _msgCtrl.clear();
    await ApiService.sendChatMessage(widget.customerId, 'Admin', text);
    _loadMessages();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF00E5FF),
              child: const Icon(Icons.person, color: Colors.black),
            ),
            const SizedBox(width: 10),
            Text(widget.customerName, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                bool isAdmin = msg['isAdmin'];
                return Align(
                  alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
decoration: BoxDecoration(
                      color: isAdmin ? const Color(0xFF00E5FF) : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isAdmin ? const Radius.circular(16) : Radius.zero,
                        bottomRight: isAdmin ? Radius.zero : const Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(msg['text'], style: TextStyle(color: isAdmin ? Colors.black : null, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(msg['time'], style: TextStyle(color: isAdmin ? Colors.black54 : Colors.grey, fontSize: 10)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: Theme.of(context).cardColor,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Nhắn cho khách...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send, color: Color(0xFF00E5FF)), onPressed: _sendMessage),
              ],
            ),
          )
        ],
      ),
    );
  }
}