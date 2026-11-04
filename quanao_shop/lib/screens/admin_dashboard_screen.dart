import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
      AdminStatisticsTab(adminId: adminId),
      AdminOrderList(adminId: adminId),
      AdminProductList(adminId: adminId),
      AdminCustomerList(adminId: adminId),
      AdminPromotionList(adminId: adminId),
      AdminAddProduct(adminId: adminId),
      AdminInventory(adminId: adminId),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('QUẢN TRỊ SHAVIK', style: TextStyle(fontWeight: FontWeight.w900)),
        elevation: 0,
        centerTitle: true,
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Thống kê'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), label: 'Đơn'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), label: 'Sản phẩm'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: 'Khách'),
          BottomNavigationBarItem(icon: Icon(Icons.confirmation_number_outlined), label: 'Khuyến mãi'),
          BottomNavigationBarItem(icon: Icon(Icons.add_box_outlined), label: 'Thêm SP'),
          BottomNavigationBarItem(icon: Icon(Icons.warehouse_outlined), label: 'Tồn kho'),
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
        
        double maxRevenue = 0;
        if (chartData.isNotEmpty) {
          maxRevenue = chartData.map((e) => double.tryParse(e['DoanhThu'].toString()) ?? 0).reduce((a, b) => a > b ? a : b);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('XIN CHÀO, ADMIN 👋', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Dưới đây là tổng quan hoạt động của cửa hàng hôm nay.', style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 20),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF334155)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: const Color(0xFF1E293B).withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.account_balance_wallet, color: Colors.white, size: 24),
                        SizedBox(width: 8),
                        Text('TỔNG DOANH THU', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(formatPrice(revenue), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 28)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(child: _buildStatCard(title: 'ĐƠN HÀNG', value: '$orders', icon: Icons.shopping_bag, color: Colors.orangeAccent)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatCard(title: 'KHÁCH HÀNG', value: '$customers', icon: Icons.people_alt, color: Colors.blueAccent)),
                ],
              ),
              const SizedBox(height: 24),

              const Text('DOANH THU 7 NGÀY QUA', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                height: 220,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: chartData.isEmpty
                    ? const Center(child: Text('Chưa có dữ liệu', style: TextStyle(color: Colors.grey)))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: chartData.map((item) {
                          double doanhThuNgay = double.tryParse(item['DoanhThu'].toString()) ?? 0;
                          double heightRatio = maxRevenue == 0 ? 0 : (doanhThuNgay / maxRevenue) * 130;

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(doanhThuNgay > 0 ? '${(doanhThuNgay / 1000).toStringAsFixed(0)}k' : '', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Container(
                                width: 24,
                                height: heightRatio < 5 ? 5 : heightRatio,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF475569)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(item['Ngay'] ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey)),
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
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

  String _formatDateTime(String? isoString) {
    if (isoString == null) return 'Đang cập nhật...';
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      final formatter = DateFormat('HH:mm - dd/MM/yyyy');
      return formatter.format(dateTime);
    } catch (e) {
      return 'Không xác định';
    }
  }

  void _updateStatus(int orderId, String currentStatus, String? trangThaiHoan) {
    if (trangThaiHoan == 'ChoDuyet') {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Yêu cầu hoàn đơn', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Khách hàng muốn trả lại hàng. Bạn xử lý thế nào?', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 45,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    var res = await ApiService.approveReturn(widget.adminId, orderId, true);
                    if (res['status'] == 'success') _loadOrders();
                  },
                  child: const Text('ĐỒNG Ý HOÀN ĐƠN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Cập nhật trạng thái đơn', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10, runSpacing: 10,
              children: ['ChoXacNhan', 'DaXacNhan', 'DangGiao', 'DaGiao', 'DaHuy'].map((st) {
                bool isCurrent = st == currentStatus;
                return ChoiceChip(
                  label: Text(_getStatusText(st)),
                  selected: isCurrent,
                  selectedColor: const Color(0xFF1E293B),
                  labelStyle: TextStyle(color: isCurrent ? Colors.white : Colors.black),
                  backgroundColor: const Color(0xFFF4F7FB),
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
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final o = list[index];
            String status = o['TrangThai'] ?? '';
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Đơn #${o['Id']} - ${o['HoTen']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: _getStatusColor(status).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text(_getStatusText(status), style: TextStyle(color: _getStatusColor(status), fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        'Đặt lúc: ${_formatDateTime(o['NgayTao'])}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  Text('Tổng: ${formatPrice(o['TongTien'])}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (o['TrangThaiHoan'] == 'ChoDuyet') ...[
                    const SizedBox(height: 8),
                    Text('⚠️ Yêu cầu hoàn: "${o['LyDoHoan']}"', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _updateStatus(o['Id'], status, o['TrangThaiHoan']),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Cập nhật', style: TextStyle(fontWeight: FontWeight.bold)),
                      )
                    ],
                  )
                ],
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

  void _showEditProductDialog(Map<String, dynamic> product) {
    final nameCtrl = TextEditingController(text: product['TenSanPham']);
    final priceCtrl = TextEditingController(text: product['Gia'].toString());
    final imageCtrl = TextEditingController(text: product['HinhAnh']);
    final descCtrl = TextEditingController(text: product['MoTa']);
    int? selectedCatId = product['DanhMucId'];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sửa Sản Phẩm #${product['Id']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên sản phẩm', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              FutureBuilder<List<dynamic>>(
                future: ApiService.getCategories(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  final cats = snapshot.data!;
                  return DropdownButtonFormField<int>(
                    value: selectedCatId,
                    decoration: const InputDecoration(labelText: 'Danh mục', border: OutlineInputBorder(), isDense: true),
                    items: cats.map<DropdownMenuItem<int>>((c) => DropdownMenuItem(value: c['Id'], child: Text(c['TenDanhMuc']))).toList(),
                    onChanged: (val) => selectedCatId = val,
                  );
                },
              ),
              const SizedBox(height: 12),
              TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giá (VNĐ)', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: imageCtrl, decoration: const InputDecoration(labelText: 'Link hình ảnh', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Mô tả', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty || priceCtrl.text.isEmpty || selectedCatId == null) return;
              double price = double.tryParse(priceCtrl.text) ?? 0;
              bool ok = await ApiService.updateProduct(widget.adminId, product['Id'], nameCtrl.text, selectedCatId!, price, imageCtrl.text, descCtrl.text);
              if (ok && mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật thành công!'), backgroundColor: Colors.green));
                _loadProducts();
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật thất bại!'), backgroundColor: Colors.red));
              }
            },
            child: const Text('LƯU THAY ĐỔI'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _futureProducts,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final list = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final p = list[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(p['HinhAnh'] ?? '', width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (a,b,c) => const Icon(Icons.image))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['TenSanPham'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(formatPrice(p['Gia']), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.blueAccent), onPressed: () => _showEditProductDialog(p)),
                      IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _deleteProduct(p['Id'])),
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ================= 4. TAB KHÁCH HÀNG =================
class AdminCustomerList extends StatefulWidget {
  final int adminId;
  const AdminCustomerList({super.key, required this.adminId});

  @override
  State<AdminCustomerList> createState() => _AdminCustomerListState();
}

class _AdminCustomerListState extends State<AdminCustomerList> {
  late Future<List<dynamic>> _futureCustomers;
  Set<int> _customersWithUnreadMessages = {};

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  void _loadCustomers() async {
    setState(() {
      _futureCustomers = ApiService.getAdminCustomers(widget.adminId);
    });
    
    var customers = await ApiService.getAdminCustomers(widget.adminId);
    Set<int> unread = {};
    for (var c in customers) {
      List<dynamic> msgs = await ApiService.getChatMessages(c['Id']);
      if (msgs.isNotEmpty && msgs.last['NguoiGui'] == 'Khach') {
        unread.add(c['Id']);
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
        content: Text(currentStatus == 'BiKhoa' ? 'Bạn muốn mở khóa cho khách hàng "$hoTen"?' : 'Bạn muốn KHÓA tài khoản "$hoTen"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(currentStatus == 'BiKhoa' ? 'Mở khóa' : 'Khóa', style: TextStyle(color: currentStatus == 'BiKhoa' ? Colors.green : Colors.red))),
        ],
      ),
    ) ?? false;

    if (confirm) {
      var res = await ApiService.toggleCustomerStatus(widget.adminId, customerId);
      if (res['status'] == 'success' && mounted) {
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
      if (ok && mounted) _loadCustomers();
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
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final c = list[index];
            String status = c['TrangThai'] ?? 'HoatDong';
            bool isBlocked = status == 'BiKhoa';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: isBlocked ? Border.all(color: Colors.redAccent.withOpacity(0.5)) : null,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))]
              ),
              child: Row(
                children: [
                  CircleAvatar(backgroundColor: isBlocked ? Colors.redAccent : const Color(0xFF1E293B), child: Icon(isBlocked ? Icons.lock : Icons.person, color: Colors.white)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c['HoTen'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(c['Email'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chat, color: Colors.blueAccent),
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => AdminChatScreen(customerId: c['Id'], customerName: c['HoTen'] ?? 'Khách hàng'))).then((_) => _loadCustomers());
                            },
                          ),
                          if (_customersWithUnreadMessages.contains(c['Id']))
                            Positioned(right: 8, top: 8, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Text('1', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)))),
                        ],
                      ),
                      IconButton(icon: Icon(isBlocked ? Icons.lock_open : Icons.lock_outline, color: isBlocked ? Colors.green : Colors.orange), onPressed: () => _toggleStatus(c['Id'], c['HoTen'] ?? '', status)),
                      IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _deleteCustomer(c['Id'], c['HoTen'] ?? '')),
                    ],
                  ),
                ],
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
  int _selectedPromoType = 1;

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

    bool ok = await ApiService.addPromotion(widget.adminId, code, percent, int.tryParse(limitCtrl.text) ?? 50, descCtrl.text.trim(), loaiGiamGia: _selectedPromoType);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tạo mã thành công!'), backgroundColor: Colors.green));
      codeCtrl.clear(); percentCtrl.clear(); limitCtrl.text = '50'; descCtrl.clear(); setState(() => _selectedPromoType = 1);
      _loadPromos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20), 
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))]
            ),
            child: Column(
              children: [
                const Text('TẠO MÃ GIẢM GIÁ MỚI', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Mã (VD: SALE10)', border: OutlineInputBorder(), isDense: true)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: percentCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '% Giảm', border: OutlineInputBorder(), isDense: true))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: limitCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giới hạn', border: OutlineInputBorder(), isDense: true))),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Mô tả', border: OutlineInputBorder(), isDense: true)),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _selectedPromoType,
                  decoration: const InputDecoration(labelText: 'Loại', border: OutlineInputBorder(), isDense: true),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Giảm giá Sản phẩm')),
                    DropdownMenuItem(value: 2, child: Text('Freeship')),
                  ],
                  onChanged: (val) => setState(() => _selectedPromoType = val!),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity, height: 45,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white),
                    onPressed: _addPromo,
                    child: const Text('TẠO MÃ', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('DANH SÁCH MÃ HIỆN CÓ:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          
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
                  bool isFreeship = (item['LoaiGiamGia'] ?? 1) == 2;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12)
                    ),
                    child: ListTile(
                      leading: Icon(isFreeship ? Icons.local_shipping : Icons.discount, color: isFreeship ? Colors.orangeAccent : null),
                      title: Row(
                        children: [
                          Text('${item['MaGiamGia']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: (isFreeship ? Colors.orangeAccent : const Color(0xFF1E293B)).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                            child: Text(isFreeship ? 'FREESHIP' : '-${item['PhanTramGiam']}%', style: TextStyle(color: isFreeship ? Colors.orangeAccent : const Color(0xFF1E293B), fontSize: 10, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                      subtitle: Text('Đã dùng: ${item['DaSuDung'] ?? 0}/${item['SoLuong'] ?? 0}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thêm thành công!'), backgroundColor: Colors.green));
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
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nhập kho thành công!'), backgroundColor: Colors.green));
      colorCtrl.clear(); sizeCtrl.clear(); qtyCtrl.clear();
      _loadInventory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('DANH SÁCH TỒN KHO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16), 
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))]
                      ),
                      child: Row(
                        children: [
                          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(item['HinhAnh'] ?? '', width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (a,b,c) => const Icon(Icons.image))),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['TenSanPham'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('Màu: ${item['MauSac']} - Size: ${item['KichThuoc']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Còn: $soLuong', style: TextStyle(fontWeight: FontWeight.bold, color: sapHet ? Colors.redAccent : Colors.green, fontSize: 14)),
                              if (sapHet) const Text('Sắp hết!', style: TextStyle(fontSize: 10, color: Colors.redAccent)),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (ctx) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                  left: 20,
                  right: 20,
                  top: 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'NHẬP THÊM HÀNG VÀO KHO',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      
                      FutureBuilder<List<dynamic>>(
                        future: ApiService.getProducts(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();
                          final prods = snapshot.data!;
                          return DropdownButtonFormField<int>(
                            decoration: const InputDecoration(
                              labelText: 'Chọn sản phẩm',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            items: prods.map<DropdownMenuItem<int>>((p) {
                              return DropdownMenuItem(
                                value: p['Id'],
                                child: Text(p['TenSanPham']),
                              );
                            }).toList(),
                            onChanged: (val) => selectedProdId = val,
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: colorCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Màu sắc',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: sizeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Kích thước',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      
                      TextField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Số lượng nhập',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E293B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _submit();
                          },
                          child: const Text(
                            'XÁC NHẬN NHẬP KHO',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            },
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}