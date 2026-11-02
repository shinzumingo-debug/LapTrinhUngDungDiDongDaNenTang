import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/formatters.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  final Map<String, dynamic>? currentUser;
  const CartScreen({super.key, required this.currentUser});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late Future<List<dynamic>> _futureCart;

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  void _loadCart() {
    if (widget.currentUser != null) {
      setState(() {
        _futureCart = ApiService.getCart(widget.currentUser!['Id']);
      });
    }
  }

  void _updateQuantity(int cartId, int currentQty, int delta) async {
    int newQty = currentQty + delta;
    if (newQty <= 0) {
      _deleteItem(cartId);
      return;
    }
    await ApiService.updateCartQuantity(cartId, newQty);
    _loadCart();
  }

  void _deleteItem(int cartId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc muốn xóa sản phẩm này khỏi giỏ hàng?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await ApiService.deleteCartItem(cartId);
      _loadCart();
    }
  }

void _goToCheckout(List<dynamic> cartItems, double total) {
    final formattedItems = cartItems.map((item) {
      return {
        // Ép buộc lấy SanPhamBienTheId, nếu null sẽ báo lỗi ngay
        'Id': item['SanPhamBienTheId'], 
        'TenSanPham': item['TenSanPham'],
        'HinhAnh': item['HinhAnh'],
        'Gia': item['Gia'],
        'MauSac': item['MauSac'],
        'KichThuoc': item['KichThuoc'],
        'SoLuong': item['SoLuong'],
      };
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(
          currentUser: widget.currentUser!,
          checkoutItems: formattedItems,
          initialTotal: total,
        ),
      ),
    ).then((_) => _loadCart());
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('GIỎ HÀNG'), centerTitle: true),
        body: const Center(child: Text('Vui lòng đăng nhập để xem giỏ hàng.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('GIỎ HÀNG CỦA TÔI'), centerTitle: true),
      body: FutureBuilder<List<dynamic>>(
        future: _futureCart,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('Giỏ hàng trống.', style: TextStyle(color: Colors.grey)));

          final cartItems = snapshot.data!;
          double total = cartItems.fold(0, (sum, item) => sum + (double.tryParse(item['ThanhTien'].toString()) ?? 0));

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    final item = cartItems[index];
                    int cartId = item['Id'];
                    int quantity = item['SoLuong'];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                item['HinhAnh'] ?? '',
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (a, b, c) => Container(width: 60, height: 60, color: Colors.grey[200], child: const Icon(Icons.image)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['TenSanPham'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Text('${item['MauSac']} - Size ${item['KichThuoc']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(formatPrice(item['ThanhTien']), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                  onPressed: () => _deleteItem(cartId),
                                ),
                                Container(
                                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade700), borderRadius: BorderRadius.circular(8)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      InkWell(
                                        onTap: () => _updateQuantity(cartId, quantity, -1),
                                        child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Icon(Icons.remove, size: 16)),
                                      ),
                                      Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text('$quantity', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                      InkWell(
                                        onTap: () => _updateQuantity(cartId, quantity, 1),
                                        child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Icon(Icons.add, size: 16, color: Color(0xFF00E5FF))),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tổng tiền giỏ hàng:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text(formatPrice(total), style: const TextStyle(fontSize: 16, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF),
                        foregroundColor: const Color(0xFF0A192F),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: cartItems.isEmpty ? null : () => _goToCheckout(cartItems, total),
                      child: const Text('MUA HÀNG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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