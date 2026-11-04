import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/formatters.dart';
import 'checkout_screen.dart';

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
  String? _currentImageUrl;

  @override
  void initState() {
    super.initState();
    _loadDetail();
    _loadReviews();
    _checkFavorite();
  }

  void _loadDetail() {
    setState(() {
      _currentImageUrl = null;
      _selectedVariant = null;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập!')),
      );
      return;
    }
    await ApiService.toggleFavorite(widget.currentUser!['Id'], widget.productId);
    setState(() => _isFavorite = !_isFavorite);
  }

  void _addToCart() async {
    if (widget.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để mua hàng.')),
      );
      return;
    }
    if (_selectedVariant == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn kích thước!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final variantId = _variantId(_selectedVariant);
    if (variantId == null) return;

    final stock = _selectedVariant!['SoLuong'] ?? 0;
    if (stock is int && _quantity > stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Số lượng trong kho không đủ!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await ApiService.addToCart(
      widget.currentUser!['Id'],
      int.parse(variantId.toString()),
      _quantity,
    );

    if (!mounted) return;
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã thêm vào giỏ hàng!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _buyNow(Map<String, dynamic> product) {
    if (widget.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để mua hàng.')),
      );
      return;
    }
    if (_selectedVariant == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn kích thước!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final variantId = _variantId(_selectedVariant);
    if (variantId == null) return;

    final stock = _selectedVariant!['SoLuong'] ?? 0;
    if (stock is int && _quantity > stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Số lượng trong kho không đủ!'),
          backgroundColor: Colors.orange,
        ),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để đánh giá!')),
      );
      return;
    }

    int rating = 5;
    final commentCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              'Đánh giá sản phẩm',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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
                  decoration: InputDecoration(
                    hintText: 'Chia sẻ cảm nhận của bạn...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final res = await ApiService.addReview(
                    widget.currentUser!['Id'],
                    widget.productId,
                    rating,
                    commentCtrl.text.trim(),
                  );
                  if (res['status'] == 'success') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Cảm ơn bạn đã đánh giá!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _loadReviews();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res['message']),
                        backgroundColor: Colors.red,
                      ),
                    );
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

  Widget _buildColorCircle(String colorName, bool isSelected) {
    Color color = Colors.grey;
    if (colorName.toLowerCase().contains('đen')) color = Colors.black;
    if (colorName.toLowerCase().contains('trắng')) color = Colors.white;
    if (colorName.toLowerCase().contains('xanh')) color = Colors.blue;
    if (colorName.toLowerCase().contains('đỏ')) color = Colors.red;
    if (colorName.toLowerCase().contains('hồng')) color = Colors.pink;

    return Container(
      margin: const EdgeInsets.only(right: 12),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? const Color(0xFF1E293B) : Colors.grey.shade300,
          width: isSelected ? 2.5 : 1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.share_outlined), onPressed: () {}),
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : null,
            ),
            onPressed: _toggleFav,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _futureDetail,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!['product'] == null) {
            return const Center(child: Text('Không tìm thấy sản phẩm.'));
          }

          final product = snapshot.data!['product'];
          final variants = snapshot.data!['variants'] as List<dynamic>? ?? [];
          List<String> uniqueColors = variants.map((v) => (v['MauSac'] ?? '').toString()).toSet().toList();
          String defaultImage = product['HinhAnh'] ?? '';

          // TÍNH ĐIỂM ĐÁNH GIÁ THẬT TỪ DATABASE
          return FutureBuilder<List<dynamic>>(
            future: _futureReviews,
            builder: (context, reviewSnapshot) {
              double averageRating = 0;
              int reviewCount = 0;
              
              if (reviewSnapshot.hasData) {
                reviewCount = reviewSnapshot.data!.length;
                if (reviewCount > 0) {
                  double totalStars = reviewSnapshot.data!.fold(0, (sum, r) => sum + (r['SoSao'] ?? 0));
                  averageRating = totalStars / reviewCount;
                }
              }

              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                            child: Image.network(
                              _currentImageUrl ?? defaultImage,
                              width: double.infinity,
                              height: 350,
                              fit: BoxFit.cover,
                              errorBuilder: (a, b, c) => Container(
                                height: 350,
                                color: Colors.grey[800],
                                child: const Icon(Icons.image, size: 80),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product['TenSanPham'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      formatPrice(product['Gia']),
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      formatPrice((double.tryParse(product['Gia'].toString()) ?? 0) * 1.2),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // HIỂN THỊ ĐÁNH GIÁ THẬT
                                Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${averageRating.toStringAsFixed(1)} ($reviewCount đánh giá)',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (uniqueColors.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Màu sắc', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: uniqueColors.map((color) {
                                      bool isSelected = _selectedVariant != null && _selectedVariant!['MauSac'] == color;
                                      return GestureDetector(
                                        onTap: () {
                                          var firstVariant = variants.firstWhere((v) => v['MauSac'] == color);
                                          setState(() {
                                            _selectedVariant = firstVariant;
                                            _currentImageUrl = firstVariant['HinhAnh'] ?? defaultImage;
                                          });
                                        },
                                        child: _buildColorCircle(color, isSelected),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Kích thước', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: variants.where((v) => _selectedVariant == null || v['MauSac'] == _selectedVariant!['MauSac']).map<Widget>((v) {
                                    final isSelected = _variantId(_selectedVariant) == _variantId(v);
                                    return ChoiceChip(
                                      label: Text(v['KichThuoc'] ?? ''),
                                      selected: isSelected,
                                      selectedColor: const Color(0xFF1E293B),
                                      labelStyle: TextStyle(
                                        color: isSelected ? Colors.white : null,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      onSelected: (val) => setState(() => _selectedVariant = val ? v : null),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Mô tả sản phẩm', style: TextStyle(fontWeight: FontWeight.bold)),
                                    TextButton.icon(
                                      onPressed: _showReviewDialog,
                                      icon: const Icon(Icons.rate_review, size: 16),
                                      label: const Text('Đánh giá'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  product['MoTa'] ?? 'Đang cập nhật...',
                                  style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
                                ),
                                const SizedBox(height: 16),
                                const Text('Đánh giá từ khách hàng', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                if (!reviewSnapshot.hasData) 
                                  const Center(child: CircularProgressIndicator())
                                else if (reviewSnapshot.data!.isEmpty)
                                  const Text(
                                    'Chưa có đánh giá.',
                                    style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                                  )
                                else
                                  Column(
                                    children: reviewSnapshot.data!.map((r) {
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
                                                color: Colors.amber,
                                                size: 12,
                                              )),
                                            ),
                                          ],
                                        ),
                                        subtitle: Text(r['BinhLuan'] ?? '', style: const TextStyle(fontSize: 13)),
                                      );
                                    }).toList(),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: OutlinedButton(
                              onPressed: _addToCart,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF1E293B), width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text(
                                'Thêm vào giỏ',
                                style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () => _buyNow(product),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E293B),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text('Mua ngay', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              );
            },
          );
        },
      ),
    );
  }
}