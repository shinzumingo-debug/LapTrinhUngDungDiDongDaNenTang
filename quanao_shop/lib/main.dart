import 'package:flutter/material.dart';
import 'dart:ui';
import 'screens/home_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/chat_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color navyPrimary = Color(0xFF1E293B);
    const Color pastelBg = Color(0xFFF4F7FB);

    return MaterialApp(
      title: 'SM Fashion',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.trackpad,
        },
      ),
      themeMode: _themeMode,
      
      // GIAO DIỆN SÁNG
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: navyPrimary,
        scaffoldBackgroundColor: pastelBg,
        cardColor: Colors.white,
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: navyPrimary,
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: navyPrimary),
          titleTextStyle: TextStyle(
            color: navyPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: navyPrimary,
          unselectedItemColor: Color(0xFF94A3B8),
          type: BottomNavigationBarType.fixed,
          elevation: 10,
        ),
      ),

      // GIAO DIỆN TỐI
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF00E5FF),
        scaffoldBackgroundColor: const Color(0xFF080B11),
        cardColor: const Color(0xFF141A24),
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          surface: Color(0xFF141A24),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF00E5FF)),
          titleTextStyle: TextStyle(
            color: Color(0xFF00E5FF),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF0F131C),
          selectedItemColor: Color(0xFF00E5FF),
          unselectedItemColor: Color(0xFF6C758D),
          type: BottomNavigationBarType.fixed,
          elevation: 10,
        ),
      ),
      
      builder: (context, child) {
        // KHUNG ĐIỆN THOẠI BÊN NGOÀI LUÔN CỐ ĐỊNH MÀU SÁNG
        return Scaffold(
          backgroundColor: const Color(0xFFE2E8F0),
          body: Center(
            child: Container(
              width: 410,
              height: 840,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7FB),
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.1),
                    blurRadius: 30,
                    spreadRadius: 5,
                  )
                ],
                border: Border.all(
                  color: const Color(0xFFCBD5E1),
                  width: 8,
                ),
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
      HomeScreen(
        currentUser: currentUser,
        onUserChanged: _onUserChanged,
      ),
      CartScreen(
        key: ValueKey('cart_$_currentIndex'),
        currentUser: currentUser,
      ),
      ProfileScreen(
        currentUser: currentUser,
        onUserChanged: _onUserChanged,
        isDarkMode: widget.isDarkMode,
        onThemeChanged: widget.onThemeChanged,
      ),
    ];

    bool isDark = widget.isDarkMode;

    return Scaffold(
      body: Stack(
        children: [
          screens[_currentIndex < screens.length ? _currentIndex : 0],
          
          if (currentUser != null)
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton(
                heroTag: 'ai_chat_btn',
                backgroundColor: isDark ? const Color(0xFF00E5FF) : const Color(0xFF1E293B),
                foregroundColor: isDark ? Colors.black : Colors.white,
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
        selectedItemColor: isDark ? const Color(0xFF00E5FF) : const Color(0xFF1E293B),
        unselectedItemColor: isDark ? const Color(0xFF6C758D) : const Color(0xFF94A3B8),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag_outlined),
            activeIcon: Icon(Icons.shopping_bag),
            label: 'Giỏ hàng',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }
}