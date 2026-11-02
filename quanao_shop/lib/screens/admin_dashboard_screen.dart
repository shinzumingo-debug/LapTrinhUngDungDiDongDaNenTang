import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/formatters.dart';
import 'admin_chat_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  const AdminDashboardScreen({super.key, required this.currentUser});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    int adminId = widget.currentUser['Id'];

    final List<Widget> pages = [
      AdminStatisticsTab(adminId: adminId), // Tab Thống kê
      AdminOrderList(adminId: adminId),
      AdminProductList(adminId: adminId),
      AdminCustomerList(adminId: adminId),
      AdminPromotionList(adminId: adminId),
      AdminAddProduct(adminId: adminId),
      AdminInventory(adminId: adminId),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('SHAMIKIN ADMIN'),
        backgroundColor: const Color(0xFF0F131C),
        foregroundColor: const Color(0xFF00E5FF),
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF00E5FF),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Thống kê'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Đơn'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'Sản phẩm'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Khách'),
          BottomNavigationBarItem(icon: Icon(Icons.confirmation_number), label: 'Khuyến mãi'),
          BottomNavigationBarItem(icon: Icon(Icons.add_box), label: 'Thêm SP'),
          BottomNavigationBarItem(icon: Icon(Icons.warehouse), label: 'Tồn kho'),
        ],
      ),
    );
  }
}

// ================= 1. TAB THỐNG KÊ =================
class AdminStatisticsTab extends StatefulWidget {
  final int adminId;
  const AdminStatisticsTab({super.key, required this.adminId});

  @override
  State<AdminStatisticsTab> createState() => _AdminStatisticsTabState();
}

class _AdminStatisticsTabState extends State<AdminStatisticsTab> {
  late Future<Map<String, dynamic>> _futureStats;

  @override
  void initState() {
    super.initState();
    _futureStats = ApiService.getAdminStatistics(widget.adminId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _futureStats,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
if (!snapshot.hasData || snapshot.data!['status'] == 'error') {
          return const Center(child: Text('Lỗi tải dữ liệu thống kê!'));
        }

        final data = snapshot.data!['data'];
        final double revenue = double.tryParse(data['totalRevenue'].toString()) ?? 0;
        final int orders = data['totalOrders'] ?? 0;
        final int customers = data['totalCustomers'] ?? 0;
        final List<dynamic> chartData = data['chartData'] ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TỔNG QUAN CỬA HÀNG', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Doanh Thu',
                      value: formatPrice(revenue),
                      icon: Icons.attach_money,
                      color: Colors.greenAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Đơn Hàng',
                      value: '$orders',
                      icon: Icons.shopping_bag,
                      color: Colors.orangeAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                title: 'Khách Hàng',
                value: '$customers',
                icon: Icons.people_alt,
                color: Colors.blueAccent,
              ),

              const SizedBox(height: 24),
              const Text('DOANH THU 7 NGÀY QUA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              Container(
                height: 200,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: chartData.isEmpty
                    ? const Center(child: Text('Chưa có dữ liệu', style: TextStyle(color: Colors.grey)))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: chartData.map((item) {
                          double doanhThuNgay = double.tryParse(item['DoanhThu'].toString()) ?? 0;
                          double maxRevenue = chartData
                              .map((e) => double.tryParse(e['DoanhThu'].toString()) ?? 0)
                              .reduce((a, b) => a > b ? a : b);
double heightRatio = maxRevenue == 0 ? 0 : (doanhThuNgay / maxRevenue) * 120;

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                doanhThuNgay > 0 ? '${(doanhThuNgay / 1000).toStringAsFixed(0)}k' : '',
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 20,
                                height: heightRatio < 5 ? 5 : heightRatio,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00E5FF),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(item['Ngay'] ?? '', style: const TextStyle(fontSize: 10)),
                            ],
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

// ================= 2. TAB ĐƠN HÀNG =================
class AdminOrderList extends StatefulWidget {
  final int adminId;
  const AdminOrderList({super.key, required this.adminId});

  @override
  State<AdminOrderList> createState() => _AdminOrderListState();
}

class _AdminOrderListState extends State<AdminOrderList> {
  late Future<List<dynamic>> _futureOrders;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  void _loadOrders() {
    setState(() {
      _futureOrders = ApiService.getAdminOrders(widget.adminId);
    });
  }

  void _updateStatus(int orderId, String currentStatus, String? trangThaiHoan) {
    if (trangThaiHoan == 'ChoDuyet') {
      showModalBottomSheet(
        context: context,
shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Yêu cầu hoàn đơn', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Khách hàng muốn trả lại hàng. Bạn xử lý thế nào?', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity, height: 45,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    var res = await ApiService.approveReturn(widget.adminId, orderId, true);
                    if (res['status'] == 'success') _loadOrders();
                  },
                  child: const Text('ĐỒNG Ý HOÀN ĐƠN (Cộng lại kho)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity, height: 45,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    var res = await ApiService.approveReturn(widget.adminId, orderId, false);
                    if (res['status'] == 'success') _loadOrders();
                  },
                  child: const Text('TỪ CHỐI HOÀN ĐƠN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Cập nhật trạng thái đơn', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: ['ChoXacNhan', 'DaXacNhan', 'DangGiao', 'DaGiao', 'DaHuy'].map((st) {
                bool isCurrent = st == currentStatus;
                return ChoiceChip(
                  label: Text(_getStatusText(st)),
                  selected: isCurrent,
                  selectedColor: const Color(0xFF00E5FF),
labelStyle: TextStyle(color: isCurrent ? Colors.black : null, fontWeight: FontWeight.bold),
                  onSelected: (val) async {
                    Navigator.pop(ctx);
                    if (!isCurrent) {
                      bool ok = await ApiService.updateOrderStatus(widget.adminId, orderId, st);
                      if (ok) _loadOrders();
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'ChoXacNhan': return 'Chờ xác nhận';
      case 'DaXacNhan': return 'Đã xác nhận';
      case 'DangGiao': return 'Đang giao';
      case 'DaGiao': return 'Đã giao';
      case 'DaHuy': return 'Đã hủy';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ChoXacNhan': return Colors.orange;
      case 'DaXacNhan': return Colors.blue;
      case 'DangGiao': return Colors.purple;
      case 'DaGiao': return Colors.green;
      case 'DaHuy': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _futureOrders,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final list = snapshot.data!;
        if (list.isEmpty) return const Center(child: Text('Chưa có đơn hàng nào.', style: TextStyle(color: Colors.grey)));

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final o = list[index];
            String status = o['TrangThai'] ?? '';
            
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                leading: CircleAvatar(
                  backgroundColor: _getStatusColor(status).withValues(alpha: 0.2),
                  child: Icon(Icons.receipt, color: _getStatusColor(status)),
                ),
                title: Text('Đơn #${o['Id']} - ${o['HoTen']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tổng: ${formatPrice(o['TongTien'])} - ${_getStatusText(status)}',
                      style: TextStyle(color: _getStatusColor(status), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    if (o['TrangThaiHoan'] == 'ChoDuyet')
                      Text(
                        '⚠️ Yêu cầu hoàn: "${o['LyDoHoan']}"',
style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
                
                trailing: const Icon(Icons.edit, color: Colors.grey, size: 20),
                onTap: () => _updateStatus(o['Id'], status, o['TrangThaiHoan']),
              ),
            );
          },
        );
      },
    );
  }
}

// ================= 3. TAB SẢN PHẨM =================
class AdminProductList extends StatefulWidget {
  final int adminId;
  const AdminProductList({super.key, required this.adminId});

  @override
  State<AdminProductList> createState() => _AdminProductListState();
}

class _AdminProductListState extends State<AdminProductList> {
  late Future<List<dynamic>> _futureProducts;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  void _loadProducts() {
    setState(() {
      _futureProducts = ApiService.getProducts();
    });
  }

  void _deleteProduct(int id) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Xóa sản phẩm này sẽ xóa toàn bộ biến thể?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await ApiService.deleteProduct(widget.adminId, id);
      _loadProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _futureProducts,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final list = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final p = list[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(p['HinhAnh'] ?? '', width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (a,b,c) => const Icon(Icons.image)),
                ),
                title: Text(p['TenSanPham'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(formatPrice(p['Gia']), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
onPressed: () => _deleteProduct(p['Id']),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ================= 4. TAB KHÁCH HÀNG (CÓ CHẤM ĐỎ THÔNG BÁO) =================
class AdminCustomerList extends StatefulWidget {
  final int adminId;
  const AdminCustomerList({super.key, required this.adminId});

  @override
  State<AdminCustomerList> createState() => _AdminCustomerListState();
}

class _AdminCustomerListState extends State<AdminCustomerList> {
  late Future<List<dynamic>> _futureCustomers;
  Set<int> _customersWithUnreadMessages = {}; // Lưu ID khách đang chờ chat

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  void _loadCustomers() async {
    setState(() {
      _futureCustomers = ApiService.getAdminCustomers(widget.adminId);
    });
    
    // Quét xem ai đang có tin nhắn chờ
    var customers = await ApiService.getAdminCustomers(widget.adminId);
    Set<int> unread = {};
    for (var c in customers) {
      List<dynamic> msgs = await ApiService.getChatMessages(c['Id']);
      if (msgs.isNotEmpty) {
        // Nếu tin nhắn cuối cùng là của Khách -> Admin chưa rep
        if (msgs.last['NguoiGui'] == 'Khach') {
          unread.add(c['Id']);
        }
      }
    }
    if (mounted) {
      setState(() {
        _customersWithUnreadMessages = unread;
      });
    }
  }

  void _toggleStatus(int customerId, String hoTen, String currentStatus) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(currentStatus == 'BiKhoa' ? 'Mở khóa tài khoản' : 'Khóa tài khoản'),
        content: Text(currentStatus == 'BiKhoa' 
            ? 'Bạn muốn mở khóa cho khách hàng "$hoTen"?' 
            : 'Bạn muốn KHÓA tài khoản "$hoTen"? Người này sẽ không thể đăng nhập.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: Text(currentStatus == 'BiKhoa' ? 'Mở khóa' : 'Khóa', style: TextStyle(color: currentStatus == 'BiKhoa' ? Colors.green : Colors.red))
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      var res = await ApiService.toggleCustomerStatus(widget.adminId, customerId);
      if (res['status'] == 'success' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']), backgroundColor: Colors.green));
        _loadCustomers();
      }
    }
  }

  void _deleteCustomer(int customerId, String hoTen) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa tài khoản'),
        content: Text('Bạn có chắc muốn xóa tài khoản "$hoTen"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (confirm) {
      bool ok = await ApiService.deleteCustomer(widget.adminId, customerId);
      if (ok && mounted) {
        _loadCustomers();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _futureCustomers,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final list = snapshot.data!;
        if (list.isEmpty) return const Center(child: Text('Chưa có khách hàng.'));

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final c = list[index];
            String status = c['TrangThai'] ?? 'HoatDong';
            bool isBlocked = status == 'BiKhoa';

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: isBlocked ? Colors.redAccent.withValues(alpha: 0.1) : null,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                leading: CircleAvatar(
                  backgroundColor: isBlocked ? Colors.redAccent : const Color(0xFF00E5FF),
                  child: Icon(isBlocked ? Icons.lock : Icons.person, color: Colors.white),
                ),
                title: Row(
                  children: [
                    Expanded(child: Text(c['HoTen'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                    if (isBlocked)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                        child: const Text('BỊ KHÓA', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      )
                  ],
                ),
                subtitle: Text('${c['Email']}\n${c['SoDienThoai'] ?? 'Chưa có SĐT'}', style: const TextStyle(fontSize: 12)),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // NÚT CHAT CÓ CHẤM ĐỎ THÔNG BÁO
                    Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chat, color: Colors.blueAccent),
                          tooltip: 'Nhắn tin',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AdminChatScreen(
customerId: c['Id'], 
                                  customerName: c['HoTen'] ?? 'Khách hàng',
                                ),
                              ),
                            ).then((_) => _loadCustomers()); // Load lại khi thoát chat
                          },
                        ),
                        if (_customersWithUnreadMessages.contains(c['Id']))
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Text(
                                '1',
                                style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                    // NÚT KHÓA
                    IconButton(
                      icon: Icon(isBlocked ? Icons.lock_open : Icons.lock_outline, color: isBlocked ? Colors.green : Colors.orange),
                      onPressed: () => _toggleStatus(c['Id'], c['HoTen'] ?? '', status),
                    ),
                    // NÚT XÓA
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _deleteCustomer(c['Id'], c['HoTen'] ?? ''),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ================= 5. TAB KHUYẾN MÃI =================
class AdminPromotionList extends StatefulWidget {
  final int adminId;
  const AdminPromotionList({super.key, required this.adminId});

  @override
  State<AdminPromotionList> createState() => _AdminPromotionListState();
}

class _AdminPromotionListState extends State<AdminPromotionList> {
  late Future<List<dynamic>> _futurePromos;
  final codeCtrl = TextEditingController();
  final percentCtrl = TextEditingController();
  final limitCtrl = TextEditingController(text: '50');
  final descCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPromos();
  }

  void _loadPromos() {
    setState(() {
      _futurePromos = ApiService.getAdminPromotions(widget.adminId);
    });
  }

  void _addPromo() async {
    final code = codeCtrl.text.trim();
    final percentText = percentCtrl.text.trim().replaceAll('%', '');
    
    if (code.isEmpty || percentText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập Mã và Phần trăm!')));
      return;
    }
int? percent = int.tryParse(percentText);
    if (percent == null || percent < 1 || percent > 100) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phần trăm phải từ 1-100!')));
      return;
    }

    bool ok = await ApiService.addPromotion(widget.adminId, code, percent, int.tryParse(limitCtrl.text) ?? 50, descCtrl.text.trim());
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tạo mã thành công!')));
      codeCtrl.clear(); percentCtrl.clear(); limitCtrl.text = '50'; descCtrl.clear();
      _loadPromos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: Theme.of(context).cardColor,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const Text('TẠO MÃ GIẢM GIÁ MỚI', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00E5FF))),
                  const SizedBox(height: 12),
                  TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Mã (VD: SALE10)', border: OutlineInputBorder(), isDense: true)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: percentCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '% Giảm', border: OutlineInputBorder(), isDense: true))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: limitCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giới hạn', border: OutlineInputBorder(), isDense: true))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Mô tả', border: OutlineInputBorder(), isDense: true)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity, height: 40,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black),
                      onPressed: _addPromo,
                      child: const Text('TẠO MÃ', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('DANH SÁCH MÃ HIỆN CÓ:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          
          FutureBuilder<List<dynamic>>(
future: _futurePromos,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final list = snapshot.data!;
              if (list.isEmpty) return const Center(child: Text('Chưa có mã nào.'));

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final item = list[index];
                  int daDung = item['DaSuDung'] ?? 0;
                  int tongSo = item['SoLuong'] ?? 0;
                  bool hetHan = daDung >= tongSo;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: Icon(Icons.discount, color: hetHan ? Colors.grey : const Color(0xFF00E5FF)),
                      title: Row(
                        children: [
                          Text('${item['MaGiamGia']}', style: TextStyle(fontWeight: FontWeight.bold, decoration: hetHan ? TextDecoration.lineThrough : null)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFF00E5FF).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                            child: Text('-${item['PhanTramGiam']}%', style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 10, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                      subtitle: Text('Đã dùng: $daDung/$tongSo', style: TextStyle(fontSize: 11, color: hetHan ? Colors.red : Colors.grey)),
                    ),
                  );
                },
              );
            },
          )
        ],
      ),
    );
  }
}

// ================= 6. TAB THÊM SẢN PHẨM =================
class AdminAddProduct extends StatefulWidget {
  final int adminId;
  const AdminAddProduct({super.key, required this.adminId});

  @override
  State<AdminAddProduct> createState() => _AdminAddProductState();
}

class _AdminAddProductState extends State<AdminAddProduct> {
  final nameCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final imageCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  int? selectedCatId;

  void _submit() async {
    if (nameCtrl.text.isEmpty || priceCtrl.text.isEmpty || selectedCatId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng điền đủ thông tin!')));
      return;
    }
    double price = double.tryParse(priceCtrl.text) ?? 0;
bool ok = await ApiService.addProduct(widget.adminId, nameCtrl.text, selectedCatId!, price, imageCtrl.text, descCtrl.text);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thêm thành công!')));
      nameCtrl.clear(); priceCtrl.clear(); imageCtrl.clear(); descCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên sản phẩm', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: FutureBuilder<List<dynamic>>(
                  future: ApiService.getCategories(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox();
                    final cats = snapshot.data!;
                    return DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: 'Danh mục', border: OutlineInputBorder(), isDense: true),
                      items: cats.map<DropdownMenuItem<int>>((c) => DropdownMenuItem(value: c['Id'], child: Text(c['TenDanhMuc']))).toList(),
                      onChanged: (val) => setState(() => selectedCatId = val),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giá (VNĐ)', border: OutlineInputBorder(), isDense: true)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(controller: imageCtrl, decoration: const InputDecoration(labelText: 'Link hình ảnh', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Mô tả', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 45,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black),
              onPressed: _submit,
              child: const Text('LƯU SẢN PHẨM', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}

// ================= 7. TAB TỒN KHO =================
class AdminInventory extends StatefulWidget {
  final int adminId;
  const AdminInventory({super.key, required this.adminId});

  @override
  State<AdminInventory> createState() => _AdminInventoryState();
}

class _AdminInventoryState extends State<AdminInventory> {
  int? selectedProdId;
final colorCtrl = TextEditingController();
  final sizeCtrl = TextEditingController();
  final qtyCtrl = TextEditingController();
  
  late Future<List<dynamic>> _futureInventory;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  void _loadInventory() {
    setState(() {
      _futureInventory = ApiService.getAdminInventory(widget.adminId);
    });
  }

  void _submit() async {
    if (selectedProdId == null || colorCtrl.text.isEmpty || sizeCtrl.text.isEmpty || qtyCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng điền đủ thông tin!')));
      return;
    }
    int qty = int.tryParse(qtyCtrl.text) ?? 0;
    bool ok = await ApiService.importInventory(widget.adminId, selectedProdId!, colorCtrl.text.trim(), sizeCtrl.text.trim(), qty);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nhập kho thành công!')));
      colorCtrl.clear(); sizeCtrl.clear(); qtyCtrl.clear();
      _loadInventory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00E5FF),
        foregroundColor: Colors.black,
        onPressed: _showImportForm,
        child: const Icon(Icons.add),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'DANH SÁCH TỒN KHO',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _futureInventory,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Chưa có dữ liệu tồn kho.'));
                }

                final list = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final item = list[index];
                    int soLuong = item['SoLuong'] ?? 0;
                    bool sapHet = soLuong <= 5;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
item['HinhAnh'] ?? '',
                            width: 50, height: 50, fit: BoxFit.cover,
                            errorBuilder: (a,b,c) => const Icon(Icons.image),
                          ),
                        ),
                        title: Text(item['TenSanPham'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text('Màu: ${item['MauSac']} - Size: ${item['KichThuoc']}', style: const TextStyle(fontSize: 12)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Còn: $soLuong',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: sapHet ? Colors.redAccent : Colors.greenAccent,
                                fontSize: 14,
                              ),
                            ),
                            if (sapHet)
                              const Text('Sắp hết!', style: TextStyle(fontSize: 10, color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showImportForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16, right: 16, top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('NHẬP THÊM HÀNG VÀO KHO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF))),
              const SizedBox(height: 16),
              FutureBuilder<List<dynamic>>(
                future: ApiService.getProducts(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  final prods = snapshot.data!;
                  return DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Chọn sản phẩm', border: OutlineInputBorder(), isDense: true),
                    items: prods.map<DropdownMenuItem<int>>((p) => DropdownMenuItem(value: p['Id'], child: Text(p['TenSanPham']))).toList(),
                    onChanged: (val) => selectedProdId = val,
                  );
                },
              ),
              const SizedBox(height: 12),
Row(
                children: [
                  Expanded(child: TextField(controller: colorCtrl, decoration: const InputDecoration(labelText: 'Màu sắc', border: OutlineInputBorder(), isDense: true))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: sizeCtrl, decoration: const InputDecoration(labelText: 'Kích thước', border: OutlineInputBorder(), isDense: true))),
                ],
              ),
              const SizedBox(height: 12),
              TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Số lượng nhập', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity, height: 45,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _submit();
                  },
                  child: const Text('XÁC NHẬN NHẬP KHO', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}