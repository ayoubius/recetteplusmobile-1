import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:recette_plus/features/videos/presentation/pages/videos_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'features/auth/presentation/pages/welcome_page.dart';
import 'features/recipes/presentation/pages/recipes_page.dart';
import 'features/products/presentation/pages/products_page.dart';
import 'features/profile/presentation/pages/profile_page.dart';
import 'features/cart/presentation/pages/cart_page.dart';
import 'core/constants/app_colors.dart';
import 'core/services/theme_service.dart';
import 'core/services/video_lifecycle_manager.dart';
import 'core/services/enhanced_simple_video_manager.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/enhanced_video_service.dart';
import 'shared/widgets/connectivity_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (kDebugMode) {
      debugPrint('🚀 Démarrage de l\'application...');
    }

    // Initialize video lifecycle manager
    VideoLifecycleManager().initialize();

    // Configure enhanced video manager
    EnhancedSimpleVideoManager().configure(
      autoResumeOnPageReturn: true,
      autoPlayOnAppStart: true,
      preloadDistance: const Duration(seconds: 3),
    );

    // Initialize enhanced video service
    EnhancedVideoService.initializeAdaptiveQuality();

    // Load environment variables
    String? envContent;
    try {
      envContent = await rootBundle.loadString('.env');
      if (kDebugMode) {
        debugPrint('📄 Fichier .env chargé avec succès');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️  Impossible de charger le fichier .env: $e');
      }
    }

    // Parse environment variables
    String supabaseUrl = 'https://your-project.supabase.co';
    String supabaseAnonKey = 'your-anon-key';

    if (envContent != null) {
      final lines = envContent.split('\n');
      for (final line in lines) {
        if (line.trim().isEmpty || line.startsWith('#')) continue;

        final parts = line.split('=');
        if (parts.length >= 2) {
          final key = parts[0].trim();
          final value = parts.sublist(1).join('=').trim();

          if (key == 'SUPABASE_URL') {
            supabaseUrl = value;
          } else if (key == 'SUPABASE_ANON_KEY') {
            supabaseAnonKey = value;
          }
        }
      }
    }

    if (kDebugMode) {
      debugPrint('🔧 Configuration Supabase...');
      debugPrint('📍 URL: $supabaseUrl');
      debugPrint(
          '🔑 Anon Key: ${supabaseAnonKey.length > 20 ? '${supabaseAnonKey.substring(0, 20)}...' : 'Non définie'}');
    }

    // Initialize Supabase
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: true,
    );

    if (kDebugMode) {
      debugPrint('✅ Supabase initialisé avec succès');
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('❌ Erreur d\'initialisation Supabase: $e');
    }
  }

  runApp(const RecettePlusApp());
}

class RecettePlusApp extends StatelessWidget {
  const RecettePlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => ThemeService()..loadTheme(),
        ),
        ChangeNotifierProvider(
          create: (context) => ConnectivityService()..initialize(),
        ),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return MaterialApp(
            title: 'Recette +',
            themeMode: themeService.themeMode,
            theme: _buildLightTheme(),
            darkTheme: _buildDarkTheme(),
            home: const AuthWrapper(),
            routes: {
              '/products': (context) =>
                  const MainNavigationPage(initialIndex: 1),
              '/welcome': (context) => const WelcomePage(),
              '/main': (context) => const MainNavigationPage(),
              '/cart': (context) => const MainNavigationPage(initialIndex: 3),
            },
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        background: AppColors.surface,
        error: AppColors.error,
      ),
      fontFamily: 'SFProDisplay',
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardBackground,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surfaceDark,
        background: AppColors.surface,
        error: AppColors.error,
      ),
      fontFamily: 'SFProDisplay',
      scaffoldBackgroundColor: AppColors.backgroundDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimaryDark),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimaryDark,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardBackgroundDark,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _checkInitialization();
  }

  Future<void> _checkInitialization() async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️  Erreur de connexion Supabase: $e');
      }
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(isDark),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: AppColors.primary.withOpacity(0.1),
                ),
                child: const Icon(
                  Icons.restaurant_menu,
                  size: 60,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
              const SizedBox(height: 16),
              Text(
                'Initialisation...',
                style: TextStyle(
                  color: AppColors.getTextSecondary(isDark),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ConnectivityWrapper(
      blockAppWhenOffline: true,
      child: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            if (kDebugMode) {
              debugPrint('❌ Erreur AuthState: ${snapshot.error}');
            }
            return Scaffold(
              backgroundColor: AppColors.getBackground(isDark),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 80,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Erreur de connexion',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getTextPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vérifiez votre connexion internet',
                      style: TextStyle(
                        color: AppColors.getTextSecondary(isDark),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isInitialized = false;
                        });
                        _checkInitialization();
                      },
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              backgroundColor: AppColors.getBackground(isDark),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Vérification de l\'authentification...',
                      style: TextStyle(
                        color: AppColors.getTextSecondary(isDark),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final session = snapshot.hasData ? snapshot.data!.session : null;
          final isAuthenticated = session != null;

          if (kDebugMode) {
            debugPrint(
                '🔐 État d\'authentification: ${isAuthenticated ? 'Connecté' : 'Déconnecté'}');
            if (isAuthenticated) {
              debugPrint('👤 Utilisateur: ${session.user.email}');
            }
          }

          if (isAuthenticated) {
            Future.microtask(() {
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/main', (route) => false);
            });

            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            );
          } else {
            return const WelcomePage();
          }
        },
      ),
    );
  }
}

class MainNavigationPage extends StatefulWidget {
  final int initialIndex;

  const MainNavigationPage({
    super.key,
    this.initialIndex = 2, // Start with videos page by default
  });

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  late int _selectedIndex;
  late List<Widget> _pages;
  final VideoLifecycleManager _lifecycleManager = VideoLifecycleManager();
  final EnhancedSimpleVideoManager _videoManager = EnhancedSimpleVideoManager();

  final List<String> _pageNames = [
    'recipes',
    'products',
    'videos',
    'cart',
    'profile',
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;

    _pages = [
      const RecipesPage(),
      const ProductsPage(),
      const VideosPage(), // Use enhanced TikTok-style video page
      const CartPage(),
      const ProfilePage(),
    ];

    _videoManager.setCurrentPage(_pageNames[_selectedIndex]);

    if (_selectedIndex == 2) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          _videoManager.forceResumePlayback();
          if (kDebugMode) {
            print('🚀 Auto-start videos on app launch');
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _lifecycleManager.dispose();
    _videoManager.disposeAll();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

    final previousPageName = _pageNames[_selectedIndex];
    final newPageName = _pageNames[index];

    _videoManager.pauseAll();
    _lifecycleManager.onPageChanged(previousPageName, newPageName);
    _videoManager.setCurrentPage(newPageName);

    setState(() {
      _selectedIndex = index;
    });

    if (index == 2) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          _videoManager.forceResumePlayback();
          if (kDebugMode) {
            print('🔄 Return to videos page - Auto resume');
          }
        }
      });
    }

    if (kDebugMode) {
      print('🔄 Navigation: $previousPageName -> $newPageName');
      print('⏸️ FORCED PAUSE of all videos');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: _selectedIndex == 2
            ? Brightness.light
            : (isDark ? Brightness.light : Brightness.dark),
        statusBarBrightness: _selectedIndex == 2
            ? Brightness.dark
            : (isDark ? Brightness.dark : Brightness.light),
        systemNavigationBarColor: AppColors.getSurface(isDark),
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
    );

    return WillPopScope(
      onWillPop: () async {
        _videoManager.pauseAll();
        _lifecycleManager.pauseAllVideos();
        if (kDebugMode) {
          print('🚪 App exit - FORCED PAUSE of all videos');
        }
        return true;
      },
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: AppColors.getSurface(isDark),
            boxShadow: [
              BoxShadow(
                color: AppColors.getShadow(isDark),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.restaurant_menu_rounded),
                activeIcon: Icon(Icons.restaurant_menu),
                label: 'Recettes',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.shopping_bag_rounded),
                activeIcon: Icon(Icons.shopping_bag),
                label: 'Produits',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.video_library_rounded),
                activeIcon: Icon(Icons.video_library),
                label: 'Vidéos',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.shopping_cart_rounded),
                activeIcon: Icon(Icons.shopping_cart),
                label: 'Panier',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded),
                activeIcon: Icon(Icons.person),
                label: 'Profil',
              ),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.getTextSecondary(isDark),
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: 12,
            ),
            onTap: _onItemTapped,
          ),
        ),
      ),
    );
  }
}
