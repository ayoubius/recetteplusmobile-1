import 'package:supabase_flutter/supabase_flutter.dart';

class DatabaseInspector {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Inspecte une table spécifique
  static Future<TableInfo> inspectTable(String tableName) async {
    try {
      // Récupérer quelques enregistrements pour analyser la structure
      final sample = await _client
          .from(tableName)
          .select('*')
          .limit(1);

      final columnCount = sample.isNotEmpty ? sample.first.keys.length : 0;
      final columns = sample.isNotEmpty ? sample.first.keys.toList() : <String>[];

      // Compter le nombre total d'enregistrements (attention: inefficace pour grandes tables)
      final allRows = await _client
          .from(tableName)
          .select('*');
      final recordCount = allRows.length;

      return TableInfo(
        name: tableName,
        exists: true,
        columnCount: columnCount,
        columns: columns,
        recordCount: recordCount,
      );
    } catch (e) {
      return TableInfo(
        name: tableName,
        exists: false,
        error: e.toString(),
      );
    }
  }

  /// Génère un rapport complet de la base de données
  static Future<DatabaseReport> generateDatabaseReport() async {
    final tables = [
      'videos', 'recipes', 'products', 'user_profiles',
      'favorites', 'user_history', 'orders', 'cart_items'
    ];

    final tableInfos = <TableInfo>[];
    
    for (final table in tables) {
      final info = await inspectTable(table);
      tableInfos.add(info);
    }

    return DatabaseReport(tables: tableInfos);
  }
}

class TableInfo {
  final String name;
  final bool exists;
  final int columnCount;
  final List<String> columns;
  final int recordCount;
  final String? error;

  TableInfo({
    required this.name,
    required this.exists,
    this.columnCount = 0,
    this.columns = const [],
    this.recordCount = 0,
    this.error,
  });

  void printInfo() {
    if (exists) {
      print('📋 Table: $name');
      print('   📊 Colonnes: $columnCount');
      print('   📈 Enregistrements: $recordCount');
      print('   🏷️ Champs: ${columns.join(', ')}');
    } else {
      print('❌ Table: $name (n\'existe pas)');
      if (error != null) print('   Erreur: $error');
    }
  }
}

class DatabaseReport {
  final List<TableInfo> tables;

  DatabaseReport({required this.tables});

  void printReport() {
    print('\n🗄️ RAPPORT D\'INSPECTION DE LA BASE DE DONNÉES');
    print('=' * 60);
    
    for (final table in tables) {
      table.printInfo();
      print('');
    }
    
    final existingTables = tables.where((t) => t.exists).length;
    final totalRecords = tables
        .where((t) => t.exists)
        .fold(0, (sum, t) => sum + t.recordCount);
    
    print('📊 RÉSUMÉ:');
    print('   Tables existantes: $existingTables/${tables.length}');
    print('   Total enregistrements: $totalRecords');
    print('=' * 60);
  }
}
