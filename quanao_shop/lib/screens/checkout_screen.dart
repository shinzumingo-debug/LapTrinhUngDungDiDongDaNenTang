import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/formatters.dart';

class CheckoutScreen extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final List<dynamic> checkoutItems;
  final double initialTotal;

  const CheckoutScreen({
    super.key,
    required this.currentUser,
    required this.checkoutItems,
    required this.initialTotal,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final addressCtrl = TextEditingController(
      text: '123 Đường Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh');
  final promoCtrl = TextEditingController();

  String _paymentMethod = 'COD';
  double discountAmount = 0;
  String? appliedPromoCode;
  bool _isSubmitting = false;

  @override
  void dispose() {
    addressCtrl.dispose();
    promoCtrl.dispose();
    super.dispose();
  }

  void _applyVoucher() async {
    if (promoCtrl.text.trim().isEmpty) return;
    String code = promoCtrl.text.trim();

    var res = await ApiService.applyPromotion(code, widget.initialTotal);
    if (res['status'] == 'success') {
      setState(() {
        discountAmount = double.parse(res['discountAmount'].toString());
        appliedPromoCode = code;
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(res['message'])));
      }
    } else if (mounted) {
      setState(() {
        discountAmount = 0;
        appliedPromoCode = null;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res['message'])));
    }
  }

 void _processCheckout() async {
    if (addressCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng nhập địa chỉ giao hàng!')));
      return;
    }

    setState(() => _isSubmitting = true);

    double finalTotal = widget.initialTotal - discountAmount;
    if (finalTotal < 0) finalTotal = 0;

    // Chuẩn hóa items để đảm bảo có Id biến thể an toàn
    // Chuẩn hóa items để đảm bảo có Id biến thể an toàn
    final List<Map<String, dynamic>> orderItems = [];
    
    for (var item in widget.checkoutItems) {
      // Lấy đúng key 'Id' đã được format ở màn hình Giỏ hàng
      final rawId = item['Id']; 
      
      if (rawId == null) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lỗi: Không tìm thấy mã biến thể sản phẩm!'), backgroundColor: Colors.red),
        );
        return;
      }

      orderItems.add({
        'Id': int.parse(rawId.toString()),
        'TenSanPham': item['TenSanPham'],
        'SoLuong': item['SoLuong'] ?? 1,
        'Gia': item['Gia'],
      });
    }

    bool ok = await ApiService.createOrder(
      widget.currentUser['Id'],
      addressCtrl.text.trim(),
      _paymentMethod,
      finalTotal,
      promoCode: appliedPromoCode,
      items: orderItems,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (ok) {
      _showSuccessDialog(finalTotal);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Đặt hàng thất bại! Vui lòng kiểm tra kết nối hoặc thử lại.'),
            backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccessDialog(double finalTotal) {
    String addInfo = 'SHAMIKIN_${widget.currentUser['Id']}_${finalTotal.toInt()}';
    String qrUrl = 'https://img.vietqr.io/image/MB-1132015271025-compact2.png?amount=$finalTotal&addInfo=$addInfo&accountName=VO%20HOANG%20VU';

    // Tạo một StatefulBuilder để có thể cập nhật trạng thái bên trong Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isPaid = _paymentMethod == 'COD'; // Nếu là COD thì mặc định đã thanh toán (thu tiền mặt)
        
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            
            // Nếu là QR Bank, tự động đếm ngược 10s để fake thanh toán thành công
            if (_paymentMethod == 'QR_BANK' && !isPaid) {
              Future.delayed(const Duration(seconds: 10)).then((_) {
                if (ctx.mounted) {
                  setStateDialog(() {
                    isPaid = true;
                  });
                }
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Column(
                children: [
                  Icon(
                    isPaid ? Icons.check_circle : Icons.qr_code_2,
                    color: isPaid ? Colors.green : const Color(0xFF00E5FF),
                    size: 60,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isPaid ? 'THANH TOÁN THÀNH CÔNG!' : 'QUÉT MÃ ĐỂ THANH TOÁN',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 18,
                      color: isPaid ? Colors.green : null
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Tổng tiền: ${formatPrice(finalTotal)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 16)),
                    const SizedBox(height: 12),
                    
                    // NẾU CHƯA THANH TOÁN VÀ CHỌN QR -> HIỆN MÃ
                    if (!isPaid) ...[
                      const Text('Hệ thống đang chờ chuyển khoản...', style: TextStyle(fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic)),
                      const SizedBox(height: 10),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 250),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(qrUrl, fit: BoxFit.contain),
),
                      ),
                      const SizedBox(height: 12),
                      const Text('Ngân hàng: MB Bank\nSTK: 1132015271025\nChủ TK: VO HOANG VU',
                          textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ] 
                    // NẾU ĐÃ THANH TOÁN -> HIỆN THÔNG BÁO
                    else ...[
                      const Icon(Icons.verified, size: 80, color: Colors.green),
                      const SizedBox(height: 10),
                      const Text(
                          'Hệ thống đã ghi nhận thanh toán của bạn.\nĐơn hàng sẽ sớm được xử lý!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: Colors.grey)),
                    ]
                  ],
                ),
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPaid ? Colors.green : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12)
                    ),
                    onPressed: isPaid ? () {
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                    } : null, // Khóa nút nếu chưa thanh toán xong
                    child: Text(isPaid ? 'HOÀN TẤT' : 'ĐANG CHỜ...', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            );
          }
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    double finalTotal = widget.initialTotal - discountAmount;
    if (finalTotal < 0) finalTotal = 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('THANH TOÁN ĐƠN HÀNG'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.location_on,
                                color: Colors.redAccent, size: 20),
                            SizedBox(width: 6),
                            Text('Địa Chỉ Nhận Hàng',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: addressCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Nhập địa chỉ nhận hàng chi tiết...',
                            contentPadding: EdgeInsets.all(10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sản Phẩm Đặt Mua',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        const Divider(height: 16),
                        ...widget.checkoutItems.map((item) {
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
                                        child: const Icon(Icons.image)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(item['TenSanPham'] ?? '',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13),
                                          maxLines: 1),
                                      Text(
                                          'Phân loại: ${item['MauSac'] ?? 'Đen'} - Size ${item['KichThuoc'] ?? 'M'}',
                                          style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 11)),
                                      Text('x${item['SoLuong'] ?? 1}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight:
                                                  FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                Text(formatPrice(item['Gia']),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.redAccent)),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.confirmation_number_outlined,
                            color: Color(0xFF00E5FF)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: promoCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Mã giảm giá (Voucher)...',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFF00E5FF).withValues(alpha: 0.2),
                            foregroundColor: const Color(0xFF00E5FF),
                          ),
                          onPressed: _applyVoucher,
                          child: const Text('Áp dụng'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Phương Thức Thanh Toán',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 8),
                        RadioGroup<String>(
                          groupValue: _paymentMethod,
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _paymentMethod = val);
                            }
                          },
                          child: Column(
                            children: [
                              RadioListTile<String>(
                                contentPadding: EdgeInsets.zero,
                                activeColor: const Color(0xFF00E5FF),
                                title: const Row(
                                  children: [
                                    Icon(Icons.payments_outlined,
                                        color: Colors.green, size: 20),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Thanh toán khi nhận hàng (COD)',
                                        style: TextStyle(fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                value: 'COD',
                              ),
                              RadioListTile<String>(
                                contentPadding: EdgeInsets.zero,
                                activeColor: const Color(0xFF00E5FF),
                                title: const Row(
                                  children: [
                                    Icon(Icons.qr_code_scanner,
                                        color: Colors.blue, size: 20),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Chuyển khoản Ngân hàng (Mã QR)',
                                        style: TextStyle(fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                value: 'QR_BANK',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 90),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, -2))
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (discountAmount > 0)
                        Text('Tiết kiệm: -${formatPrice(discountAmount)}',
                            style: const TextStyle(
                                color: Colors.green,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      const Text('Tổng thanh toán:',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(formatPrice(finalTotal),
                          style: const TextStyle(
                              fontSize: 18,
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: const Color(0xFF0A192F),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isSubmitting ? null : _processCheckout,
                    child: const Text('ĐẶT HÀNG NGAY',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                  )
                ],
              ),
            ),
          ),
          if (_isSubmitting)
            Container(
                color: Colors.black45,
                child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}