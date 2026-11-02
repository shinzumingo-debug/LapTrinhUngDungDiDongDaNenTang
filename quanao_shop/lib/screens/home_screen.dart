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
  final searchCtrl = TextEditingController();
  int? selectedCategoryId;
  String currentCategoryName = 'Tất cả';

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
    _bannerTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
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
    searchCtrl.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _futureCategories = ApiService.getCategories();
      _futureProducts = ApiService.getProducts(
        query: searchCtrl.text.trim(),
        categoryId: selectedCategoryId,
      );
    });
  }

  // HÀM LẤY ICON THEO TÊN DANH MỤC
  IconData _getCategoryIcon(String name) {
    String lower = name.toLowerCase();
    if (lower.contains('áo')) return Icons.checkroom;
    if (lower.contains('quần')) return Icons.dry_cleaning;
    if (lower.contains('váy') || lower.contains('đầm')) return Icons.woman;
    if (lower.contains('phụ kiện') || lower.contains('túi') || lower.contains('kính') || lower.contains('mũ')) {
      return Icons.watch; // Icon cho Phụ kiện
    }
    return Icons.category;
  }

  // Hàm hiển thị bảng chọn danh mục (Bottom Sheet nâng cấp)
  void _showCategoryBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
builder: (context) {
        return FutureBuilder<List<dynamic>>(
          future: _futureCategories,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final categories = snapshot.data!;

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chọn Danh Mục',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      // Nút "Tất cả"
                      ChoiceChip(
                        avatar: Icon(
                          Icons.grid_view,
                          color: selectedCategoryId == null ? const Color(0xFF0A192F) : Colors.grey,
                          size: 18,
                        ),
                        label: const Text('Tất cả'),
                        selected: selectedCategoryId == null,
                        selectedColor: const Color(0xFF00E5FF),
                        labelStyle: TextStyle(
                          color: selectedCategoryId == null ? const Color(0xFF0A192F) : null,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (val) {
                          setState(() {
                            selectedCategoryId = null;
                            currentCategoryName = 'Tất cả';
                          });
                          _loadData();
                          Navigator.pop(context);
                        },
                      ),
                      // Các danh mục khác
                      ...categories.map((cat) {
                        bool isSelected = selectedCategoryId == cat['Id'];
                        String catName = cat['TenDanhMuc'] ?? '';
                        return ChoiceChip(
                          avatar: Icon(
                            _getCategoryIcon(catName),
                            color: isSelected ? const Color(0xFF0A192F) : Colors.grey,
                            size: 18,
                          ),
                          label: Text(catName),
                          selected: isSelected,
                          selectedColor: const Color(0xFF00E5FF),
                          labelStyle: TextStyle(
                            color: isSelected ? const Color(0xFF0A192F) : null,
                            fontWeight: FontWeight.bold,
                          ),
onSelected: (val) {
                            setState(() {
                              selectedCategoryId = cat['Id'];
                              currentCategoryName = catName;
                            });
                            _loadData();
                            Navigator.pop(context);
                          },
                        );
                      }).toList(),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: const Color(0xFF0F131C),
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/logo.png',
                width: 30,
                height: 30,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00E5FF), Color(0xFF0055FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'SM',
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
            const Text(
              'SHAMIKIN SHOP',
              style: TextStyle(
                color: Color(0xFF00E5FF),
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF00E5FF), size: 28),
            tooltip: 'Chọn danh mục',
            onPressed: _showCategoryBottomSheet,
          ),
        ],
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
// --- 1. THANH TÌM KIẾM ---
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: TextField(
                      controller: searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm sản phẩm quần áo...',
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF00E5FF)),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            searchCtrl.clear();
                            _loadData();
                          },
                        ),
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (_) => _loadData(),
                    ),
                  ),

                  // --- 2. BANNER CHẠY TỰ ĐỘNG ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 160,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
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
                                    color: const Color(0xFF151922),
                                    child: const Icon(Icons.image, size: 60, color: Colors.grey),
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
                            return GestureDetector(
                              onTap: () {
                                _bannerController.animateToPage(
                                  index,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: _currentBannerIndex == index ? 22 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _currentBannerIndex == index
                                      ? const Color(0xFF00E5FF)
                                      : Colors.grey.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // --- 3. TIÊU ĐỀ SẢN PHẨM ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          currentCategoryName == 'Tất cả' 
                              ? 'Sản Phẩm Mới Nhất' 
                              : 'Danh mục: $currentCategoryName',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        GestureDetector(
                          onTap: _showCategoryBottomSheet,
                          child: const Text(
                            'Lọc danh mục >',
                            style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            // --- 4. DANH SÁCH SẢN PHẨM ---
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
                          'Không tìm thấy sản phẩm nào.\n(Kéo xuống để tải lại)',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  );
                }

                final products = snapshot.data!;
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.72,
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
                          child: Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Image.network(
                                    p['HinhAnh'] ?? '',
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (a, b, c) => Container(
                                      color: Colors.grey[800],
                                      child: const Icon(Icons.image, size: 50, color: Colors.grey),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(10.0),
child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p['TenSanPham'] ?? '',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        formatPrice(p['Gia']),
                                        style: const TextStyle(
                                            color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14),
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
}