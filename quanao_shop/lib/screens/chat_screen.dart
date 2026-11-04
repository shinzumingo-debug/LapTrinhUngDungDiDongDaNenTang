import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../utils/formatters.dart'; 
import 'product_detail_screen.dart'; // <-- Thêm import này để chuyển trang

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
  List<dynamic> _categories = []; 
  String? _lastMentionedProduct; 

  bool _isChattingWithAdmin = false; 
  Timer? _chatTimer; 

  @override
  void initState() {
    super.initState();
    _loadData(); 
    
    String welcomeMsg = 'Xin chào ${widget.currentUser?['HoTen'] ?? 'bạn'}! Mình là trợ lý ảo của SHAVIK.';
    if (widget.currentProduct != null) {
      welcomeMsg += '\nMình thấy bạn đang xem sản phẩm "${widget.currentProduct!['TenSanPham']}". Bạn cần tư vấn gì về mẫu này không ạ?';
      _lastMentionedProduct = widget.currentProduct!['TenSanPham'];
    } else {
      welcomeMsg += ' Bạn cần tìm sản phẩm gì, hay muốn hỏi về chính sách giao hàng, đổi trả ạ?\n(Bạn có thể bấm các nút gợi ý bên dưới, hoặc gõ "tôi muốn gặp admin" nhé!)';
    }

    _messages.add({
      'isUser': false,
      'text': welcomeMsg,
      'time': DateFormat('HH:mm').format(DateTime.now()),
      'type': 'ai', 
    });
  }

  void _loadData() async {
    _products = await ApiService.getProducts();
    _categories = await ApiService.getCategories();
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
    if (widget.currentUser != null) {
      await ApiService.sendChatMessage(
        widget.currentUser!['Id'], 
        'Khach', 
        'Chào Admin, mình cần được hỗ trợ tư vấn thêm ạ!'
      );
    }

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

  double? _extractPrice(String text) {
    RegExp regExp = RegExp(r'(\d+(\.\d+)?)');
    Match? match = regExp.firstMatch(text);
    if (match != null) {
      double value = double.parse(match.group(0)!);
      if (text.contains('tr') || text.contains('triệu')) {
        return value * 1000000;
      }
      if (text.contains('k') || text.contains('nghìn')) {
        return value * 1000;
      }
      return value;
    }
    return null;
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

    // 1. KIỂM TRA GẶP ADMIN
    if (lowerText.contains('gặp admin') || lowerText.contains('gặp người') || lowerText.contains('gọi admin') || lowerText.contains('tư vấn viên')) {
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

    String botReply = '';
    bool isIntentFound = false; 
    List<dynamic> displayProducts = []; // Biến lưu danh sách sản phẩm để hiển thị thẻ

    // 2. KIỂM TRA TỪ KHÓA CHUNG (Áo, Quần, Phụ kiện...)
    List<String> categoryKeywords = ['áo', 'quần', 'váy', 'đầm', 'phụ kiện', 'túi', 'kính', 'mũ', 'giày', 'dép'];
    String? foundKeyword;
    
    for (String keyword in categoryKeywords) {
      if (lowerText.contains(keyword)) {
        foundKeyword = keyword;
        break;
      }
    }

    if (foundKeyword != null) {
      var matchedCategories = _categories.where((c) {
        String catName = (c['TenDanhMuc'] ?? '').toString().toLowerCase();
        return catName.contains(foundKeyword!);
      }).toList();

      if (matchedCategories.isNotEmpty) {
        var catId = matchedCategories.first['Id'];
        String catName = matchedCategories.first['TenDanhMuc'];
        
        var catProducts = _products.where((p) => p['DanhMucId'] == catId).toList();
        
        if (catProducts.isNotEmpty) {
          botReply = 'Dạ, bên em có các sản phẩm thuộc danh mục "$catName" như sau:';
          displayProducts = catProducts.take(5).toList(); // Lưu danh sách để vẽ thẻ
          _lastMentionedProduct = catProducts.first['TenSanPham'];
        } else {
          botReply = 'Dạ, hiện tại danh mục "$catName" đang tạm hết hàng. Bạn thông cảm nhé!';
        }
        isIntentFound = true;
      }
    }

    // 3. KIỂM TRA KHÁCH HỎI VỀ GIÁ CẢ
    if (!isIntentFound && (lowerText.contains('giá') || lowerText.contains('bao nhiêu') || lowerText.contains('dưới') || lowerText.contains('trên') || lowerText.contains('khoảng') || lowerText.contains('rẻ') || lowerText.contains('mắc'))) {
      double? priceLimit = _extractPrice(lowerText);
      
      if (priceLimit != null) {
        if (lowerText.contains('dưới') || lowerText.contains('nhỏ hơn') || lowerText.contains('rẻ hơn')) {
          displayProducts = _products.where((p) => (double.tryParse(p['Gia'].toString()) ?? 0) < priceLimit).toList();
          botReply = 'Dạ, em tìm thấy các sản phẩm có giá dưới ${formatPrice(priceLimit)}:';
        } else if (lowerText.contains('trên') || lowerText.contains('lớn hơn') || lowerText.contains('mắc hơn')) {
          displayProducts = _products.where((p) => (double.tryParse(p['Gia'].toString()) ?? 0) > priceLimit).toList();
          botReply = 'Dạ, em tìm thấy các sản phẩm có giá trên ${formatPrice(priceLimit)}:';
        } else {
          displayProducts = _products.where((p) {
            double price = double.tryParse(p['Gia'].toString()) ?? 0;
            return price >= priceLimit * 0.8 && price <= priceLimit * 1.2;
          }).toList();
          botReply = 'Dạ, em tìm thấy các sản phẩm có giá khoảng ${formatPrice(priceLimit)}:';
        }

        if (displayProducts.isNotEmpty) {
          displayProducts = displayProducts.take(5).toList();
          _lastMentionedProduct = displayProducts.first['TenSanPham'];
        } else {
          botReply = 'Dạ tiếc quá, hiện tại em không tìm thấy sản phẩm nào có mức giá đó. Bạn thử tìm mức giá khác nhé!';
        }
      } else if (_lastMentionedProduct != null) {
        var p = _products.firstWhere((e) => e['TenSanPham'] == _lastMentionedProduct, orElse: () => null);
        if (p != null) {
          botReply = 'Dạ, sản phẩm "$_lastMentionedProduct" hiện đang có giá là ${formatPrice(p['Gia'])} ạ.';
        }
      } else {
         botReply = 'Dạ, bạn muốn tìm sản phẩm với mức giá bao nhiêu ạ? (Ví dụ: "Giá dưới 1 triệu", "Giá trên 500k")';
      }
      isIntentFound = true;
    }

    // 4. KIỂM TRA CÁC CÂU HỎI CHÍNH SÁCH KHÁC
    if (!isIntentFound) {
      if (lowerText.contains('ship') || lowerText.contains('giao hàng') || lowerText.contains('vận chuyển')) {
        botReply = 'Dạ, phí ship đồng giá 30.000 VNĐ toàn quốc. Thời gian giao từ 2-4 ngày làm việc ạ.';
        isIntentFound = true;
      }
      else if (lowerText.contains('đổi trả') || lowerText.contains('hoàn tiền') || lowerText.contains('bảo hành')) {
        botReply = 'Dạ, shop hỗ trợ đổi trả trong vòng 7 ngày nếu hàng lỗi. Bạn vào "Đơn hàng của tôi" để yêu cầu hoàn đơn nhé!';
        isIntentFound = true;
      }
      else if (lowerText.contains('thanh toán') || lowerText.contains('chuyển khoản') || lowerText.contains('cod')) {
        botReply = 'Shop nhận thanh toán COD (khi nhận hàng) hoặc Chuyển khoản qua mã VietQR ạ.';
        isIntentFound = true;
      }
      else if (lowerText.contains('chào') || lowerText.contains('hello') || lowerText.contains('hi')) {
        botReply = 'Dạ em chào bạn! Em có thể giúp gì cho bạn ạ?';
        isIntentFound = true;
      }
    }

    // 5. TÌM KIẾM THEO TÊN SẢN PHẨM
    if (!isIntentFound) {
      List<String> words = lowerText.split(' ');
      var matchedProducts = _products.where((p) {
        String productName = (p['TenSanPham'] ?? '').toString().toLowerCase();
        return words.any((word) => word.length > 2 && productName.contains(word));
      }).toList();

      if (matchedProducts.isNotEmpty) {
        var p = matchedProducts.first; 
        _lastMentionedProduct = p['TenSanPham']; 
        botReply = 'Dạ, em tìm thấy sản phẩm phù hợp:';
        displayProducts = [p]; // Chỉ hiện đúng sản phẩm đó
      } else {
        botReply = 'Dạ xin lỗi, em chưa hiểu rõ ý bạn lắm. Bạn có thể hỏi em về:\n- Tìm áo, quần, phụ kiện...\n- Tìm theo giá (Ví dụ: "dưới 500k")\n- Chính sách ship, đổi trả\nHoặc gõ "gặp admin" để được hỗ trợ trực tiếp nhé!';
      }
    }

    // Gửi tin nhắn (nếu có sản phẩm thì gửi kèm thẻ)
    if (displayProducts.isNotEmpty) {
       _sendProductReply(botReply, displayProducts);
    } else {
       _sendBotReply(botReply);
    }
  }

  // Hàm gửi tin nhắn chỉ có text
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

  // Hàm gửi tin nhắn kèm danh sách thẻ sản phẩm
  void _sendProductReply(String reply, List<dynamic> products) {
    if (mounted) {
      setState(() {
        _messages.add({
          'isUser': false,
          'text': reply,
          'products': products, // Lưu kèm danh sách sản phẩm
          'time': DateFormat('HH:mm').format(DateTime.now()),
          'type': 'product', // Đánh dấu đây là tin nhắn chứa sản phẩm
        });
        _isTyping = false; 
      });
      _scrollToBottom();
    }
  }

  Widget _buildQuickReplyButton(String label, String message) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        backgroundColor: Theme.of(context).cardColor,
        side: BorderSide(color: const Color(0xFF00E5FF).withOpacity(0.5)),
        label: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF00E5FF))),
        onPressed: () {
          _msgCtrl.text = message;
          _handleUserMessage(message);
        },
      ),
    );
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
                Text(_isChattingWithAdmin ? 'Admin SHAVIK' : 'Trợ Lý Ảo SHAVIK', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                bool isProductMsg = msg['type'] == 'product';

                return Column(
                  crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    // 1. Bong bóng chat (Text)
                    Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 4),
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
                    ),

                    // 2. Nếu là tin nhắn có kèm sản phẩm -> Vẽ danh sách thẻ
                    if (isProductMsg && msg['products'] != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
                        child: SizedBox(
                          height: 210, // Chiều cao của thẻ sản phẩm
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: (msg['products'] as List).length,
                            itemBuilder: (context, pIndex) {
                              final p = msg['products'][pIndex];
                              return GestureDetector(
                                onTap: () {
                                  // Bấm vào thẻ -> Chuyển sang trang chi tiết
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ProductDetailScreen(
                                        productId: p['Id'],
                                        currentUser: widget.currentUser,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 140,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                        child: Image.network(
                                          p['HinhAnh'] ?? '', height: 100, width: 140, fit: BoxFit.cover,
                                          errorBuilder: (a,b,c) => Container(height: 100, color: Colors.grey[800], child: const Icon(Icons.image)),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(p['TenSanPham'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                                            const SizedBox(height: 4),
                                            Text(formatPrice(p['Gia']), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                                            const SizedBox(height: 4),
                                            const Text('Xem chi tiết >', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 10)),
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          
          if (!_isChattingWithAdmin)
            Container(
              height: 40,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _buildQuickReplyButton('Xem Áo', 'Shop có những loại áo nào?'),
                  _buildQuickReplyButton('Xem Quần', 'Shop có những loại quần nào?'),
                  _buildQuickReplyButton('Xem Phụ kiện', 'Shop có phụ kiện gì không?'),
                  _buildQuickReplyButton('Giá dưới 500k', 'Giá dưới 500k'),
                  _buildQuickReplyButton('Giá trên 1tr', 'Giá trên 1tr'),
                ],
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