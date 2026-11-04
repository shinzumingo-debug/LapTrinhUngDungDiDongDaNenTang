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
        if (st == 'ChoXacNhan' || st == 'DaXacNhan' || st == 'DangLayHang') {
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
    } catch (e) {}
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

    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Colors.grey;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tài khoản',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // KHỐI THÔNG TIN CÁ NHÂN
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: const Color(0xFF1E293B),
                    child: Text(
                      isLoggedIn ? (user['HoTen'] ?? 'U')[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
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
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'ID: SM${user['Id']}',
                                style: TextStyle(
                                  color: subTextColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bạn chưa đăng nhập',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Đăng nhập để theo dõi đơn hàng',
                                style: TextStyle(
                                  color: subTextColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                  ),
                  if (!isLoggedIn)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _openLoginScreen,
                      child: const Text('Đăng nhập'),
                    )
                ],
              ),
            ),

            const SizedBox(height: 20),

            // KHỐI ĐƠN HÀNG CỦA TÔI
            if (isLoggedIn) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Đơn hàng của tôi',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: textColor,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _openOrderTracking(0),
                          child: Text(
                            'Xem tất cả',
                            style: TextStyle(
                              color: subTextColor,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
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
              const SizedBox(height: 20),
            ],

            // KHỐI MENU CHỨC NĂNG (Đã bỏ VIP)
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                children: [
                  if (isAdmin) ...[
                    _buildMenuItem(
                      Icons.admin_panel_settings,
                      'Trang Quản Trị Admin',
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdminDashboardScreen(currentUser: user!),
                          ),
                        );
                      },
                      textColor: Colors.redAccent,
                    ),
                    const Divider(height: 1),
                  ],
                  
                  _buildMenuItem(
                    Icons.favorite_border,
                    'Sản phẩm yêu thích',
                    () {
                      if (!isLoggedIn) return _openLoginScreen();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FavoriteScreen(currentUser: widget.currentUser),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  
                  _buildMenuItem(
                    Icons.confirmation_number_outlined,
                    'Kho Voucher / Ưu đãi',
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const VoucherScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),

                  _buildMenuItem(
                    Icons.smart_toy_outlined,
                    'Trợ lý ảo AI',
                    () {
                      if (!isLoggedIn) return _openLoginScreen();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(currentUser: widget.currentUser),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),

                  _buildMenuItem(
                    Icons.rate_review_outlined,
                    'Đánh giá của tôi',
                    () {
                      if (!isLoggedIn) return _openLoginScreen();
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
                    tileColor: Colors.transparent,
                    secondary: Icon(Icons.dark_mode_outlined, color: textColor),
                    title: Text(
                      'Giao diện Tối (Dark Mode)',
                      style: TextStyle(fontSize: 14, color: textColor),
                    ),
                    value: widget.isDarkMode,
                    activeColor: const Color(0xFF1E293B),
                    onChanged: widget.onThemeChanged,
                  ),

                  if (isLoggedIn) ...[
                    const Divider(height: 1),
                    _buildMenuItem(
                      Icons.logout,
                      'Đăng xuất',
                      _logout,
                      textColor: Colors.redAccent,
                    ),
                  ]
                ],
              ),
            ),
            const SizedBox(height: 40),
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
              Icon(
                icon,
                size: 28,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
              if (count > 0)
                Positioned(
                  right: -8,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color textColor = const Color(0xFF1E293B),
  }) {
    final defaultColor = Theme.of(context).textTheme.bodyLarge?.color;
    return ListTile(
      tileColor: Colors.transparent,
      leading: Icon(
        icon,
        color: textColor == const Color(0xFF1E293B) ? defaultColor : textColor,
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          color: textColor == const Color(0xFF1E293B) ? defaultColor : textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 14,
        color: Colors.grey,
      ),
      onTap: onTap,
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
      appBar: AppBar(
        title: const Text(
          'Đánh giá của tôi',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _futureMyReviews,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'Bạn chưa viết đánh giá nào.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          final list = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final r = list[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            r['HinhAnh'] ?? '',
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r['TenSanPham'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: List.generate(5, (i) {
                                  return Icon(
                                    i < r['SoSao'] ? Icons.star : Icons.star_border,
                                    color: Colors.amber,
                                    size: 16,
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Text(
                      r['BinhLuan'] ?? '',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}