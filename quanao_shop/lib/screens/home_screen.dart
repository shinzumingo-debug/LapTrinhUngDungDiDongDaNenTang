import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/formatters.dart';
import 'product_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic>? currentUser;
  final Function(Map<String, dynamic>?)? onUserChanged;

  const HomeScreen({
    super.key,
    required this.currentUser,
    this.onUserChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<dynamic>> _futureProducts;
  late Future<List<dynamic>> _futureCategories;
  List<dynamic> _allProducts = [];
  
  int? selectedCategoryId;
  String currentCategoryName = 'Tất cả';
  String? _sortBy = 'newest';

  late PageController _bannerController;
  int _currentBannerIndex = 0;
  Timer? _bannerTimer;

  final List<String> _bannerImages = [
    'https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=800&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1445205170230-053b83016050?w=800&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1472851294608-062f824d29cc?w=800&auto=format&fit=crop&q=80',
  ];

  @override
  void initState() {
    super.initState();
    _bannerController = PageController(initialPage: 0);
    _startBannerTimer();
    _loadData();
  }

  void _startBannerTimer() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_bannerController.hasClients) {
        int nextIndex = (_currentBannerIndex + 1) % _bannerImages.length;
        _bannerController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  void _loadData({String query = ''}) {
    setState(() {
      _futureCategories = ApiService.getCategories();
      _futureProducts = ApiService.getProducts(
        query: query,
        categoryId: selectedCategoryId,
        sortBy: _sortBy,
      );
    });
    _loadAllProductsForSuggestion();
  }

  Future<void> _loadAllProductsForSuggestion() async {
    var allProd = await ApiService.getProducts();
    if (mounted) {
      setState(() {
        _allProducts = allProd;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ĐÃ ĐƯA LOGO TRỞ LẠI
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/images/logo2.jpg',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00E5FF), Color(0xFF0055FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'SV',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'SHAVIK SHOP',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                fontSize: 18,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
        // ĐÃ BỎ 2 ICON CHUÔNG VÀ TÚI XÁCH
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadData();
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // THANH TÌM KIẾM
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Autocomplete<Object>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return const Iterable<Object>.empty();
                        }
                        return _allProducts
                            .where((product) {
                              String name = (product['TenSanPham'] ?? '').toString().toLowerCase();
                              return name.contains(textEditingValue.text.toLowerCase());
                            })
                            .map((e) => e as Object)
                            .toList();
                      },
                      displayStringForOption: (Object option) {
                        final map = option as Map<String, dynamic>;
                        return map['TenSanPham'] ?? '';
                      },
                      onSelected: (Object selection) {
                        final map = selection as Map<String, dynamic>;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProductDetailScreen(
                              productId: map['Id'],
                              currentUser: widget.currentUser,
                            ),
                          ),
                        );
                      },
                      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                        return TextField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            hintText: 'Tìm kiếm sản phẩm...',
                            prefixIcon: Icon(Icons.search),
                            contentPadding: EdgeInsets.symmetric(vertical: 0),
                          ),
                          onSubmitted: (val) => _loadData(query: val),
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 8,
                            borderRadius: BorderRadius.circular(16),
                            color: Theme.of(context).cardColor,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: 250,
                                maxWidth: MediaQuery.of(context).size.width - 32,
                              ),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (context, index) {
                                  final map = options.elementAt(index) as Map<String, dynamic>;
                                  return ListTile(
                                    leading: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        map['HinhAnh'] ?? '',
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        errorBuilder: (a, b, c) => const Icon(Icons.image),
                                      ),
                                    ),
                                    title: Text(
                                      map['TenSanPham'] ?? '',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    trailing: Text(
                                      formatPrice(map['Gia']),
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    onTap: () => onSelected(options.elementAt(index)),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // ĐÃ ĐƯA BANNER TRƯỢT TRỞ LẠI
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 170,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: PageView.builder(
                              controller: _bannerController,
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              onPageChanged: (index) {
                                setState(() => _currentBannerIndex = index);
                              },
                              itemCount: _bannerImages.length,
                              itemBuilder: (context, index) {
                                return Image.network(
                                  _bannerImages[index],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (a, b, c) => Container(
                                    color: Colors.grey[800],
                                    child: const Icon(Icons.image, size: 60),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_bannerImages.length, (index) {
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: _currentBannerIndex == index ? 24 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _currentBannerIndex == index
                                    ? const Color(0xFF1E293B)
                                    : Colors.grey.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // DANH MỤC
                  FutureBuilder<List<dynamic>>(
                    future: _futureCategories,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: snapshot.data!.map((cat) {
                            String catName = cat['TenDanhMuc'] ?? '';
                            int catId = cat['Id'];
                            bool isSelected = selectedCategoryId == catId;
                            return _buildCategoryCircle(
                              _getCategoryIcon(catName),
                              catName,
                              () {
                                setState(() {
                                  if (isSelected) {
                                    selectedCategoryId = null;
                                    currentCategoryName = 'Tất cả';
                                  } else {
                                    selectedCategoryId = catId;
                                    currentCategoryName = catName;
                                  }
                                });
                                _loadData();
                              },
                              isSelected: isSelected,
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // TIÊU ĐỀ SẢN PHẨM
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Sản phẩm: $currentCategoryName 🔥',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.filter_list, size: 20),
                          onSelected: (val) {
                            setState(() => _sortBy = val);
                            _loadData();
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'newest', child: Text('Mới nhất')),
                            const PopupMenuItem(value: 'price_asc', child: Text('Giá thấp - cao')),
                            const PopupMenuItem(value: 'price_desc', child: Text('Giá cao - thấp')),
                            const PopupMenuItem(value: 'best_seller', child: Text('Bán chạy nhất')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // DANH SÁCH SẢN PHẨM
            FutureBuilder<List<dynamic>>(
              future: _futureProducts,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: Text(
                          'Không tìm thấy sản phẩm nào.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  );
                }

                final products = snapshot.data!;
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.6,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final p = products[index];
                        return GestureDetector(
                          onTap: () {
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
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(16),
                                        ),
                                        child: Image.network(
                                          p['HinhAnh'] ?? '',
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (a, b, c) => Container(
                                            color: Colors.grey[800],
                                            child: const Icon(Icons.image),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).cardColor,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.favorite_border,
                                            size: 16,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p['TenSanPham'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            formatPrice(p['Gia']),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              formatPrice((double.tryParse(p['Gia'].toString()) ?? 0) * 1.2),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey,
                                                decoration: TextDecoration.lineThrough,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.star,
                                            color: Colors.amber,
                                            size: 12,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${(p['DiemDanhGia'] ?? 0).toStringAsFixed(1)} (${p['SoLuongDanhGia'] ?? 0})',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: products.length,
                    ),
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String name) {
    String lower = name.toLowerCase();
    if (lower.contains('áo')) return Icons.checkroom;
    if (lower.contains('quần')) return Icons.dry_cleaning;
    if (lower.contains('váy') || lower.contains('đầm')) return Icons.woman;
    if (lower.contains('phụ kiện') || lower.contains('túi') || lower.contains('kính')) {
      return Icons.watch;
    }
    return Icons.category;
  }

  Widget _buildCategoryCircle(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isSelected = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF1E293B) : Theme.of(context).cardColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xFF1E293B),
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF64748B),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}