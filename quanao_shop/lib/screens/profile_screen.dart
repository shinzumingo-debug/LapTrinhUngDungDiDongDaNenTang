import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'admin_dashboard_screen.dart';
import 'favorite_screen.dart';
import 'login_screen.dart';
import 'order_tracking_screen.dart';
import 'voucher_screen.dart';
import 'chat_screen.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? currentUser;
  final Function(Map<String, dynamic>?) onUserChanged;
  final bool isDarkMode;
  final Function(bool) onThemeChanged;

  const ProfileScreen({
    super.key,
    required this.currentUser,
    required this.onUserChanged,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int countChoXacNhan = 0;
  int countDangGiao = 0;
  int countDaGiao = 0;
  int countDaHuy = 0;

  @override
  void initState() {
    super.initState();
    _fetchOrderCounts();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentUser != oldWidget.currentUser) {
      _fetchOrderCounts();
    }
  }

  void _fetchOrderCounts() async {
    if (widget.currentUser == null) {
      setState(() {
        countChoXacNhan = 0;
        countDangGiao = 0;
        countDaGiao = 0;
        countDaHuy = 0;
      });
      return;
    }

    try {
      final orders = await ApiService.getUserOrders(widget.currentUser!['Id']);
      int choXacNhan = 0;
      int dangGiao = 0;
      int daGiao = 0;
      int daHuy = 0;

      for (var o in orders) {
        String st = o['TrangThai'] ?? '';
        if (st == 'ChoXacNhan' || st == 'DaXacNhan') {
          choXacNhan++;
        } else if (st == 'DangGiao') {
          dangGiao++;
        } else if (st == 'DaGiao') {
          daGiao++;
        } else if (st == 'DaHuy') {
          daHuy++;
        }
      }

      if (mounted) {
        setState(() {
          countChoXacNhan = choXacNhan;
          countDangGiao = dangGiao;
          countDaGiao = daGiao;
          countDaHuy = daHuy;
        });
      }
    } catch (e) {
      // Bỏ qua lỗi kết nối
    }
  }

  void _openOrderTracking(int initialTab) {
    if (widget.currentUser == null) {
      _openLoginScreen();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderTrackingScreen(
          currentUser: widget.currentUser!,
          initialTabIndex: initialTab,
        ),
      ),
    ).then((_) => _fetchOrderCounts());
  }

  void _openLoginScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LoginScreen(
          onUserChanged: (user) {
            widget.onUserChanged(user);
          },
        ),
      ),
    ).then((_) => _fetchOrderCounts());
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    widget.onUserChanged(null);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã đăng xuất khỏi tài khoản.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.currentUser;
    bool isLoggedIn = user != null;
    String role = isLoggedIn ? (user['VaiTro'] ?? 'KhachHang').toString().trim().toLowerCase() : '';
    bool isAdmin = role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('TÀI KHOẢN CỦA TÔI'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: const Color(0xFF00E5FF),
                      child: Text(
                        isLoggedIn ? (user['HoTen'] ?? 'U')[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0A192F)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: isLoggedIn
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user['HoTen'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                                const SizedBox(height: 4),
                                Text(user['Email'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                if (isAdmin) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.redAccent),
                                    ),
                                    child: const Text('QUẢN TRỊ VIÊN (ADMIN)', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                  )
                                ]
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Bạn chưa đăng nhập', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                const Text('Đăng nhập để theo dõi đơn hàng và ưu đãi', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                    ),
                    if (!isLoggedIn)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E5FF),
                          foregroundColor: const Color(0xFF0A192F),
                        ),
                        onPressed: _openLoginScreen,
                        child: const Text('Đăng nhập', style: TextStyle(fontWeight: FontWeight.bold)),
                      )
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Đơn hàng của tôi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        GestureDetector(
                          onTap: () => _openOrderTracking(0),
                          child: const Text('Xem tất cả >', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildOrderItem(Icons.hourglass_top, 'Chờ xác nhận', countChoXacNhan, () => _openOrderTracking(0)),
                        _buildOrderItem(Icons.local_shipping, 'Đang giao', countDangGiao, () => _openOrderTracking(1)),
                        _buildOrderItem(Icons.check_circle_outline, 'Đã giao', countDaGiao, () => _openOrderTracking(2)),
                        _buildOrderItem(Icons.cancel_outlined, 'Đã hủy', countDaHuy, () => _openOrderTracking(3)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  if (isAdmin)
                    ListTile(
                      leading: const Icon(Icons.admin_panel_settings, color: Colors.redAccent),
                      title: const Text('Trang Quản Trị Admin', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => AdminDashboardScreen(currentUser: user!)),
                        );
                      },
                    ),
                  if (isAdmin) const Divider(height: 1),

                  ListTile(
                    leading: const Icon(Icons.confirmation_number_outlined, color: Color(0xFF00E5FF)),
                    title: const Text('Kho Voucher / Mã giảm giá'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const VoucherScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.smart_toy, color: Colors.blueAccent),
                    title: const Text('Trợ lý ảo AI'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      if (!isLoggedIn) {
                        _openLoginScreen();
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(currentUser: widget.currentUser),
                        ),
                      );
                    },
                  ),

                  // ➕ MỤC SẢN PHẨM YÊU THÍCH
                  ListTile(
                    leading: const Icon(Icons.favorite, color: Colors.redAccent),
                    title: const Text('Sản phẩm yêu thích'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      if (!isLoggedIn) {
                        _openLoginScreen();
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FavoriteScreen(currentUser: widget.currentUser),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.rate_review, color: Colors.amber),
                    title: const Text('Đánh giá của tôi'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      if (!isLoggedIn) {
                        _openLoginScreen();
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MyReviewsScreen(currentUser: widget.currentUser!),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),


                  SwitchListTile(
                    secondary: Icon(
                      widget.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                      color: const Color(0xFF00E5FF),
                    ),
                    title: const Text('Giao diện Tối (Dark Mode)'),
                    value: widget.isDarkMode,
                    onChanged: widget.onThemeChanged,
                  ),

                  if (isLoggedIn) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.redAccent),
                      title: const Text('Đăng xuất tài khoản', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      onTap: _logout,
                    ),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItem(IconData icon, String label, int count, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, size: 28, color: const Color(0xFF00E5FF)),
              if (count > 0)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
// ================= MÀN HÌNH XEM LẠI ĐÁNH GIÁ CỦA TÔI =================
class MyReviewsScreen extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  const MyReviewsScreen({super.key, required this.currentUser});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  late Future<List<dynamic>> _futureMyReviews;

  @override
  void initState() {
    super.initState();
    _futureMyReviews = ApiService.getUserReviews(widget.currentUser['Id']);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ĐÁNH GIÁ CỦA TÔI'), centerTitle: true),
      body: FutureBuilder<List<dynamic>>(
        future: _futureMyReviews,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Bạn chưa viết đánh giá nào.', style: TextStyle(color: Colors.grey)));
          }

          final list = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final r = list[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(r['HinhAnh'] ?? '', width: 50, height: 50, fit: BoxFit.cover),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r['TenSanPham'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 4),
                                Row(
                                  children: List.generate(5, (i) => Icon(
                                    i < r['SoSao'] ? Icons.star : Icons.star_border,
                                    color: Colors.amber, size: 16,
                                  )),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
Text(r['BinhLuan'] ?? '', style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}