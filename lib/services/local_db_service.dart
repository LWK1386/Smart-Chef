import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/meal_model.dart';
import '../models/nutrition_model.dart';

class LocalDbService {
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'smart_chef_planner.db');

    return await openDatabase(
      path,
      version: 5, // Incremented version to trigger onUpgrade for the new table
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS meals(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            type TEXT,
            kcal INTEGER,
            imageUrl TEXT,
            ingredients TEXT,
            steps TEXT,
            date TEXT,
            isSocialPost INTEGER DEFAULT 0 
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS grocery_items(
            name TEXT PRIMARY KEY,
            price REAL,
            category TEXT DEFAULT 'General'
          )
        ''');

        // NEW: Profile table for Hybrid Data Management
        await db.execute('''
          CREATE TABLE IF NOT EXISTS user_profile(
            id TEXT PRIMARY KEY,
            username TEXT,
            avatar_url TEXT,
            last_synced TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS cached_posts(
            id TEXT PRIMARY KEY,
            user_id TEXT,
            title TEXT,
            content TEXT,
            image_url TEXT,
            author_name TEXT,
            author_avatar TEXT,
            created_at TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS cached_liked_posts(
            id TEXT PRIMARY KEY,
            user_id TEXT,
            title TEXT,
            content TEXT,
            image_url TEXT,
            author_name TEXT,
            author_avatar TEXT,
            created_at TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS favorite_recipes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT UNIQUE,
            ingredients TEXT,
            steps TEXT,
            image TEXT,
            kcal TEXT,
            duration TEXT
          )
          ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS nutrition_logs_cache (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            meal_type TEXT NOT NULL,
            food_name TEXT NOT NULL,
            calories REAL NOT NULL,
            protein REAL NOT NULL,
            carbs REAL NOT NULL,
            fat REAL NOT NULL,
            serving_size REAL NOT NULL,
            barcode TEXT,
            image_path TEXT,
            image_url TEXT,
            logged_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS pedometer_baseline (
            date TEXT PRIMARY KEY,
            baseline INTEGER NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS cached_user_goals (
            user_id TEXT PRIMARY KEY,
            calorie_goal INTEGER NOT NULL DEFAULT 2000,
            protein_goal INTEGER NOT NULL DEFAULT 150,
            carbs_goal INTEGER NOT NULL DEFAULT 250,
            fat_goal INTEGER NOT NULL DEFAULT 65,
            water_goal INTEGER NOT NULL DEFAULT 8,
            step_goal INTEGER NOT NULL DEFAULT 10000,
            is_vegetarian INTEGER NOT NULL DEFAULT 0,
            is_vegan INTEGER NOT NULL DEFAULT 0,
            is_low_carb INTEGER NOT NULL DEFAULT 0,
            is_high_protein INTEGER NOT NULL DEFAULT 0,
            is_keto INTEGER NOT NULL DEFAULT 0,
            last_synced TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS cached_health_data (
            user_id TEXT NOT NULL,
            recorded_date TEXT NOT NULL,
            steps INTEGER NOT NULL DEFAULT 0,
            calories_burned REAL NOT NULL DEFAULT 0,
            water_intake INTEGER NOT NULL DEFAULT 0,
            source TEXT NOT NULL DEFAULT 'manual',
            last_synced TEXT NOT NULL,
            PRIMARY KEY (user_id, recorded_date)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE user_profile(
              id TEXT PRIMARY KEY,
              username TEXT,
              avatar_url TEXT,
              last_synced TEXT
            )
          ''');
        }

        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE favorite_recipes(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT UNIQUE,
              ingredients TEXT,
              steps TEXT,
              image TEXT,
              kcal TEXT,
              duration TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE nutrition_logs_cache (
              id TEXT PRIMARY KEY,
              user_id TEXT NOT NULL,
              meal_type TEXT NOT NULL,
              food_name TEXT NOT NULL,
              calories REAL NOT NULL,
              protein REAL NOT NULL,
              carbs REAL NOT NULL,
              fat REAL NOT NULL,
              serving_size REAL NOT NULL,
              barcode TEXT,
              image_path TEXT,
              image_url TEXT,
              logged_at TEXT NOT NULL
            )
          ''');
        }

        if (oldVersion < 3) {
        }

        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE pedometer_baseline (
              date TEXT PRIMARY KEY,
              baseline INTEGER NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
        }

        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE cached_user_goals (
              user_id TEXT PRIMARY KEY,
              calorie_goal INTEGER NOT NULL DEFAULT 2000,
              protein_goal INTEGER NOT NULL DEFAULT 150,
              carbs_goal INTEGER NOT NULL DEFAULT 250,
              fat_goal INTEGER NOT NULL DEFAULT 65,
              water_goal INTEGER NOT NULL DEFAULT 8,
              step_goal INTEGER NOT NULL DEFAULT 10000,
              is_vegetarian INTEGER NOT NULL DEFAULT 0,
              is_vegan INTEGER NOT NULL DEFAULT 0,
              is_low_carb INTEGER NOT NULL DEFAULT 0,
              is_high_protein INTEGER NOT NULL DEFAULT 0,
              is_keto INTEGER NOT NULL DEFAULT 0,
              last_synced TEXT NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE cached_health_data (
              user_id TEXT NOT NULL,
              recorded_date TEXT NOT NULL,
              steps INTEGER NOT NULL DEFAULT 0,
              calories_burned REAL NOT NULL DEFAULT 0,
              water_intake INTEGER NOT NULL DEFAULT 0,
              source TEXT NOT NULL DEFAULT 'manual',
              last_synced TEXT NOT NULL,
              PRIMARY KEY (user_id, recorded_date)
            )
          ''');
        }
      },
    );
  }

  // --- EXISTING MEAL METHODS ---

  Future<int> insertMeal(Meal meal) async {
    final db = await database;
    return await db.insert('meals', meal.toMap());
  }

  Future<int> updateMeal(Meal meal) async {
    final db = await database;
    return await db.update(
      'meals',
      meal.toMap(),
      where: 'id = ?',
      whereArgs: [meal.id],
    );
  }

  Future<void> updateAllMealsWithTitle({
    required String title,
    required String ingredients,
    required String steps,
    required int kcal,
  }) async {
    final db = await database;
    await db.update(
      'meals',
      {
        'ingredients': ingredients,
        'steps': steps,
        'kcal': kcal,
        'isSocialPost': 0,
      },
      where: 'title = ?',
      whereArgs: [title],
    );
  }

  Future<List<Meal>> getMealsByDate(String dateString) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'meals',
      where: 'date = ?',
      whereArgs: [dateString],
    );
    return List.generate(maps.length, (i) => Meal.fromMap(maps[i]));
  }

  Future<void> deleteMeal(int id) async {
    final db = await database;
    await db.delete('meals', where: 'id = ?', whereArgs: [id]);
  }

  ///////////Leftover Recipe Methods///////////
  // Save recipe
  Future<void> saveFavorite(Map<String, String> recipe) async {
    final db = await database;

    await db.insert(
      'favorite_recipes',
      recipe,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Remove recipe
  Future<void> removeFavorite(String title) async {
    final db = await database;

    await db.delete(
      'favorite_recipes',
      where: 'title = ?',
      whereArgs: [title],
    );
  }

  // Get favorites
  Future<List<Map<String, dynamic>>> getFavorites() async {
    final db = await database;

    return await db.query(
      'favorite_recipes',
      orderBy: 'id DESC',
    );
  }

  // Check favorite
  Future<bool> isFavorite(String title) async {
    final db = await database;

    final result = await db.query(
      'favorite_recipes',
      where: 'title = ?',
      whereArgs: [title],
    );

    return result.isNotEmpty;
  }

  // --- EXISTING GROCERY METHODS ---

  Future<int> upsertGroceryItem(String name, double price, String category) async {
    final db = await database;
    return await db.insert(
      'grocery_items',
      {'name': name, 'price': price, 'category': category},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAllGroceryItems() async {
    final db = await database;
    return await db.query('grocery_items');
  }

  Future<int> removeGroceryItem(String name) async {
    final db = await database;
    return await db.delete('grocery_items', where: 'name = ?', whereArgs: [name]);
  }

  // --- NEW PROFILE METHODS (For Hybrid/Local Management) ---

  Future<int> saveLocalProfile(Map<String, dynamic> profileData) async {
    final db = await database;
    // Add a timestamp to know when we last synced with Supabase
    profileData['last_synced'] = DateTime.now().toIso8601String();

    return await db.insert(
      'user_profile',
      profileData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getLocalProfile(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'user_profile',
      where: 'id = ?',
      whereArgs: [userId],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> clearLocalProfile() async {
    final db = await database;
    await db.delete('user_profile');
  }

  Future<void> savePostsLocally(List<dynamic> posts) async {
    final db = await database;
    Batch batch = db.batch(); // Use batch for faster multiple inserts

    for (var post in posts) {
      batch.insert(
        'cached_posts',
        {
          'id': post['id'].toString(),
          'user_id': post['user_id'],
          'title': post['title'],
          'content': post['content'],
          'image_url': post['image_url'],
          'author_name': post['profiles']?['username'] ?? 'Unknown',
          'author_avatar': post['profiles']?['avatar_url'] ?? '',
          'created_at': post['created_at'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getLocalPosts() async {
    final db = await database;
    return await db.query('cached_posts', orderBy: 'created_at DESC');
  }

  Future<void> saveLikedPostsLocally(List<dynamic> likedData) async {
    final db = await database;
    Batch batch = db.batch();

    // Clear out the old cached likes to ensure we don't show un-liked posts
    await db.delete('cached_liked_posts');

    for (var item in likedData) {
      final post = item['posts']; // Extract the actual post data
      if (post != null) {
        batch.insert(
          'cached_liked_posts',
          {
            'id': post['id'].toString(),
            'user_id': post['user_id'],
            'title': post['title'],
            'content': post['content'],
            'image_url': post['image_url'],
            'author_name': post['profiles']?['username'] ?? 'Unknown',
            'author_avatar': post['profiles']?['avatar_url'] ?? '',
            'created_at': post['created_at'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getLocalLikedPosts() async {
    final db = await database;
    return await db.query('cached_liked_posts', orderBy: 'created_at DESC');
  }

  Future<void> cacheNutritionLogs(List<NutritionLog> logs) async {
    final db = await database;
    final batch = db.batch();
    for (final log in logs) {
      batch.insert(
        'nutrition_logs_cache',
        {
          'id': log.id.isEmpty
              ? '${log.userId}_${log.loggedAt.millisecondsSinceEpoch}'
              : log.id,
          'user_id': log.userId,
          'meal_type': log.mealType,
          'food_name': log.foodName,
          'calories': log.calories,
          'protein': log.protein,
          'carbs': log.carbs,
          'fat': log.fat,
          'serving_size': log.servingSize,
          'barcode': log.barcode,
          'image_path': log.imagePath,
          'image_url': log.imageUrl,
          'logged_at': log.loggedAt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    print('=== SQLITE CACHED: ${logs.length} nutrition logs ===');
  }

  Future<List<NutritionLog>> getNutritionLogsForDate(
      String userId, DateTime date) async {
    final db = await database;
    final startOfDay =
    DateTime(date.year, date.month, date.day).toIso8601String();
    final endOfDay =
    DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();

    print('=== SQLITE QUERY: user=$userId start=$startOfDay end=$endOfDay ===');

    final results = await db.query(
      'nutrition_logs_cache',
      where: 'user_id = ? AND logged_at >= ? AND logged_at <= ?',
      whereArgs: [userId, startOfDay, endOfDay],
      orderBy: 'logged_at ASC',
    );

    print('=== SQLITE LOADED: ${results.length} nutrition logs ===');
    for (final r in results) {
      print('=== ROW: ${r['food_name']} | logged_at: ${r['logged_at']} ===');
    }
    return results.map((row) => NutritionLog.fromMap(row)).toList();
  }

  Future<void> deleteNutritionLog(String logId) async {
    final db = await database;
    await db.delete(
      'nutrition_logs_cache',
      where: 'id = ?',
      whereArgs: [logId],
    );
  }

  Future<int?> getPedometerBaseline(String date) async {
    final db = await database;
    final result = await db.query(
      'pedometer_baseline',
      where: 'date = ?',
      whereArgs: [date],
    );
    if (result.isEmpty) return null;
    return result.first['baseline'] as int?;
  }

  Future<void> savePedometerBaseline(String date, int baseline) async {
    final db = await database;
    await db.insert(
      'pedometer_baseline',
      {
        'date': date,
        'baseline': baseline,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearOldBaselines() async {
    // Keep only last 7 days to avoid bloat
    final db = await database;
    final cutoff = DateTime.now()
        .subtract(const Duration(days: 7))
        .toString()
        .substring(0, 10);
    await db.delete(
      'pedometer_baseline',
      where: 'date < ?',
      whereArgs: [cutoff],
    );
  }

  Future<void> cacheUserGoals(UserGoals goals) async {
    final db = await database;
    await db.insert(
      'cached_user_goals',
      {
        'user_id': goals.userId,
        'calorie_goal': goals.calorieGoal.toInt(),
        'protein_goal': goals.proteinGoal.toInt(),
        'carbs_goal': goals.carbsGoal.toInt(),
        'fat_goal': goals.fatGoal.toInt(),
        'water_goal': goals.waterGoal,
        'step_goal': goals.stepGoal,
        'is_vegetarian': goals.isVegetarian ? 1 : 0,
        'is_vegan': goals.isVegan ? 1 : 0,
        'is_low_carb': goals.isLowCarb ? 1 : 0,
        'is_high_protein': goals.isHighProtein ? 1 : 0,
        'is_keto': goals.isKeto ? 1 : 0,
        'last_synced': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    print('=== SQLITE: user_goals cached ===');
  }

  Future<UserGoals?> getCachedUserGoals(String userId) async {
    final db = await database;
    final result = await db.query(
      'cached_user_goals',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    if (result.isEmpty) return null;
    final row = result.first;
    print('=== SQLITE: user_goals loaded from cache ===');
    return UserGoals(
      userId: row['user_id'] as String,
      calorieGoal: (row['calorie_goal'] as int).toDouble(),
      proteinGoal: (row['protein_goal'] as int).toDouble(),
      carbsGoal: (row['carbs_goal'] as int).toDouble(),
      fatGoal: (row['fat_goal'] as int).toDouble(),
      waterGoal: row['water_goal'] as int,
      stepGoal: row['step_goal'] as int,
      isVegetarian: (row['is_vegetarian'] as int) == 1,
      isVegan: (row['is_vegan'] as int) == 1,
      isLowCarb: (row['is_low_carb'] as int) == 1,
      isHighProtein: (row['is_high_protein'] as int) == 1,
      isKeto: (row['is_keto'] as int) == 1,
    );
  }

// --- HEALTH DATA CACHE ---

  Future<void> cacheHealthData(DailyHealthData data) async {
    final db = await database;
    final recordedDate = data.recordedAt.toString().substring(0, 10);
    await db.insert(
      'cached_health_data',
      {
        'user_id': data.userId,
        'recorded_date': recordedDate,
        'steps': data.steps,
        'calories_burned': data.caloriesBurned,
        'water_intake': data.waterIntake,
        'source': data.source,
        'last_synced': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    print('=== SQLITE: health_data cached for $recordedDate ===');
  }

  Future<void> cacheHealthDataList(List<Map<String, dynamic>> rows) async {
    final db = await database;
    final batch = db.batch();
    for (final row in rows) {
      final date = DateTime.tryParse(row['recorded_at'] ?? '');
      if (date == null) continue;
      batch.insert(
        'cached_health_data',
        {
          'user_id': row['user_id'] ?? '',
          'recorded_date': date.toString().substring(0, 10),
          'steps': (row['steps'] as num?)?.toInt() ?? 0,
          'calories_burned': (row['calories_burned'] as num?)?.toDouble() ?? 0,
          'water_intake': (row['water_intake'] as num?)?.toInt() ?? 0,
          'source': row['source'] ?? 'manual',
          'last_synced': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    print('=== SQLITE: cached ${rows.length} health_data rows ===');
  }

  Future<DailyHealthData?> getCachedHealthData(
      String userId, DateTime date) async {
    final db = await database;
    final recordedDate = date.toString().substring(0, 10);
    final result = await db.query(
      'cached_health_data',
      where: 'user_id = ? AND recorded_date = ?',
      whereArgs: [userId, recordedDate],
    );
    if (result.isEmpty) return null;
    final row = result.first;
    print('=== SQLITE: health_data loaded from cache for $recordedDate ===');
    return DailyHealthData(
      userId: row['user_id'] as String,
      steps: row['steps'] as int,
      caloriesBurned: (row['calories_burned'] as num).toDouble(),
      waterIntake: row['water_intake'] as int,
      source: row['source'] as String,
      recordedAt: date,
    );
  }

  Future<void> clearNutritionLogsForDate(String userId, DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day).toIso8601String();
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();
    await db.delete(
      'nutrition_logs_cache',
      where: 'user_id = ? AND logged_at >= ? AND logged_at <= ?',
      whereArgs: [userId, startOfDay, endOfDay],
    );
    print('=== SQLITE: cleared cache for ${date.toString().substring(0, 10)} ===');
  }
}