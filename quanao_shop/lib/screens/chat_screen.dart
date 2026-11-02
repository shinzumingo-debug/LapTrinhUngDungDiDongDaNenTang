import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../utils/formatters.dart'; 

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic>? currentUser;
  final Map<String, dynamic>? currentProduct; 

  const ChatScreen({super.key, required this.currentUser, this.currentProduct});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  
  bool _isTyping = false; 
  List<dynamic> _products = []; 
  String? _lastMentionedProduct; 

  bool _isChattingWithAdmin = false; 
  Timer? _chatTimer; 

  @override
  void initState() {
    super.initState();
    _loadProducts();
    
    String welcomeMsg = 'Xin chào ${widget.currentUser?['HoTen'] ?? 'bạn'}! Mình là trợ lý ảo của SHAMIKIN.';
    if (widget.currentProduct != null) {
      welcomeMsg += '\nMình thấy bạn đang xem sản phẩm "${widget.currentProduct!['TenSanPham']}". Bạn cần tư vấn gì về mẫu này không ạ?';
      _lastMentionedProduct = widget.currentProduct!['TenSanPham'];
    } else {
      welcomeMsg += ' Bạn cần tìm sản phẩm gì, hay muốn hỏi về chính sách giao hàng, đổi trả ạ?\n(Nếu cần gặp người thật, hãy gõ "tôi muốn gặp admin" nhé!)';
    }

    _messages.add({
      'isUser': false,
      'text': welcomeMsg,
      'time': DateFormat('HH:mm').format(DateTime.now()),
      'type': 'ai', 
    });
  }

  void _loadProducts() async {
    _products = await ApiService.getProducts();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _startPolling() {
    _chatTimer?.cancel();
    _chatTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (widget.currentUser == null) return;
      
      List<dynamic> msgs = await ApiService.getChatMessages(widget.currentUser!['Id']);
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m['type'] == 'real');
          
          // Sửa lại dòng này (thêm .cast<Map<String, dynamic>>())
          List<Map<String, dynamic>> realChat = msgs.map((m) => {
            'isUser': m['NguoiGui'] == 'Khach',
            'text': m['NoiDung'],
            'time': DateFormat('HH:mm').format(DateTime.parse(m['ThoiGian'])),
            'type': 'real',
          }).toList().cast<Map<String, dynamic>>();
          
          _messages.addAll(realChat);
        });
        _scrollToBottom();
      }
    });
  }

  void _switchToAdmin() async {
    // 1. Tự động gửi tin nhắn báo hiệu cho Admin
    if (widget.currentUser != null) {
      await ApiService.sendChatMessage(
        widget.currentUser!['Id'], 
        'Khach', 
        'Chào Admin, mình cần được hỗ trợ tư vấn thêm ạ!'
      );
    }

    // 2. Chuyển giao diện sang chat với Admin
    setState(() {
      _isChattingWithAdmin = true;
      _messages.add({
        'isUser': false,
        'text': 'Hệ thống: Bạn đang kết nối với Admin. Vui lòng đợi trong giây lát...',
        'time': DateFormat('HH:mm').format(DateTime.now()),
        'type': 'system',
      });
    });
    _scrollToBottom();
    _startPolling();
  }

  void _handleAdminChat(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add({
        'isUser': true,
        'text': text.trim(),
        'time': DateFormat('HH:mm').format(DateTime.now()),
        'type': 'real',
      });
      _msgCtrl.clear();
    });
    _scrollToBottom();

    await ApiService.sendChatMessage(widget.currentUser!['Id'], 'Khach', text.trim());
  }

  bool _isSimilar(String text, String keyword) {
    if (text.contains(keyword) || keyword.contains(text)) return true;
    if (keyword.length < 3) return false;
    int match = 0;
    for (int i = 0; i < keyword.length; i++) {
      if (i < text.length && text[i] == keyword[i]) match++;
    }
    return match >= (keyword.length * 0.7); 
  }

  void _handleUserMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add({
        'isUser': true,
        'text': text.trim(),
        'time': DateFormat('HH:mm').format(DateTime.now()),
        'type': 'ai',
      });
      _msgCtrl.clear();
      _isTyping = true; 
    });
    _scrollToBottom();

    await Future.delayed(const Duration(milliseconds: 1200));

    String lowerText = text.toLowerCase();

    // KIỂM TRA GẶP ADMIN
    if (lowerText.contains('gặp admin') || lowerText.contains('gặp người') || lowerText.contains('gọi admin')) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add({
            'isUser': false,
            'text': 'Dạ vâng, em chuyển bạn đến Admin để được tư vấn kỹ hơn ngay bây giờ. Vui lòng đợi trong giây lát...',
            'time': DateFormat('HH:mm').format(DateTime.now()),
            'type': 'system',
          });
        });
        _scrollToBottom();
      }
      
      await Future.delayed(const Duration(milliseconds: 1500));
      _switchToAdmin();
      return; 
    }

    // LOGIC AI CŨ
    String botReply = '';

    if (lowerText.contains('cái này') || lowerText.contains('mẫu này') || lowerText.contains('sản phẩm này')) {
      if (_lastMentionedProduct != null) {
        var p = _products.firstWhere((e) => e['TenSanPham'] == _lastMentionedProduct, orElse: () => null);
        if (p != null) {
          botReply = 'Dạ, sản phẩm "$_lastMentionedProduct" đang được bán với giá ${formatPrice(p['Gia'])}. Bạn có muốn đặt mua không ạ?';
          _sendBotReply(botReply);
          return;
        }
      }
    }

    if (_isSimilar(lowerText, 'ship') || _isSimilar(lowerText, 'giao hàng')) {
      botReply = 'Dạ, phí ship đồng giá 30.000 VNĐ toàn quốc. Thời gian giao từ 2-4 ngày làm việc ạ.';
    }
else if (_isSimilar(lowerText, 'đổi trả') || _isSimilar(lowerText, 'hoàn tiền')) {
      botReply = 'Dạ, shop hỗ trợ đổi trả trong vòng 7 ngày nếu hàng lỗi. Bạn vào "Đơn hàng của tôi" để yêu cầu hoàn đơn nhé!';
    }
    else if (_isSimilar(lowerText, 'thanh toán') || _isSimilar(lowerText, 'chuyển khoản')) {
      botReply = 'Shop nhận thanh toán COD (khi nhận hàng) hoặc Chuyển khoản qua mã VietQR ạ.';
    }
    else if (_isSimilar(lowerText, 'chào') || _isSimilar(lowerText, 'hello')) {
      botReply = 'Dạ em chào bạn! Em có thể giúp gì cho bạn ạ?';
    }
    else {
      var matchedProducts = _products.where((p) => 
        _isSimilar((p['TenSanPham'] ?? '').toString().toLowerCase(), lowerText)
      ).toList();

      if (matchedProducts.isNotEmpty) {
        var p = matchedProducts.first; 
        _lastMentionedProduct = p['TenSanPham']; 
        botReply = 'Dạ, em tìm thấy sản phẩm phù hợp:\n- Tên: ${p['TenSanPham']}\n- Giá: ${formatPrice(p['Gia'])}\nBạn có muốn hỏi thêm gì về sản phẩm này không ạ?';
      } else {
        botReply = 'Dạ xin lỗi, em chưa tìm thấy sản phẩm nào khớp với từ khóa "$text".\nNếu bạn cần tư vấn kỹ hơn, hãy gõ "tôi muốn gặp admin" để được hỗ trợ trực tiếp nhé!';
      }
    }

    _sendBotReply(botReply);
  }

  void _sendBotReply(String reply) {
    if (mounted) {
      setState(() {
        _messages.add({
          'isUser': false,
          'text': reply,
          'time': DateFormat('HH:mm').format(DateTime.now()),
          'type': 'ai',
        });
        _isTyping = false; 
      });
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _chatTimer?.cancel();
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
              backgroundColor: _isChattingWithAdmin ? Colors.orangeAccent : const Color(0xFF00E5FF),
              child: Icon(_isChattingWithAdmin ? Icons.support_agent : Icons.smart_toy, color: Colors.black),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_isChattingWithAdmin ? 'Admin SHAMIKIN' : 'Trợ Lý Ảo SHAMIKIN', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(_isChattingWithAdmin ? 'Đang kết nối...' : 'Đang hoạt động', style: TextStyle(fontSize: 11, color: _isChattingWithAdmin ? Colors.orangeAccent : Colors.green)),
              ],
            )
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
                bool isUser = msg['isUser'];
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF00E5FF) : (msg['type'] == 'system' ? Colors.grey[800] : Theme.of(context).cardColor),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
                        bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                      ),
                      border: isUser ? null : Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          msg['text'],
                          style: TextStyle(
                            color: isUser ? Colors.black : (msg['type'] == 'system' ? Colors.white70 : null),
                            fontSize: 14,
                            fontStyle: msg['type'] == 'system' ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(msg['time'], style: TextStyle(color: isUser ? Colors.black54 : Colors.grey, fontSize: 10)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 10),
                      Text('AI đang suy nghĩ...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ),

          Container(
            padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: const Border(top: BorderSide(color: Colors.grey, width: 0.2)),
            ),
            child: Row(
              children: [
                if (!_isChattingWithAdmin)
                  IconButton(
                    icon: const Icon(Icons.support_agent, color: Colors.orangeAccent),
                    tooltip: 'Gặp trực tiếp Admin',
                    onPressed: _switchToAdmin,
                  ),
                const SizedBox(width: 4),

                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (val) {
                      if (_isChattingWithAdmin) {
                        _handleAdminChat(val);
                      } else {
                        _handleUserMessage(val);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: _isChattingWithAdmin ? 'Nhắn cho Admin...' : 'Nhập tin nhắn...',
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: _isChattingWithAdmin ? Colors.orangeAccent : const Color(0xFF00E5FF),
                  child: IconButton(
                    icon: Icon(Icons.send, color: _isChattingWithAdmin ? Colors.white : Colors.black, size: 20),
                    onPressed: () {
                      if (_isChattingWithAdmin) {
                        _handleAdminChat(_msgCtrl.text);
                      } else {
                        _handleUserMessage(_msgCtrl.text);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}