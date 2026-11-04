import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'product_detail_screen.dart';

class OrderTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final int initialTabIndex;

  const OrderTrackingScreen({
    super.key,
    required this.currentUser,
    this.initialTabIndex = 0,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  late Future<List<dynamic>> _futureOrders;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  void _loadOrders() {
    setState(() {
      _futureOrders = ApiService.getUserOrders(widget.currentUser['Id']);
    });
  }

  String _formatCurrency(dynamic price) {
    if (price == null) return '0 VNĐ';
    num numValue = num.tryParse(price.toString()) ?? 0;
    final formatter = NumberFormat('#,###', 'en_US');
    return '${formatter.format(numValue)} VNĐ';
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

  String _getStatusText(String status) {
    switch (status) {
      case 'ChoXacNhan': return 'Chờ xác nhận';
      case 'DaXacNhan':
      case 'DangLayHang': return 'Chờ lấy hàng';
      case 'DangGiao': return 'Đang giao hàng';
      case 'DaGiao': return 'Giao thành công';
      case 'DaHuy': return 'Đã hủy';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ChoXacNhan': return Colors.orangeAccent;
      case 'DaXacNhan':
      case 'DangLayHang': return Colors.blueAccent;
      case 'DangGiao': return Colors.purpleAccent;
      case 'DaGiao': return Colors.green;
      case 'DaHuy': return Colors.redAccent;
      default: return Colors.grey;
    }
  }

  void _cancelOrder(int orderId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận hủy đơn'),
        content: Text('Bạn có chắc chắn muốn hủy Đơn hàng #$orderId không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Đóng', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hủy Đơn', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isCancelling = true);
      try {
        var res = await ApiService.cancelOrder(orderId, widget.currentUser['Id']);
        if (mounted) {
          setState(() => _isCancelling = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Thao tác hoàn tất')),
          );
          _loadOrders();
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isCancelling = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lỗi kết nối Server!')),
          );
        }
      }
    }
  }

  void _showReturnDialog(int orderId) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Yêu cầu hoàn đơn'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Vui lòng nhập lý do bạn muốn hoàn đơn:'),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Lý do...',
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
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              var res = await ApiService.requestReturn(orderId, widget.currentUser['Id'], reasonCtrl.text.trim());
              if (res['status'] == 'success' && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(res['message']), backgroundColor: Colors.green),
                );
                _loadOrders();
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(res['message']), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Gửi yêu cầu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      initialIndex: widget.initialTabIndex < 4 ? widget.initialTabIndex : 0,
      child: Scaffold(
        // Đã xóa backgroundColor cứng
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Đơn hàng của tôi',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadOrders,
            )
          ],
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Color(0xFF1E293B),
            labelColor: Color(0xFF1E293B),
            unselectedLabelColor: Colors.grey,
            indicatorWeight: 3,
            tabs: [
              Tab(text: 'Chờ xác nhận'),
              Tab(text: 'Đang giao'),
              Tab(text: 'Đã giao'),
              Tab(text: 'Đã hủy'),
            ],
          ),
        ),
        body: Stack(
          children: [
            FutureBuilder<List<dynamic>>(
              future: _futureOrders,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allOrders = snapshot.data ?? [];
                
                final choXacNhan = allOrders.where((o) => o['TrangThai'] == 'ChoXacNhan' || o['TrangThai'] == 'DaXacNhan' || o['TrangThai'] == 'DangLayHang').toList();
                final dangGiao = allOrders.where((o) => o['TrangThai'] == 'DangGiao').toList();
                final daGiao = allOrders.where((o) => o['TrangThai'] == 'DaGiao').toList();
                final daHuy = allOrders.where((o) => o['TrangThai'] == 'DaHuy').toList();

                return TabBarView(
                  children: [
                    _buildOrderList(choXacNhan, isCanceledTab: false),
                    _buildOrderList(dangGiao, isCanceledTab: false),
                    _buildOrderList(daGiao, isCanceledTab: false),
                    _buildOrderList(daHuy, isCanceledTab: true),
                  ],
                );
              },
            ),
            if (_isCancelling)
              Container(
                color: Colors.black45,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderList(List<dynamic> orders, {required bool isCanceledTab}) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isCanceledTab ? Icons.remove_shopping_cart_outlined : Icons.inbox_outlined,
              size: 70,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              isCanceledTab ? 'Không có đơn hàng nào đã hủy.' : 'Chưa có đơn hàng nào.',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        String status = order['TrangThai'] ?? '';
        List items = order['ChiTiet'] ?? [];

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor, // Tự đổi màu theo Theme
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Mã đơn: #${order['Id']}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _getStatusText(status),
                        style: TextStyle(
                          color: _getStatusColor(status),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Đặt lúc: ${_formatDateTime(order['NgayTao'])}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                if (status == 'DaGiao') ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        'Nhận lúc: ${_formatDateTime(order['NgayGiaoHang'])}',
                        style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],

                const Divider(height: 24),
                
                if (items.isNotEmpty) ...[
                  Column(
                    children: items.map<Widget>((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                item['HinhAnh'] ?? '',
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (a, b, c) => Container(
                                  width: 50,
                                  height: 50,
                                  color: Colors.grey[800],
                                  child: const Icon(Icons.image),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['TenSanPham'] ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Phân loại: ${item['MauSac'] ?? ''} - ${item['KichThuoc'] ?? ''}',
                                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                                  ),
                                  Text(
                                    'x${item['SoLuong']}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _formatCurrency(item['Gia']),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const Divider(height: 16),
                ],
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tổng thanh toán:', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
                    Text(
                      _formatCurrency(order['TongTien']),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ],
                ),
                
                if (status == 'ChoXacNhan') ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isCancelling ? null : () => _cancelOrder(order['Id']),
                      child: const Text(
                        'HỦY ĐƠN HÀNG',
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],

                if (status == 'DaGiao' && items.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF1E293B)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            final rawId = items[0]['SanPhamId'];
                            if (rawId == null) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProductDetailScreen(
                                  productId: int.parse(rawId.toString()),
                                  currentUser: widget.currentUser,
                                ),
                              ),
                            ).then((_) => _loadOrders());
                          },
                          icon: const Icon(Icons.rate_review, size: 18),
                          label: const Text('ĐÁNH GIÁ', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (order['TrangThaiHoan'] == 'KhongCo' || order['TrangThaiHoan'] == null)
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.orangeAccent),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => _showReturnDialog(order['Id']),
                            icon: const Icon(Icons.assignment_return, color: Colors.orangeAccent, size: 18),
                            label: const Text('HOÀN ĐƠN', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                          ),
                        ),
                    ],
                  ),
                ],
                
                if (order['TrangThaiHoan'] != null && order['TrangThaiHoan'] != 'KhongCo') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: order['TrangThaiHoan'] == 'ChoDuyet' ? Colors.orange.withOpacity(0.1) : (order['TrangThaiHoan'] == 'DaDuyet' ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: order['TrangThaiHoan'] == 'ChoDuyet' ? Colors.orange : (order['TrangThaiHoan'] == 'DaDuyet' ? Colors.green : Colors.red),
                      ),
                    ),
                    child: Text(
                      'Trạng thái hoàn: ${order['TrangThaiHoan'] == 'ChoDuyet' ? 'Đang chờ Admin duyệt' : (order['TrangThaiHoan'] == 'DaDuyet' ? 'Đã được duyệt (Hoàn tiền)' : 'Bị từ chối')}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: order['TrangThaiHoan'] == 'ChoDuyet' ? Colors.orange : (order['TrangThaiHoan'] == 'DaDuyet' ? Colors.green : Colors.red),
                      ),
                    ),
                  )
                ]
              ],
            ),
          ),
        );
      },
    );
  }
}