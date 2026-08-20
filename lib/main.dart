import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'providers/user_provider.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/ad_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await AdService.init();
  runApp(const EarnMoneyApp());
}

class EarnMoneyApp extends StatelessWidget {
  const EarnMoneyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        ChangeNotifierProvider<AdService>(
          create: (_) {
            final ad = AdService();
            ad.loadRewardedAd();
            ad.loadInterstitialAd();
            return ad;
          },
        ),
        ChangeNotifierProvider<UserProvider>(
          create: (ctx) => UserProvider(
            authService: ctx.read<AuthService>(),
            firestoreService: ctx.read<FirestoreService>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Earn Money',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
          useMaterial3: true,
        ),
        home: const _AuthGate(),
      ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProvider>();

    if (provider.user != null) {
      return const HomeScreen();
    }

    if (provider.firebaseUser != null && provider.user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return const LoginScreen();
  }
}
