import 'package:flutter/material.dart';

class VoucherScreen extends StatelessWidget {
  const VoucherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> sampleVouchers = [
      {'code': 'SHAMIKIN10', 'discount': 'Giảm 10%', 'desc': 'Áp dụng cho mọi đơn hàng từ 200,000 VNĐ.'},
      {'code': 'SHAMIKIN20', 'discount': 'Giảm 20%', 'desc': 'Áp dụng cho khách hàng mua từ 2 sản phẩm.'},
      {'code': 'FREESHIP', 'discount': 'Giảm 15%', 'desc': 'Ưu đãi phí vận chuyển toàn quốc.'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('KHO VOUCHER / ƯU ĐÃI'),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: sampleVouchers.length,
        itemBuilder: (context, index) {
          final v = sampleVouchers[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF00E5FF),
                child: Icon(Icons.confirmation_number, color: Color(0xFF0A192F)),
              ),
              title: Text('Mã: ${v['code']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00E5FF))),
              subtitle: Text('${v['discount']} - ${v['desc']}'),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF).withOpacity(0.2),
                  foregroundColor: const Color(0xFF00E5FF),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã sao chép mã ${v['code']}!')),
                  );
                },
                child: const Text('Sao chép'),
              ),
            ),
          );
        },
      ),
    );
  }
}