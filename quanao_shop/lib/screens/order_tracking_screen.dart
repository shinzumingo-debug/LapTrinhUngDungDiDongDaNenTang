import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'product_detail_screen.dart'; // Thêm import này để chuyển trang đánh giá

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

  // HÀM ĐỊNH DẠNG GIÁ TIỀN CÓ DẤU PHẨY (VD: 400,000 VNĐ)
  String _formatCurrency(dynamic price) {
    if (price == null) return '0 VNĐ';
    num numValue = num.tryParse(price.toString()) ?? 0;
    final formatter = NumberFormat('#,###', 'en_US');
    return '${formatter.format(numValue)} VNĐ';
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'ChoXacNhan':
        return 'Chờ xác nhận';
      case 'DaXacNhan':
      case 'DangLayHang':
        return 'Chờ lấy hàng';
      case 'DangGiao':
        return 'Đang giao hàng';
      case 'DaGiao':
        return 'Giao thành công';
      case 'DaHuy':
        return 'Đã hủy';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ChoXacNhan':
        return Colors.orangeAccent;
      case 'DaXacNhan':
      case 'DangLayHang':
        return Colors.blueAccent;
      case 'DangGiao':
        return Colors.purpleAccent;
      case 'DaGiao':
        return Colors.green;
      case 'DaHuy':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  void _cancelOrder(int orderId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận hủy đơn'),
        content: Text('Bạn có chắc chắn muốn hủy Đơn hàng #$orderId không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Đóng'),
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
            const SnackBar(content: Text('Lỗi kết nối Server! Vui lòng thử lại.')),
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
        title: const Text('Yêu cầu hoàn đơn'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Vui lòng nhập lý do bạn muốn hoàn đơn (VD: Hàng bị rách, giao sai size...):'),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Lý do...'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              var res = await ApiService.requestReturn(orderId, widget.currentUser['Id'], reasonCtrl.text.trim());
              if (res['status'] == 'success' && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']), backgroundColor: Colors.green));
                _loadOrders();
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']), backgroundColor: Colors.red));
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
      length: 2,
      initialIndex: widget.initialTabIndex < 2 ? widget.initialTabIndex : 0,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ĐƠN HÀNG CỦA TÔI'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF00E5FF)),
              onPressed: _loadOrders, // Gọi lại API để lấy trạng thái mới
            )
          ],
          bottom: const TabBar(
            indicatorColor: Color(0xFF00E5FF),
            labelColor: Color(0xFF00E5FF),
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(icon: Icon(Icons.shopping_bag_outlined), text: 'Đơn Đặt & Giao'),
              Tab(icon: Icon(Icons.cancel_outlined), text: 'Đơn Đã Hủy'),
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
                
                final activeOrders = allOrders.where((o) => o['TrangThai'] != 'DaHuy').toList();
                final canceledOrders = allOrders.where((o) => o['TrangThai'] == 'DaHuy').toList();

                return TabBarView(
                  children: [
                    _buildOrderList(activeOrders, isCanceledTab: false),
                    _buildOrderList(canceledOrders, isCanceledTab: true),
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
              color: Colors.grey.shade600,
            ),
            const SizedBox(height: 12),
            Text(
isCanceledTab ? 'Không có đơn hàng nào đã hủy.' : 'Chưa có đơn hàng nào ở trạng thái này.',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        String status = order['TrangThai'] ?? '';
        List items = order['ChiTiet'] ?? [];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Mã đơn: #${order['Id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.15),
                        border: Border.all(color: _getStatusColor(status)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getStatusText(status),
                        style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
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
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.image, size: 25),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['TenSanPham'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Phân loại: ${item['MauSac'] ?? ''} - Size ${item['KichThuoc'] ?? ''}',
                                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                                  ),
                                  Text('x${item['SoLuong']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            Text(_formatCurrency(item['Gia']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                    const Text('Tổng thanh toán:', style: TextStyle(fontWeight: FontWeight.w500)),
                    Text(
                      _formatCurrency(order['TongTien']),
                      style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                
                // NÚT HỦY ĐƠN (Khi đang chờ xác nhận)
                if (status == 'ChoXacNhan') ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isCancelling ? null : () => _cancelOrder(order['Id']),
                      child: const Text('HỦY ĐƠN HÀNG NÀY', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],

                // NÚT ĐÁNH GIÁ (Khi đã giao thành công)
                // NÚT ĐÁNH GIÁ VÀ HOÀN ĐƠN (Khi đã giao thành công)
                // NÚT ĐÁNH GIÁ VÀ HOÀN ĐƠN (Khi đã giao thành công)
                if (status == 'DaGiao' && items.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Nút Đánh giá
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF00E5FF)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                          icon: const Icon(Icons.rate_review, color: Color(0xFF00E5FF), size: 18),
                          label: const Text('ĐÁNH GIÁ', style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      
                      // Nút Hoàn đơn (Chỉ hiện nếu chưa có yêu cầu hoàn và chưa quá 7 ngày)
                      if (order['TrangThaiHoan'] == 'KhongCo' || order['TrangThaiHoan'] == null)
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.orangeAccent),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _showReturnDialog(order['Id']),
                            icon: const Icon(Icons.assignment_return, color: Colors.orangeAccent, size: 18),
                            label: const Text('HOÀN ĐƠN', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                          ),
                        ),
                    ],
                  ),
                ],
                
                // HIỂN THỊ TRẠNG THÁI HOÀN ĐƠN (Nếu có)
                if (order['TrangThaiHoan'] != null && order['TrangThaiHoan'] != 'KhongCo') ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
color: order['TrangThaiHoan'] == 'ChoDuyet' ? Colors.orange.withOpacity(0.1) : (order['TrangThaiHoan'] == 'DaDuyet' ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: order['TrangThaiHoan'] == 'ChoDuyet' ? Colors.orange : (order['TrangThaiHoan'] == 'DaDuyet' ? Colors.green : Colors.red)),
                    ),
                    child: Text(
                      'Trạng thái hoàn: ${order['TrangThaiHoan'] == 'ChoDuyet' ? 'Đang chờ Admin duyệt' : (order['TrangThaiHoan'] == 'DaDuyet' ? 'Đã được duyệt (Hoàn tiền)' : 'Bị từ chối')}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: order['TrangThaiHoan'] == 'ChoDuyet' ? Colors.orange : (order['TrangThaiHoan'] == 'DaDuyet' ? Colors.green : Colors.red)),
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