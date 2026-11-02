import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/formatters.dart';
import 'checkout_screen.dart';
import 'chat_screen.dart'; // <-- ĐÃ THÊM IMPORT CHAT SCREEN

class ProductDetailScreen extends StatefulWidget {
  final int productId;
  final Map<String, dynamic>? currentUser;

  const ProductDetailScreen({
    super.key,
    required this.productId,
    required this.currentUser,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Future<Map<String, dynamic>> _futureDetail;
  late Future<List<dynamic>> _futureReviews;
  Map<String, dynamic>? _selectedVariant;
  bool _isFavorite = false;
  int _quantity = 1; 

  @override
  void initState() {
    super.initState();
    _loadDetail();
    _loadReviews();
    _checkFavorite();
  }

  void _loadDetail() {
    setState(() {
      _futureDetail = ApiService.getProductDetail(widget.productId);
    });
  }

  void _loadReviews() {
    setState(() {
      _futureReviews = ApiService.getProductReviews(widget.productId);
    });
  }

  dynamic _variantId(Map<String, dynamic>? v) {
    if (v == null) return null;
    return v['Id'] ?? v['id'] ?? v['VariantId'] ?? v['variantId'];
  }

  dynamic _variantPrice(Map<String, dynamic> v, Map<String, dynamic> product) {
    return v['Gia'] ?? v['gia'] ?? product['Gia'];
  }

  void _checkFavorite() async {
    if (widget.currentUser != null) {
      List favs = await ApiService.getFavorites(widget.currentUser!['Id']);
      bool exists = favs.any((f) => int.parse(f['Id'].toString()) == widget.productId);
      if (mounted) setState(() => _isFavorite = exists);
    }
  }

  void _toggleFav() async {
    if (widget.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng đăng nhập!')));
      return;
    }
    await ApiService.toggleFavorite(widget.currentUser!['Id'], widget.productId);
    setState(() => _isFavorite = !_isFavorite);
  }

  void _addToCart() async {
    if (widget.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng đăng nhập để mua hàng.')));
      return;
    }
    if (_selectedVariant == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn phân loại sản phẩm!')));
      return;
    }

    final variantId = _variantId(_selectedVariant);
    if (variantId == null) return;

    final stock = _selectedVariant!['SoLuong'] ?? 0;
    if (stock is int && _quantity > stock) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Số lượng trong kho không đủ!'), backgroundColor: Colors.orange));
      return;
    }

    final result = await ApiService.addToCart(widget.currentUser!['Id'], int.parse(variantId.toString()), _quantity);

    if (!mounted) return;
if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã thêm vào giỏ hàng!'), backgroundColor: Colors.green));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: Colors.red));
    }
  }

  void _buyNow(Map<String, dynamic> product) {
    if (widget.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng đăng nhập để mua hàng.')));
      return;
    }
    if (_selectedVariant == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn phân loại sản phẩm!')));
      return;
    }

    final variantId = _variantId(_selectedVariant);
    if (variantId == null) return;

    final stock = _selectedVariant!['SoLuong'] ?? 0;
    if (stock is int && _quantity > stock) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Số lượng trong kho không đủ!'), backgroundColor: Colors.orange));
      return;
    }

    double price = double.tryParse(_variantPrice(_selectedVariant!, product).toString()) ?? 0;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(
          currentUser: widget.currentUser!,
          checkoutItems: [
            {
              'Id': variantId,
              'TenSanPham': product['TenSanPham'],
              'HinhAnh': product['HinhAnh'],
              'Gia': price,
              'MauSac': _selectedVariant!['MauSac'],
              'KichThuoc': _selectedVariant!['KichThuoc'],
              'SoLuong': _quantity, 
            }
          ],
          initialTotal: price * _quantity, 
        ),
      ),
    );
  }

  void _showReviewDialog() {
    if (widget.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng đăng nhập để đánh giá!')));
      return;
    }

    int rating = 5;
    final commentCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Đánh giá sản phẩm'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 32,
                      ),
                      onPressed: () => setDialogState(() => rating = index + 1),
                    );
                  }),
                ),
                TextField(
                  controller: commentCtrl,
maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Chia sẻ cảm nhận của bạn...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final res = await ApiService.addReview(widget.currentUser!['Id'], widget.productId, rating, commentCtrl.text.trim());
                  if (res['status'] == 'success') {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cảm ơn bạn đã đánh giá!'), backgroundColor: Colors.green));
                    _loadReviews();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']), backgroundColor: Colors.red));
                  }
                },
                child: const Text('Gửi'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi Tiết Sản Phẩm'),
        centerTitle: true,
        actions: [
          // ==========================================
          // NÚT CHAT AI TRÊN THANH APP BAR
          // ==========================================
          IconButton(
            icon: const Icon(Icons.support_agent, color: Color(0xFF00E5FF)),
            tooltip: 'Hỏi AI về sản phẩm này',
            onPressed: () {
              // Lấy dữ liệu sản phẩm hiện tại để truyền sang cho AI
              _futureDetail.then((data) {
                final product = data['product'];
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      currentUser: widget.currentUser,
                      currentProduct: product, // Truyền ngữ cảnh sản phẩm
                    ),
                  ),
                );
              });
            },
          ),
          IconButton(
            icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border, color: _isFavorite ? Colors.red : Colors.white),
            onPressed: _toggleFav,
          )
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _futureDetail,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!['product'] == null) return const Center(child: Text('Không tìm thấy sản phẩm.'));

          final product = snapshot.data!['product'];
          final variants = snapshot.data!['variants'] as List<dynamic>? ?? [];
return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(product['HinhAnh'] ?? '', width: double.infinity, height: 250, fit: BoxFit.cover),
                      ),
                      const SizedBox(height: 16),
                      Text(product['TenSanPham'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                      const SizedBox(height: 8),
                      Text(formatPrice(product['Gia']), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 12),
                      Text(product['MoTa'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                      const SizedBox(height: 20),
                      
                      const Text('Chọn phân loại (Màu - Size):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: variants.map<Widget>((v) {
                          final vId = _variantId(v);
                          final isSelected = _variantId(_selectedVariant) == vId;
                          final stock = v['SoLuong'] ?? 0;
                          final outOfStock = stock is int && stock <= 0;

                          return ChoiceChip(
                            label: Text('${v['MauSac']} - Size ${v['KichThuoc']} (Còn: $stock)'),
                            selected: isSelected,
                            selectedColor: const Color(0xFF00E5FF),
                            labelStyle: TextStyle(color: outOfStock ? Colors.grey : null, decoration: outOfStock ? TextDecoration.lineThrough : null),
                            onSelected: outOfStock ? null : (val) {
                              setState(() {
                                _selectedVariant = val ? v : null;
                                _quantity = 1; 
                              });
                            },
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Text('Số lượng:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(width: 16),
                          Container(
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove, size: 18),
                                  onPressed: () {
                                    if (_quantity > 1) setState(() => _quantity--);
                                  },
                                ),
                                Text('$_quantity', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: const Icon(Icons.add, size: 18),
                                  onPressed: () {
                                    setState(() => _quantity++);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const Divider(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Đánh giá từ khách hàng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          TextButton.icon(
                            onPressed: _showReviewDialog,
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('Viết đánh giá'),
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<List<dynamic>>(
                        future: _futureReviews,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                          final reviews = snapshot.data!;
                          if (reviews.isEmpty) return const Text('Chưa có đánh giá nào cho sản phẩm này.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic));

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: reviews.length,
                            itemBuilder: (context, index) {
                              final r = reviews[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(child: Text(r['HoTen'][0])),
                                title: Row(
                                  children: [
                                    Text(r['HoTen'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    const SizedBox(width: 8),
                                    Row(
children: List.generate(5, (i) => Icon(
                                        i < r['SoSao'] ? Icons.star : Icons.star_border,
                                        color: Colors.amber, size: 14,
                                      )),
                                    )
                                  ],
                                ),
                                subtitle: Text(r['BinhLuan'] ?? '', style: const TextStyle(fontSize: 13)),
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Theme.of(context).cardColor, border: const Border(top: BorderSide(color: Colors.grey, width: 0.2))),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(border: Border.all(color: const Color(0xFF00E5FF)), borderRadius: BorderRadius.circular(12)),
                      child: IconButton(icon: const Icon(Icons.add_shopping_cart, color: Color(0xFF00E5FF)), onPressed: _addToCart),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: const Color(0xFF0A192F)),
                          onPressed: () => _buyNow(product),
                          child: const Text('MUA NGAY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    )
                  ],
                ),
              )
            ],
          );
        },
      ),
    );
  }
}