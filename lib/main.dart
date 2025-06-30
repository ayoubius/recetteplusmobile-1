import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'features/auth/presentation/pages/welcome_page.dart';
import 'features/recipes/presentation/pages/recipes_page.dart';
import 'features/products/presentation/pages/products_page.dart';
import 'features/profile/presentation/pages/profile_page.dart';
import 'features/cart/presentation/pages/cart_page.dart';
import 'features/videos/presentation/pages/videos_page.dart';
import 'core/constants/app_colors.dart';
import 'core/services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (kDebugMode) {
      debugPrint('🚀 Démarrage de l\'application...');
    }

    // Charger les variables d'environnement depuis le fichier .env
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

    // Parser les variables d'environnement
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

    // Vérifier si les variables sont correctement définies
    if (supabaseUrl == 'https://your-project.supabase.co' ||
        supabaseAnonKey == 'your-anon-key') {
      if (kDebugMode) {
        debugPrint('⚠️  Variables d\'environnement par défaut détectées');
        debugPrint('💡 Vérifiez votre fichier .env');
      }
    }

    // Initialiser Supabase avec gestion d'erreur
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
    // Continuer même en cas d'erreur pour permettre le debug
  }

  runApp(const RecettePlusApp());
}

class RecettePlusApp extends StatelessWidget {
  const RecettePlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ThemeService()..loadTheme(),
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
          statusBarIconBrightness:
              Brightness.light, // Icônes claires en mode sombre
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
      // Attendre un peu pour s'assurer que Supabase est initialisé
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️  Erreur de connexion Supabase: $e');
      }
      setState(() {
        _isInitialized = true; // Continuer même avec erreur
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
              // Logo de l'application
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

    // Écouter les changements d'authentification avec gestion d'erreur améliorée
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Gestion des erreurs de connexion
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
                  Icon(
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

        // Vérifier l'état d'authentification
        final session = snapshot.hasData ? snapshot.data!.session : null;
        final isAuthenticated = session != null;

        if (kDebugMode) {
          debugPrint(
              '🔐 État d\'authentification: ${isAuthenticated ? 'Connecté' : 'Déconnecté'}');
          if (isAuthenticated) {
            debugPrint('👤 Utilisateur: ${session.user.email}');
          }
        }

        // Navigation basée sur l'état d'authentification
        if (isAuthenticated) {
          // Utilisateur connecté -> Aller à l'application principale
          // Utiliser Future.microtask pour éviter les problèmes de navigation pendant le build
          Future.microtask(() {
            Navigator.of(context)
                .pushNamedAndRemoveUntil('/main', (route) => false);
          });

          // Retourner un écran de chargement pendant la navigation
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          );
        } else {
          // Utilisateur non connecté -> Aller à la page de bienvenue
          return const WelcomePage();
        }
      },
    );
  }
}

class MainNavigationPage extends StatefulWidget {
  final int initialIndex;

  const MainNavigationPage({
    super.key,
    this.initialIndex = 2, // Commencer par la page vidéos (index 2) par défaut
  });

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  late int _selectedIndex;

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;

    // Initialiser les pages
    _pages = [
      const RecipesPage(),
      const ProductsPage(),
      const VideosPage(),
      const CartPage(),
      const ProfilePage(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Mettre à jour la barre de statut selon le thème
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

    return Scaffold(
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
    );
  }
}
