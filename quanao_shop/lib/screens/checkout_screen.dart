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
  final addressCtrl = TextEditingController(text: '123 Đường Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh');
  final promoCtrl = TextEditingController();
  final freeshipCtrl = TextEditingController();

  String _paymentMethod = 'COD';
  String _shippingMethod = 'FAST';

  double productDiscount = 0;
  double shipDiscount = 0;
  String? appliedPromoCode;
  String? appliedShipCode;
  bool _isSubmitting = false;

  double get _shippingFee {
    if (_shippingMethod == 'FAST') return 30000;
    return 15000;
  }

  double get _finalTotal {
    double total = widget.initialTotal - productDiscount - shipDiscount + _shippingFee;
    return total < 0 ? 0 : total;
  }

  @override
  void dispose() {
    addressCtrl.dispose();
    promoCtrl.dispose();
    freeshipCtrl.dispose();
    super.dispose();
  }

  void _applyVoucher(String code, bool isFreeship) async {
    if (code.trim().isEmpty) return;
    String cleanCode = code.trim();
    double baseAmount = isFreeship ? _shippingFee : widget.initialTotal;
    var res = await ApiService.applyPromotion(cleanCode, baseAmount);

    if (res['status'] == 'success') {
      int loai = res['loaiGiamGia'] ?? 1;
      if (loai == 2 && !isFreeship) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mã này dành cho Vận chuyển!'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      if (loai == 1 && isFreeship) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mã này dành cho Sản phẩm!'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      setState(() {
        if (isFreeship) {
          shipDiscount = double.parse(res['discountAmount'].toString());
          appliedShipCode = cleanCode;
        } else {
          productDiscount = double.parse(res['discountAmount'].toString());
          appliedPromoCode = cleanCode;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']), backgroundColor: Colors.red),
      );
    }
  }

  void _showAvailableVouchers(bool isFreeship) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return FutureBuilder<List<dynamic>>(
          future: ApiService.getAvailablePromotions(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final promos = (snapshot.data ?? [])
                .where((p) => (p['LoaiGiamGia'] ?? 1) == (isFreeship ? 2 : 1))
                .toList();

            if (promos.isEmpty) {
              return SizedBox(
                height: 200,
                child: Center(
                  child: Text(
                    isFreeship ? 'Không có mã Freeship.' : 'Không có mã giảm giá.',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isFreeship ? 'Chọn mã Freeship' : 'Chọn mã giảm giá',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: promos.length,
                      itemBuilder: (context, index) {
                        final p = promos[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: Icon(
                              isFreeship ? Icons.local_shipping : Icons.confirmation_number,
                              color: isFreeship ? Colors.orangeAccent : null,
                            ),
                            title: Text(
                              p['MaGiamGia'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text('-${p['PhanTramGiam']}% | ${p['MoTa'] ?? ''}'),
                            trailing: TextButton(
                              child: const Text('Chọn'),
                              onPressed: () {
                                Navigator.pop(ctx);
                                if (isFreeship) {
                                  freeshipCtrl.text = p['MaGiamGia'];
                                } else {
                                  promoCtrl.text = p['MaGiamGia'];
                                }
                                _applyVoucher(p['MaGiamGia'], isFreeship);
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _processCheckout() async {
    if (addressCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập địa chỉ!')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    double finalTotal = _finalTotal;

    final List<Map<String, dynamic>> orderItems = [];
    for (var item in widget.checkoutItems) {
      final rawId = item['Id'];
      if (rawId == null) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lỗi biến thể!'), backgroundColor: Colors.red),
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

    String? codeToSend = appliedPromoCode ?? appliedShipCode;
    bool ok = await ApiService.createOrder(
      widget.currentUser['Id'],
      addressCtrl.text.trim(),
      _paymentMethod,
      finalTotal,
      promoCode: codeToSend,
      items: orderItems,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (ok) {
      _showSuccessDialog(finalTotal);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đặt hàng thất bại!'), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccessDialog(double finalTotal) {
    String addInfo = 'SMFASHION_${widget.currentUser['Id']}_${finalTotal.toInt()}';
    String qrUrl = 'https://img.vietqr.io/image/MB-1132015271025-compact2.png?amount=$finalTotal&addInfo=$addInfo&accountName=VO%20HOANG%20VU';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isPaid = _paymentMethod == 'COD';
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            if (_paymentMethod == 'QR_BANK' && !isPaid) {
              Future.delayed(const Duration(seconds: 10)).then((_) {
                if (ctx.mounted) setStateDialog(() { isPaid = true; });
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
                      color: isPaid ? Colors.green : null,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tổng tiền: ${formatPrice(finalTotal)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (!isPaid) ...[
                      const Text(
                        'Hệ thống đang chờ chuyển khoản...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 250),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(qrUrl, fit: BoxFit.contain),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Ngân hàng: MB Bank\nSTK: 1132015271025\nChủ TK: VO HOANG VU',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ] else ...[
                      const Icon(Icons.verified, size: 80, color: Colors.green),
                      const SizedBox(height: 10),
                      const Text(
                        'Hệ thống đã ghi nhận thanh toán.\nĐơn hàng sẽ sớm được xử lý!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
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
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: isPaid
                        ? () {
                            Navigator.pop(ctx);
                            Navigator.pop(context);
                          }
                        : null,
                    child: Text(
                      isPaid ? 'HOÀN TẤT' : 'ĐANG CHỜ...',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
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
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Đã xóa nền trắng cứng
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Thanh toán',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. ĐỊA CHỈ
                _buildSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.location_on, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Địa chỉ nhận hàng',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: addressCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText: 'Nhập địa chỉ...',
                          contentPadding: EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. SẢN PHẨM
                _buildSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sản phẩm đặt mua',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const Divider(height: 24),
                      ...widget.checkoutItems.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  item['HinhAnh'] ?? '',
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (a, b, c) => Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.grey[800],
                                    child: const Icon(Icons.image),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['TenSanPham'] ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Phân loại: ${item['MauSac'] ?? ''} - ${item['KichThuoc'] ?? ''}',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      'x${item['SoLuong'] ?? 1}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                formatPrice(item['Gia']),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                // 3. VOUCHER
                _buildSectionCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_offer),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: promoCtrl,
                              decoration: const InputDecoration(
                                hintText: 'Mã giảm giá sản phẩm...',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _applyVoucher(promoCtrl.text, false),
                            child: const Text('Áp dụng'),
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        children: [
                          const Icon(Icons.local_shipping),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: freeshipCtrl,
                              decoration: const InputDecoration(
                                hintText: 'Mã Freeship...',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _applyVoucher(freeshipCtrl.text, true),
                            child: const Text('Áp dụng'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          GestureDetector(
                            onTap: () => _showAvailableVouchers(false),
                            child: const Text(
                              'Xem mã Giảm giá',
                              style: TextStyle(fontSize: 12, decoration: TextDecoration.underline),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _showAvailableVouchers(true),
                            child: const Text(
                              'Xem mã Freeship',
                              style: TextStyle(fontSize: 12, decoration: TextDecoration.underline),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 4. PHƯƠNG THỨC GIAO HÀNG
                _buildSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Phương thức giao hàng',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      RadioGroup<String>(
                        groupValue: _shippingMethod,
                        onChanged: (val) {
                          if (val != null) setState(() => _shippingMethod = val);
                        },
                        child: Column(
                          children: [
                            RadioListTile<String>(
                              value: 'FAST',
                              title: const Text('Giao hàng Nhanh (2-3 ngày)'),
                              subtitle: const Text(
                                'Phí: 30.000 VNĐ',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ),
                            RadioListTile<String>(
                              value: 'SAVE',
                              title: const Text('Giao hàng Tiết kiệm (4-5 ngày)'),
                              subtitle: const Text(
                                'Phí: 15.000 VNĐ',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 5. PHƯƠNG THỨC THANH TOÁN
                _buildSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Phương thức thanh toán',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      RadioGroup<String>(
                        groupValue: _paymentMethod,
                        onChanged: (val) {
                          if (val != null) setState(() => _paymentMethod = val);
                        },
                        child: const Column(
                          children: [
                            RadioListTile<String>(
                              value: 'COD',
                              title: Text('Thanh toán khi nhận hàng (COD)'),
                            ),
                            RadioListTile<String>(
                              value: 'QR_BANK',
                              title: Text('Chuyển khoản Ngân hàng (QR)'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 90),
              ],
            ),
          ),

          // THANH TOÁN DƯỚI CÙNG
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor, // Tự đổi màu theo Theme
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (productDiscount > 0)
                        Text(
                          'Giảm giá SP: -${formatPrice(productDiscount)}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      if (shipDiscount > 0)
                        Text(
                          'Giảm Ship: -${formatPrice(shipDiscount)}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      Text(
                        'Phí vận chuyển: +${formatPrice(_shippingFee)}',
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                      const Text(
                        'Tổng thanh toán:',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        formatPrice(_finalTotal),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _isSubmitting ? null : _processCheckout,
                    child: const Text(
                      'ĐẶT HÀNG',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  )
                ],
              ),
            ),
          ),
          
          if (_isSubmitting)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}