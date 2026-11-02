import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/formatters.dart';
import 'product_detail_screen.dart';

class FavoriteScreen extends StatefulWidget {
  final Map<String, dynamic>? currentUser;
  const FavoriteScreen({super.key, required this.currentUser});

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  late Future<List<dynamic>> _futureFavorites;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  void _loadFavorites() {
    if (widget.currentUser != null) {
      setState(() {
        _futureFavorites = ApiService.getFavorites(widget.currentUser!['Id']);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentUser == null) {
      return Scaffold(
        appBar: AppBar(
            title: const Text('SẢN PHẨM YÊU THÍCH'), centerTitle: true),
        body: const Center(
            child: Text('Vui lòng đăng nhập để xem danh sách yêu thích.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('SẢN PHẨM YÊU THÍCH'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFavorites,
          )
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _futureFavorites,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('Chưa có sản phẩm yêu thích nào.',
                  style: TextStyle(color: Colors.grey)),
            );
          }

          final items = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final int pId = int.parse(item['Id'].toString());

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(8),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      item['HinhAnh'] ?? '',
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (a, b, c) => Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image),
                      ),
                    ),
                  ),
                  title: Text(item['TenSanPham'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    formatPrice(item['Gia']),
                    style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.favorite, color: Colors.red),
                    onPressed: () async {
                      await ApiService.toggleFavorite(
                          widget.currentUser!['Id'], pId);
                      _loadFavorites();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Đã bỏ yêu thích!'),
                              duration: Duration(seconds: 1)),
                        );
                      }
                    },
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductDetailScreen(
                          productId: pId,
                          currentUser: widget.currentUser,
                        ),
                      ),
                    ).then((_) => _loadFavorites());
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}