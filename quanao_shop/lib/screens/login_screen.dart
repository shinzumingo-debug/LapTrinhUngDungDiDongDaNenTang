import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  final Function(Map<String, dynamic>?) onUserChanged;

  const LoginScreen({super.key, required this.onUserChanged});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLoginMode = true;
  bool isLoading = false;

  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();

  @override
  void dispose() {
    emailCtrl.dispose();
    passwordCtrl.dispose();
    nameCtrl.dispose();
    phoneCtrl.dispose();
    super.dispose();
  }

  // Hàm tạo InputDecoration tự động đổi màu theo Theme
  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Theme.of(context).dividerColor,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Theme.of(context).dividerColor,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFF1E293B),
          width: 1.5,
        ),
      ),
      fillColor: Theme.of(context).cardColor,
      filled: true,
    );
  }

  void _submit() async {
    final email = emailCtrl.text.trim();
    final password = passwordCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng điền email và mật khẩu!')),
      );
      return;
    }

    if (!isLoginMode && nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng điền họ và tên!')),
      );
      return;
    }

    setState(() => isLoading = true);

    if (isLoginMode) {
      var res = await ApiService.login(email, password);
      setState(() => isLoading = false);

      if (res['status'] == 'success' && res['user'] != null) {
        final user = Map<String, dynamic>.from(res['user']);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('userId', user['Id']);
        await prefs.setString('userName', user['HoTen'] ?? '');
        await prefs.setString('userEmail', user['Email'] ?? '');
        await prefs.setString('userRole', user['VaiTro'] ?? 'KhachHang');

        widget.onUserChanged(user);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Xin chào, ${user['HoTen']}!'), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Đăng nhập thất bại!'), backgroundColor: Colors.red),
          );
        }
      }
    } else {
      var res = await ApiService.requestRegisterOTP(
        nameCtrl.text.trim(),
        email,
        password,
        phoneCtrl.text.trim(),
      );
      setState(() => isLoading = false);

      if (res['status'] == 'success' && mounted) {
        _showRegisterOTPDialog(email); 
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Đăng ký thất bại!'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showRegisterOTPDialog(String email) {
    final otpCtrl = TextEditingController();
    bool isVerifying = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Xác thực đăng ký', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Mã OTP đã được gửi đến Gmail của bạn.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: otpCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _buildInputDecoration('Mã OTP (6 số)', Icons.password),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white),
                  onPressed: isVerifying ? null : () async {
                    if (otpCtrl.text.trim().isEmpty) return;
                    setStateDialog(() => isVerifying = true);
                    var res = await ApiService.verifyRegisterOTP(email, otpCtrl.text.trim());
                    setStateDialog(() => isVerifying = false);

                    if (res['status'] == 'success' && mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']), backgroundColor: Colors.green));
                      setState(() { isLoginMode = true; }); 
                    } else if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Lỗi!'), backgroundColor: Colors.red));
                    }
                  },
                  child: isVerifying ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('XÁC NHẬN'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController();
    final otpCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    
    bool isSendingOTP = false;
    bool isOTPSent = false; 
    bool isResetting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(isOTPSent ? 'Nhập mã OTP' : 'Quên mật khẩu', style: const TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isOTPSent) ...[
                    const Text('Nhập Email đăng ký để nhận mã xác nhận.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _buildInputDecoration('Email đăng ký', Icons.email),
                    ),
                  ] else ...[
                    const Text('Vui lòng kiểm tra Gmail của bạn để lấy mã OTP.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: otpCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _buildInputDecoration('Mã OTP (6 số)', Icons.password),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPassCtrl,
                      obscureText: true,
                      decoration: _buildInputDecoration('Mật khẩu mới', Icons.lock_reset),
                    ),
                  ]
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white),
                  onPressed: (isSendingOTP || isResetting) ? null : () async {
                    if (!isOTPSent) {
                      if (emailCtrl.text.trim().isEmpty) return;
                      setStateDialog(() => isSendingOTP = true);
                      var res = await ApiService.requestForgotPasswordOTP(emailCtrl.text.trim());
                      setStateDialog(() => isSendingOTP = false);

                      if (res['status'] == 'success' && mounted) {
                        setStateDialog(() => isOTPSent = true); 
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']), backgroundColor: Colors.green));
                      } else if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Lỗi!'), backgroundColor: Colors.red));
                      }
                    } else {
                      if (otpCtrl.text.trim().isEmpty || newPassCtrl.text.trim().isEmpty) return;
                      setStateDialog(() => isResetting = true);
                      var res = await ApiService.resetPasswordWithOTP(emailCtrl.text.trim(), otpCtrl.text.trim(), newPassCtrl.text.trim());
                      setStateDialog(() => isResetting = false);

                      if (res['status'] == 'success' && mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']), backgroundColor: Colors.green));
                      } else if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Lỗi!'), backgroundColor: Colors.red));
                      }
                    }
                  },
                  child: (isSendingOTP || isResetting) ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(isOTPSent ? 'XÁC NHẬN' : 'GỬI MÃ OTP'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // ================= ĐÃ ĐỔI SANG LOGO VÀ TÊN =================
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/logo2.jpg',
                    width: 45,
                    height: 45,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 45,
                        height: 45,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00E5FF), Color(0xFF0055FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'SV',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'SHAVIK SHOP',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    fontSize: 22,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Thời trang trong tầm tay ♡',
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 40),
            // =========================================================

            if (!isLoginMode) ...[
              TextField(
                controller: nameCtrl,
                decoration: _buildInputDecoration('Họ và tên', Icons.person_outline),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: _buildInputDecoration('Số điện thoại', Icons.phone_outlined),
              ),
              const SizedBox(height: 16),
            ],

            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: _buildInputDecoration('Email', Icons.email_outlined),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: passwordCtrl,
              obscureText: true,
              decoration: _buildInputDecoration('Mật khẩu', Icons.lock_outline),
            ),
            
            if (isLoginMode)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _showForgotPasswordDialog,
                  child: const Text('Quên mật khẩu?', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                ),
              ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: isLoading ? null : _submit,
                child: isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(isLoginMode ? 'Đăng nhập' : 'Đăng ký', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),

            TextButton(
              onPressed: () {
                setState(() {
                  isLoginMode = !isLoginMode;
                  emailCtrl.clear();
                  passwordCtrl.clear();
                  nameCtrl.clear();
                  phoneCtrl.clear();
                });
              },
              child: Text(
                isLoginMode ? 'Chưa có tài khoản? Đăng ký' : 'Đã có tài khoản? Đăng nhập',
                style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}