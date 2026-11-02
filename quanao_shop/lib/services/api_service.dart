import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api';
    } else {
      return 'http://localhost:3000/api';
    }
  }
  // Lấy tin nhắn chat
  static Future<List<dynamic>> getChatMessages(int userId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/chat/$userId'));
      if (res.statusCode == 200) return jsonDecode(res.body);
      return [];
    } catch (e) { return []; }
  }

  // Gửi tin nhắn
  static Future<bool> sendChatMessage(int userId, String sender, String message) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId, 'sender': sender, 'message': message}),
      );
      return res.statusCode == 200;
    } catch (e) { return false; }
  }
  // Khách yêu cầu hoàn đơn
  static Future<Map<String, dynamic>> requestReturn(int orderId, int userId, String reason) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/orders/$orderId/return'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId, 'reason': reason}),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Lỗi kết nối Server!'};
    }
  }

  // Admin duyệt hoàn đơn
  static Future<Map<String, dynamic>> approveReturn(int adminId, int orderId, bool isApproved) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/admin/orders/$orderId/approve-return'),
        headers: {
          'Content-Type': 'application/json',
          'admin-id': adminId.toString(),
        },
        body: jsonEncode({'isApproved': isApproved}),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Lỗi kết nối Server!'};
    }
  }
  // Khóa / Mở khóa tài khoản khách hàng
  static Future<Map<String, dynamic>> toggleCustomerStatus(int adminId, int customerId) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/admin/customers/$customerId/toggle-status'),
        headers: {'admin-id': adminId.toString()},
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Lỗi kết nối Server!'};
    }
    
  }
  

  // =========================================================================
  // 10. ĐÁNH GIÁ SẢN PHẨM
  // =========================================================================
  static Future<List<dynamic>> getProductReviews(int productId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/reviews/$productId'));
      if (res.statusCode == 200) return jsonDecode(res.body);
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<dynamic>> getUserReviews(int userId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/reviews/user/$userId'));
      if (res.statusCode == 200) return jsonDecode(res.body);
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> addReview(int userId, int productId, int soSao, String binhLuan) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/reviews'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'productId': productId,
          'soSao': soSao,
          'binhLuan': binhLuan,
        }),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Lỗi kết nối Server!'};
    }
  }
// =========================================================================
  // 9. LẤY DANH SÁCH TỒN KHO
  // =========================================================================
  static Future<List<dynamic>> getAdminInventory(int adminId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/admin/inventory'),
        headers: {'admin-id': adminId.toString()},
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
      return [];
    } catch (e) {
      return [];
    }
  }

  // =========================================================================
  // 8. THỐNG KÊ (ADMIN)
  // =========================================================================
  static Future<Map<String, dynamic>> getAdminStatistics(int adminId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/admin/statistics'),
        headers: {'admin-id': adminId.toString()},
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
      return {'status': 'error', 'message': 'Lỗi server ${res.statusCode}'};
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  // =========================================================================
  // 1. TÀI KHOẢN
  // =========================================================================
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Lỗi kết nối Server!'};
    }
  }

  static Future<Map<String, dynamic>> register(String fullName, String email, String password, String phone) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fullName': fullName,
          'email': email,
          'password': password,
          'phone': phone,
        }),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Lỗi kết nối Server!'};
    }
  }

  // =========================================================================
  // 2. SẢN PHẨM & DANH MỤC
  // =========================================================================
  static Future<List<dynamic>> getCategories() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/categories'));
      if (res.statusCode == 200) return jsonDecode(res.body);
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<dynamic>> getProducts({String query = '', int? categoryId}) async {
    try {
      String url = '$baseUrl/products?query=$query';
      if (categoryId != null) url += '&categoryId=$categoryId';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) return jsonDecode(res.body);
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> getProductDetail(int id) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/products/$id'));
      if (res.statusCode == 200) return jsonDecode(res.body);
      return {};
    } catch (e) {
      return {};
    }
  }

  // =========================================================================
  // 3. GIỎ HÀNG
  // =========================================================================
  static Future<List<dynamic>> getCart(int userId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/cart/$userId'));
      if (res.statusCode == 200) return jsonDecode(res.body);
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> addToCart(
      int userId, int variantId, int quantity) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/cart'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'variantId': variantId,
          'quantity': quantity,
        }),
      );
      debugPrint('=== addToCart ===');
      debugPrint('Gửi: userId=$userId, variantId=$variantId, quantity=$quantity');
      debugPrint('Nhận: ${res.statusCode} - ${res.body}');

      if (res.statusCode == 200) {
        return {'success': true, 'message': 'Đã thêm vào giỏ hàng!'};
      }
      try {
        final data = jsonDecode(res.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Lỗi server ${res.statusCode}'
        };
      } catch (_) {
        return {'success': false, 'message': 'Server trả về ${res.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  static Future<bool> updateCartQuantity(int cartId, int quantity) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/cart/$cartId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'quantity': quantity}),
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteCartItem(int cartId) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/cart/$cartId'));
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // =========================================================================
  // 4. YÊU THÍCH
  // =========================================================================
  static Future<List<dynamic>> getFavorites(int userId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/favorites/$userId'));
      if (res.statusCode == 200) return jsonDecode(res.body);
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> toggleFavorite(int userId, int productId) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/favorites/toggle'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId, 'productId': productId}),
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // =========================================================================
  // 5. KHUYẾN MÃI
  // =========================================================================
  static Future<List<dynamic>> getAdminPromotions(int adminId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/admin/promotions'),
        headers: {'admin-id': adminId.toString()},
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> addPromotion(int adminId, String code, int percent, int limit, String description) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/admin/promotions'),
        headers: {
          'Content-Type': 'application/json',
          'admin-id': adminId.toString(),
        },
        body: jsonEncode({
          'code': code,
          'percent': percent,
          'limit': limit,
          'description': description,
        }),
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> applyPromotion(String code, double totalAmount) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/promotions/apply'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': code, 'totalAmount': totalAmount}),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Lỗi kết nối Server!'};
    }
  }

  // =========================================================================
  // 6. ĐƠN HÀNG
  // =========================================================================
  static Future<List<dynamic>> getUserOrders(int userId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/orders/user/$userId'));
      if (res.statusCode == 200) return jsonDecode(res.body);
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> createOrder(int userId, String address, String paymentMethod, double totalAmount,
      {String? promoCode, List<dynamic>? items}) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/orders'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'address': address,
          'paymentMethod': paymentMethod,
          'totalAmount': totalAmount,
          'promoCode': promoCode,
          'items': items ?? [],
        }),
      );
      debugPrint('createOrder response: ${res.statusCode} - ${res.body}');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('createOrder error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> cancelOrder(int orderId, int userId) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/orders/$orderId/cancel'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId}),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Lỗi kết nối Server!'};
    }
  }

  // =========================================================================
  // 7. ADMIN
  // =========================================================================
  static Future<List<dynamic>> getAdminOrders(int adminId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/admin/orders'),
        headers: {'admin-id': adminId.toString()},
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> updateOrderStatus(int adminId, int orderId, String status) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/admin/orders/$orderId/status'),
        headers: {
          'Content-Type': 'application/json',
          'admin-id': adminId.toString(),
        },
        body: jsonEncode({'status': status}),
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<List<dynamic>> getAdminCustomers(int adminId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/admin/customers'),
        headers: {'admin-id': adminId.toString()},
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
      return [];
    } catch (e) {
      return [];
    }
  }

  // THÊM MỚI: Xóa khách hàng
  static Future<bool> deleteCustomer(int adminId, int customerId) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/admin/customers/$customerId'),
        headers: {'admin-id': adminId.toString()},
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> addProduct(int adminId, String name, int categoryId, double price, String image, String description) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/admin/products'),
        headers: {
          'Content-Type': 'application/json',
          'admin-id': adminId.toString(),
        },
        body: jsonEncode({
          'name': name,
          'categoryId': categoryId,
          'price': price,
          'image': image,
          'description': description,
        }),
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteProduct(int adminId, int productId) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/admin/products/$productId'),
        headers: {'admin-id': adminId.toString()},
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> importInventory(int adminId, int sanPhamId, String mauSac, String kichThuoc, int soLuongNhap) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/admin/inventory/import'),
        headers: {
          'Content-Type': 'application/json',
          'admin-id': adminId.toString(),
        },
        body: jsonEncode({
          'sanPhamId': sanPhamId,
          'mauSac': mauSac,
          'kichThuoc': kichThuoc,
          'soLuongNhap': soLuongNhap,
        }),
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}