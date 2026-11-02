import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/chat_screen.dart'; // <-- ĐÃ THÊM IMPORT CHAT SCREEN

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryTechColor = Color(0xFF00E5FF);
    const Color techBackgroundDark = Color(0xFF0B0E14);
    const Color techCardDark = Color(0xFF151922);

    return MaterialApp(
      title: 'SHAMIKIN_SHOP',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: primaryTechColor,
        scaffoldBackgroundColor: techBackgroundDark,
        cardColor: techCardDark,
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: primaryTechColor,
          secondary: Color(0xFF7C4DFF),
          surface: techCardDark,
          background: techBackgroundDark, // Lưu ý: Dart mới khuyên dùng surface thay background, nhưng giữ nguyên để không lỗi
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F131C),
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: primaryTechColor),
          titleTextStyle: TextStyle(
            color: primaryTechColor,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
            fontFamily: 'monospace',
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF0F131C),
          selectedItemColor: primaryTechColor,
          unselectedItemColor: Color(0xFF6C758D),
          type: BottomNavigationBarType.fixed,
        ),
      ),
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF00838F),
        scaffoldBackgroundColor: const Color(0xFFF4F7FA),
        cardColor: Colors.white,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A192F),
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Color(0xFF00E5FF)),
          titleTextStyle: TextStyle(
            color: Color(0xFF00E5FF),
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
            fontFamily: 'monospace',
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
selectedItemColor: Color(0xFF00838F),
          unselectedItemColor: Color(0xFF757575),
          type: BottomNavigationBarType.fixed,
        ),
      ),
      builder: (context, child) {
        bool isDark = _themeMode == ThemeMode.dark;
        return Scaffold(
          backgroundColor: const Color(0xFF05070A),
          body: Center(
            child: Container(
              width: 410,
              height: 840,
              decoration: BoxDecoration(
                color: isDark ? techBackgroundDark : const Color(0xFFF4F7FA),
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: primaryTechColor.withValues(alpha: 0.25), // Sửa theo chuẩn mới chống cảnh báo
                    blurRadius: 25,
                    spreadRadius: 2,
                  )
                ],
                border: Border.all(color: const Color(0xFF1E2638), width: 8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: child ?? const SizedBox(),
              ),
            ),
          ),
        );
      },
      home: PhoneMockupFrame(
        isDarkMode: _themeMode == ThemeMode.dark,
        onThemeChanged: _toggleTheme,
      ),
    );
  }
}

class PhoneMockupFrame extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onThemeChanged;

  const PhoneMockupFrame({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<PhoneMockupFrame> createState() => _PhoneMockupFrameState();
}

class _PhoneMockupFrameState extends State<PhoneMockupFrame> {
  int _currentIndex = 0;
  Map<String, dynamic>? currentUser;

  void _onUserChanged(Map<String, dynamic>? user) {
    setState(() {
      currentUser = user;
      // KHI ĐĂNG NHẬP THÀNH CÔNG -> TỰ ĐỘNG CHUYỂN VỀ TRANG CHỦ (INDEX = 0)
      if (user != null) {
        _currentIndex = 0;
      }
    });

    if (user != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Xin chào, ${user['HoTen'] ?? 'Thành viên'}!'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> screens = [
      HomeScreen(currentUser: currentUser, onUserChanged: _onUserChanged),
      CartScreen(key: ValueKey('cart_$_currentIndex'), currentUser: currentUser),
      ProfileScreen(
        currentUser: currentUser,
        onUserChanged: _onUserChanged,
        isDarkMode: widget.isDarkMode,
        onThemeChanged: widget.onThemeChanged,
      ),
    ];

    bool isDark = widget.isDarkMode;

    return Scaffold(
      // BỌC BODY BẰNG STACK ĐỂ CHÈN NÚT NỔI
      body: Stack(
        children: [
          screens[_currentIndex],
          
          // NÚT BONG BÓNG AI (Chỉ hiển thị khi đã đăng nhập để tư vấn chính xác)
if (currentUser != null)
            Positioned(
              bottom: 20, 
              right: 20,
              child: FloatingActionButton(
                heroTag: 'ai_chat_btn',
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                elevation: 8,
                shape: const CircleBorder(),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(currentUser: currentUser),
                    ),
                  );
                },
                child: const Icon(Icons.smart_toy, size: 28),
              ),
            ),
        ],
      ),
      
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: isDark ? const Color(0xFF0F131C) : Colors.white,
        selectedItemColor: isDark ? const Color(0xFF00E5FF) : const Color(0xFF00838F),
        unselectedItemColor: isDark ? const Color(0xFF6C758D) : Colors.grey.shade600,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.hub_outlined), activeIcon: Icon(Icons.hub), label: 'Trang chủ'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart_outlined), activeIcon: Icon(Icons.shopping_cart), label: 'Giỏ hàng'),
          BottomNavigationBarItem(icon: Icon(Icons.fingerprint), activeIcon: Icon(Icons.fingerprint), label: 'Tài khoản'),
        ],
      ),
    );
  }
}