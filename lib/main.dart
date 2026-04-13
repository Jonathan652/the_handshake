import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/transactions/transaction_list_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/disputes/disputes_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const HandshakeApp());
}

class HandshakeApp extends StatelessWidget {
  const HandshakeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Handshake',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF064E3B),
        ),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF534AB7),
              body: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            );
          }
          if (snapshot.hasData) {
            return const MainShell();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  List<Widget> _screensForRole(bool isArbiter) {
    if (isArbiter) {
      return const [
        HomeScreen(),
        TransactionListScreen(),
        DisputesScreen(),
        ProfileScreen(),
      ];
    }
    return const [
      HomeScreen(),
      TransactionListScreen(),
      ProfileScreen(),
    ];
  }

  List<BottomNavigationBarItem> _itemsForRole(bool isArbiter) {
    if (isArbiter) {
      return const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long_outlined),
          activeIcon: Icon(Icons.receipt_long),
          label: 'Transactions',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.gavel_outlined),
          activeIcon: Icon(Icons.gavel),
          label: 'Disputes',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ];
    }

    return const [
      BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        activeIcon: Icon(Icons.home),
        label: 'Home',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.receipt_long_outlined),
        activeIcon: Icon(Icons.receipt_long),
        label: 'Transactions',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        activeIcon: Icon(Icons.person),
        label: 'Profile',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const LoginScreen();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final role =
            snapshot.data?.data()?['role']?.toString().toLowerCase() ?? 'user';
        final isArbiter = role == 'arbiter';
        final screens = _screensForRole(isArbiter);
        final items = _itemsForRole(isArbiter);
        final safeIndex = _currentIndex >= screens.length
            ? screens.length - 1
            : _currentIndex;

        if (safeIndex != _currentIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _currentIndex = safeIndex);
            }
          });
        }

        return Scaffold(
          body: IndexedStack(
            index: safeIndex,
            children: screens,
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: safeIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            selectedItemColor: const Color(0xFF064E3B),
            unselectedItemColor: const Color(0xFF888780),
            backgroundColor: Colors.white,
            elevation: 8,
            type: BottomNavigationBarType.fixed,
            items: items,
          ),
        );
      },
    );
  }
}
