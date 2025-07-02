import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class DatabaseSchemaValidator {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Valide que toutes les tables requises existent
  static Future<Map<String, bool>> validateSchema() async {
    final results = <String, bool>{};
    
    final requiredTables = [
      'videos',
      'recipes', 
      'products',
      'user_profiles',
      'favorites',
      'user_history',
      'orders',
      'cart_items',
      'recipe_carts',
    ];

    for (final table in requiredTables) {
      try {
        await _client.from(table).select('*').limit(1);
        results[table] = true;
        print('✅ Table $table existe');
      } catch (e) {
        results[table] = false;
        print('❌ Table $table manquante: $e');
      }
    }

    return results;
  }

  /// Valide les fonctions de base de données
  static Future<Map<String, bool>> validateFunctions() async {
    final results = <String, bool>{};
    
    final requiredFunctions = [
      'increment_video_views',
      'increment_video_likes', 
      'increment_recipe_views',
    ];

    for (final function in requiredFunctions) {
      try {
        // Test avec un UUID factice pour vérifier l'existence
        await _client.rpc(function, params: {
          'video_id': '00000000-0000-0000-0000-000000000000'
        });
        results[function] = true;
        print('✅ Fonction $function existe');
      } catch (e) {
        if (e.toString().contains('does not exist')) {
          results[function] = false;
          print('❌ Fonction $function manquante');
        } else {
          results[function] = true; // Fonction existe mais erreur d'exécution normale
          print('✅ Fonction $function existe (erreur d\'exécution attendue)');
        }
      }
    }

    return results;
  }

  /// Rapport complet de validation
  static Future<DatabaseValidationReport> generateReport() async {
    final tables = await validateSchema();
    final functions = await validateFunctions();
    
    return DatabaseValidationReport(
      tables: tables,
      functions: functions,
      isValid: !tables.containsValue(false) && !functions.containsValue(false),
    );
  }
}

class DatabaseValidationReport {
  final Map<String, bool> tables;
  final Map<String, bool> functions;
  final bool isValid;

  DatabaseValidationReport({
    required this.tables,
    required this.functions,
    required this.isValid,
  });

  void printReport() {
    print('\n📊 RAPPORT DE VALIDATION DE LA BASE DE DONNÉES');
    print('=' * 50);
    
    print('\n📋 TABLES:');
    tables.forEach((table, exists) {
      print('  ${exists ? '✅' : '❌'} $table');
    });
    
    print('\n⚙️ FONCTIONS:');
    functions.forEach((function, exists) {
      print('  ${exists ? '✅' : '❌'} $function');
    });
    
    print('\n🎯 STATUT GLOBAL: ${isValid ? '✅ VALIDE' : '❌ PROBLÈMES DÉTECTÉS'}');
    print('=' * 50);
  }
}
