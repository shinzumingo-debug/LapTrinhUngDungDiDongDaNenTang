import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Thư viện để copy
import '../services/api_service.dart';

class VoucherScreen extends StatefulWidget {
  const VoucherScreen({super.key});

  @override
  State<VoucherScreen> createState() => _VoucherScreenState();
}

class _VoucherScreenState extends State<VoucherScreen> {
  late Future<List<dynamic>> _futureVouchers;

  @override
  void initState() {
    super.initState();
    _loadVouchers();
  }

  void _loadVouchers() {
    setState(() {
      _futureVouchers = ApiService.getAvailablePromotions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Kho Voucher', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF1E293B)),
            onPressed: _loadVouchers,
          )
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _futureVouchers,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('Hiện tại chưa có mã giảm giá nào từ hệ thống.',
                  style: TextStyle(color: Colors.grey)),
            );
          }

          final vouchers = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: vouchers.length,
            itemBuilder: (context, index) {
              final v = vouchers[index];
              String code = v['MaGiamGia'] ?? '';
              int percent = v['PhanTramGiam'] ?? 0;
              String desc = v['MoTa'] ?? 'Không có mô tả';
              bool isFreeship = (v['LoaiGiamGia'] ?? 1) == 2;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    // Phần bên trái (Biểu tượng)
                    Container(
                      width: 80,
                      height: 100,
                      decoration: BoxDecoration(
                        color: isFreeship ? Colors.orange.withOpacity(0.1) : const Color(0xFF1E293B).withOpacity(0.05),
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                      ),
                      child: Icon(
                        isFreeship ? Icons.local_shipping : Icons.confirmation_number,
                        color: isFreeship ? Colors.orangeAccent : const Color(0xFF1E293B),
                        size: 32,
                      ),
                    ),
                    // Đường kẻ đứt (mô phỏng vé)
                    SizedBox(
                      height: 100,
                      child: VerticalDivider(
                        color: Colors.grey.shade300,
                        thickness: 1,
                        width: 1,
                      ),
                    ),
                    // Phần bên phải (Thông tin)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mã: $code',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Giảm $percent% - $desc',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 30,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E293B),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                ),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: code));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Đã sao chép mã $code!'), backgroundColor: Colors.green),
                                  );
                                },
                                child: const Text('Sao chép', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
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