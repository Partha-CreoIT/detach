import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static Database? _database;
  static const String _databaseName = 'detach_stats.db';
  static const int _databaseVersion = 2;

  // Table names
  static const String tableAppUsage = 'app_usage';
  static const String tablePauseSessions = 'pause_sessions';
  static const String tableDailyStats = 'daily_stats';
  static const String tableLockedApps = 'locked_apps';

  // Singleton pattern
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize database and create all tables
  Future<void> initializeDatabase() async {
    try {
      final db = await database;
      print('Database initialized successfully with all tables');

      // Verify tables exist by checking table info
      final tables = await db.query('sqlite_master', where: 'type = ?', whereArgs: ['table']);
      print('Created tables: ${tables.map((t) => t['name']).toList()}');
    } catch (e) {
      print('Error initializing database: $e');
    }
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // App usage table - tracks individual app usage sessions
    await db.execute('''
      CREATE TABLE $tableAppUsage (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        package_name TEXT NOT NULL,
        app_name TEXT NOT NULL,
        start_time INTEGER NOT NULL,
        end_time INTEGER,
        duration_seconds INTEGER,
        created_at INTEGER NOT NULL
      )
    ''');

    // Pause sessions table - tracks when apps were paused/blocked
    await db.execute('''
      CREATE TABLE $tablePauseSessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        package_name TEXT NOT NULL,
        app_name TEXT NOT NULL,
        pause_start_time INTEGER NOT NULL,
        pause_end_time INTEGER,
        duration_seconds INTEGER,
        created_at INTEGER NOT NULL
      )
    ''');

    // Daily stats table - aggregated daily statistics
    await db.execute('''
      CREATE TABLE $tableDailyStats (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL UNIQUE,
        total_screen_time_seconds INTEGER DEFAULT 0,
        total_pause_time_seconds INTEGER DEFAULT 0,
        apps_used_count INTEGER DEFAULT 0,
        apps_paused_count INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Locked apps table - tracks individual app lock status and usage
    await db.execute('''
      CREATE TABLE $tableLockedApps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        package_name TEXT NOT NULL UNIQUE,
        app_name TEXT NOT NULL,
        total_locked_time INTEGER NOT NULL DEFAULT 0,
        time_used INTEGER NOT NULL DEFAULT 0,
        remaining_time INTEGER NOT NULL DEFAULT 0,
        last_session_time INTEGER NOT NULL DEFAULT 0,
        lock_status BOOLEAN NOT NULL DEFAULT 0,
        last_opened INTEGER,
        daily_usage_limit INTEGER NOT NULL DEFAULT 0,
        weekly_usage_limit INTEGER NOT NULL DEFAULT 0,
        daily_usage_today INTEGER NOT NULL DEFAULT 0,
        weekly_usage_this_week INTEGER NOT NULL DEFAULT 0,
        total_sessions INTEGER NOT NULL DEFAULT 0,
        average_session_time INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Weekly usage table - tracks daily usage for each app by day of week
    await db.execute('''
      CREATE TABLE weekly_usage (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        package_name TEXT NOT NULL,
        app_name TEXT NOT NULL,
        week_start_date TEXT NOT NULL,
        monday_usage INTEGER NOT NULL DEFAULT 0,
        tuesday_usage INTEGER NOT NULL DEFAULT 0,
        wednesday_usage INTEGER NOT NULL DEFAULT 0,
        thursday_usage INTEGER NOT NULL DEFAULT 0,
        friday_usage INTEGER NOT NULL DEFAULT 0,
        saturday_usage INTEGER NOT NULL DEFAULT 0,
        sunday_usage INTEGER NOT NULL DEFAULT 0,
        total_week_usage INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        UNIQUE(package_name, week_start_date)
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_app_usage_package ON $tableAppUsage(package_name)');
    await db.execute('CREATE INDEX idx_app_usage_date ON $tableAppUsage(created_at)');
    await db
        .execute('CREATE INDEX idx_pause_sessions_package ON $tablePauseSessions(package_name)');
    await db.execute('CREATE INDEX idx_pause_sessions_date ON $tablePauseSessions(created_at)');
    await db.execute('CREATE INDEX idx_locked_apps_package ON $tableLockedApps(package_name)');
    await db.execute('CREATE INDEX idx_locked_apps_status ON $tableLockedApps(lock_status)');
    await db.execute('CREATE INDEX idx_weekly_usage_package ON weekly_usage(package_name)');
    await db.execute('CREATE INDEX idx_weekly_usage_week ON weekly_usage(week_start_date)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add weekly_usage table for version 2
      await db.execute('''
        CREATE TABLE weekly_usage (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          package_name TEXT NOT NULL,
          app_name TEXT NOT NULL,
          week_start_date TEXT NOT NULL,
          monday_usage INTEGER NOT NULL DEFAULT 0,
          tuesday_usage INTEGER NOT NULL DEFAULT 0,
          wednesday_usage INTEGER NOT NULL DEFAULT 0,
          thursday_usage INTEGER NOT NULL DEFAULT 0,
          friday_usage INTEGER NOT NULL DEFAULT 0,
          saturday_usage INTEGER NOT NULL DEFAULT 0,
          sunday_usage INTEGER NOT NULL DEFAULT 0,
          total_week_usage INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          UNIQUE(package_name, week_start_date)
        )
      ''');

      await db.execute('CREATE INDEX idx_weekly_usage_package ON weekly_usage(package_name)');
      await db.execute('CREATE INDEX idx_weekly_usage_week ON weekly_usage(week_start_date)');

      print('DEBUG: Database upgraded to version 2 - added weekly_usage table');
    }
  }

  // App Usage Methods
  Future<int> insertAppUsage({
    required String packageName,
    required String appName,
    required DateTime startTime,
    DateTime? endTime,
  }) async {
    final db = await database;
    final duration = endTime != null ? endTime.difference(startTime).inSeconds : null;

    return await db.insert(tableAppUsage, {
      'package_name': packageName,
      'app_name': appName,
      'start_time': startTime.millisecondsSinceEpoch,
      'end_time': endTime?.millisecondsSinceEpoch,
      'duration_seconds': duration,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> updateAppUsageEndTime({
    required String packageName,
    required DateTime endTime,
  }) async {
    final db = await database;
    final now = DateTime.now();

    // Find the most recent open session for this app
    final List<Map<String, dynamic>> sessions = await db.query(
      tableAppUsage,
      where: 'package_name = ? AND end_time IS NULL',
      whereArgs: [packageName],
      orderBy: 'start_time DESC',
      limit: 1,
    );

    if (sessions.isNotEmpty) {
      final session = sessions.first;
      final startTime = DateTime.fromMillisecondsSinceEpoch(session['start_time']);
      final duration = endTime.difference(startTime).inSeconds;

      await db.update(
        tableAppUsage,
        {
          'end_time': endTime.millisecondsSinceEpoch,
          'duration_seconds': duration,
        },
        where: 'id = ?',
        whereArgs: [session['id']],
      );
    }
  }

  // Pause Sessions Methods
  Future<int> insertPauseSession({
    required String packageName,
    required String appName,
    required DateTime pauseStartTime,
    DateTime? pauseEndTime,
  }) async {
    final db = await database;
    final duration =
        pauseEndTime != null ? pauseEndTime.difference(pauseStartTime).inSeconds : null;

    return await db.insert(tablePauseSessions, {
      'package_name': packageName,
      'app_name': appName,
      'pause_start_time': pauseStartTime.millisecondsSinceEpoch,
      'pause_end_time': pauseEndTime?.millisecondsSinceEpoch,
      'duration_seconds': duration,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> updatePauseSessionEndTime({
    required String packageName,
    required DateTime pauseEndTime,
  }) async {
    final db = await database;

    // Find the most recent open pause session for this app
    final List<Map<String, dynamic>> sessions = await db.query(
      tablePauseSessions,
      where: 'package_name = ? AND pause_end_time IS NULL',
      whereArgs: [packageName],
      orderBy: 'pause_start_time DESC',
      limit: 1,
    );

    if (sessions.isNotEmpty) {
      final session = sessions.first;
      final pauseStartTime = DateTime.fromMillisecondsSinceEpoch(session['pause_start_time']);
      final duration = pauseEndTime.difference(pauseStartTime).inSeconds;

      await db.update(
        tablePauseSessions,
        {
          'pause_end_time': pauseEndTime.millisecondsSinceEpoch,
          'duration_seconds': duration,
        },
        where: 'id = ?',
        whereArgs: [session['id']],
      );
    }
  }

  // Statistics Methods
  Future<Map<String, dynamic>> getDailyStats(DateTime date) async {
    final db = await database;
    final dateStr = _formatDate(date);

    final List<Map<String, dynamic>> results = await db.query(
      tableDailyStats,
      where: 'date = ?',
      whereArgs: [dateStr],
    );

    if (results.isNotEmpty) {
      return results.first;
    }

    // If no stats exist for this date, create default entry
    final defaultStats = {
      'date': dateStr,
      'total_screen_time_seconds': 0,
      'total_pause_time_seconds': 0,
      'apps_used_count': 0,
      'apps_paused_count': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };

    final id = await db.insert(tableDailyStats, defaultStats);
    return {...defaultStats, 'id': id};
  }

  Future<List<Map<String, dynamic>>> getWeeklyStats(DateTime startDate) async {
    final db = await database;
    final endDate = startDate.add(const Duration(days: 7));
    final startDateStr = _formatDate(startDate);
    final endDateStr = _formatDate(endDate);

    return await db.query(
      tableDailyStats,
      where: 'date >= ? AND date < ?',
      whereArgs: [startDateStr, endDateStr],
      orderBy: 'date ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getTopAppsByUsage({
    required DateTime startDate,
    required DateTime endDate,
    int limit = 10,
  }) async {
    final db = await database;
    final startTime = startDate.millisecondsSinceEpoch;
    final endTime = endDate.millisecondsSinceEpoch;

    return await db.rawQuery('''
      SELECT 
        package_name,
        app_name,
        SUM(COALESCE(duration_seconds, 0)) as total_duration,
        COUNT(*) as session_count
      FROM $tableAppUsage
      WHERE created_at >= ? AND created_at <= ?
      GROUP BY package_name, app_name
      ORDER BY total_duration DESC
      LIMIT ?
    ''', [startTime, endTime, limit]);
  }

  Future<List<Map<String, dynamic>>> getTopPausedApps({
    required DateTime startDate,
    required DateTime endDate,
    int limit = 10,
  }) async {
    final db = await database;
    final startTime = startDate.millisecondsSinceEpoch;
    final endTime = endDate.millisecondsSinceEpoch;

    return await db.rawQuery('''
      SELECT 
        package_name,
        app_name,
        SUM(COALESCE(duration_seconds, 0)) as total_pause_duration,
        COUNT(*) as pause_count
      FROM $tablePauseSessions
      WHERE created_at >= ? AND created_at <= ?
      GROUP BY package_name, app_name
      ORDER BY total_pause_duration DESC
      LIMIT ?
    ''', [startTime, endTime, limit]);
  }

  Future<Map<String, dynamic>> getOverallStats({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await database;
    final startTime = startDate.millisecondsSinceEpoch;
    final endTime = endDate.millisecondsSinceEpoch;

    // Get total screen time
    final screenTimeResult = await db.rawQuery('''
      SELECT SUM(COALESCE(duration_seconds, 0)) as total_screen_time
      FROM $tableAppUsage
      WHERE created_at >= ? AND created_at <= ?
    ''', [startTime, endTime]);

    // Get total pause time
    final pauseTimeResult = await db.rawQuery('''
      SELECT SUM(COALESCE(duration_seconds, 0)) as total_pause_time
      FROM $tablePauseSessions
      WHERE created_at >= ? AND created_at <= ?
    ''', [startTime, endTime]);

    // Get unique apps used
    final appsUsedResult = await db.rawQuery('''
      SELECT COUNT(DISTINCT package_name) as unique_apps_used
      FROM $tableAppUsage
      WHERE created_at >= ? AND created_at <= ?
    ''', [startTime, endTime]);

    // Get unique apps paused
    final appsPausedResult = await db.rawQuery('''
      SELECT COUNT(DISTINCT package_name) as unique_apps_paused
      FROM $tablePauseSessions
      WHERE created_at >= ? AND created_at <= ?
    ''', [startTime, endTime]);

    return {
      'total_screen_time_seconds': screenTimeResult.first['total_screen_time'] ?? 0,
      'total_pause_time_seconds': pauseTimeResult.first['total_pause_time'] ?? 0,
      'unique_apps_used': appsUsedResult.first['unique_apps_used'] ?? 0,
      'unique_apps_paused': appsPausedResult.first['unique_apps_paused'] ?? 0,
    };
  }

  // Utility method to format date for database storage
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  // ===== LOCKED APPS METHODS =====

  /// Insert or update a locked app record
  Future<int> upsertLockedApp({
    required String packageName,
    required String appName,
    int? totalLockedTime,
    int? dailyUsageLimit,
    int? weeklyUsageLimit,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Check if app already exists
    final existing = await db.query(
      tableLockedApps,
      where: 'package_name = ?',
      whereArgs: [packageName],
    );

    if (existing.isNotEmpty) {
      // Update existing record (only update provided values)
      final updateData = <String, dynamic>{
        'app_name': appName,
        'updated_at': now,
      };

      if (totalLockedTime != null) updateData['total_locked_time'] = totalLockedTime;
      if (dailyUsageLimit != null) updateData['daily_usage_limit'] = dailyUsageLimit;
      if (weeklyUsageLimit != null) updateData['weekly_usage_limit'] = weeklyUsageLimit;

      await db.update(
        tableLockedApps,
        updateData,
        where: 'package_name = ?',
        whereArgs: [packageName],
      );
      return existing.first['id'] as int;
    } else {
      // Insert new record
      return await db.insert(tableLockedApps, {
        'package_name': packageName,
        'app_name': appName,
        'total_locked_time': totalLockedTime ?? 0,
        'time_used': 0,
        'remaining_time': totalLockedTime ?? 0,
        'last_session_time': 0,
        'lock_status': 0, // 0 = unlocked, 1 = locked
        'last_opened': null,
        'daily_usage_limit': dailyUsageLimit ?? 0,
        'weekly_usage_limit': weeklyUsageLimit ?? 0,
        'daily_usage_today': 0,
        'weekly_usage_this_week': 0,
        'total_sessions': 0,
        'average_session_time': 0,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  /// Get locked app by package name
  Future<Map<String, dynamic>?> getLockedApp(String packageName) async {
    final db = await database;
    final results = await db.query(
      tableLockedApps,
      where: 'package_name = ?',
      whereArgs: [packageName],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Get all locked apps
  Future<List<Map<String, dynamic>>> getAllLockedApps() async {
    final db = await database;
    return await db.query(
      tableLockedApps,
      orderBy: 'app_name ASC',
    );
  }

  /// Start app session (when app is opened)
  Future<void> startAppSession(String packageName) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.update(
      tableLockedApps,
      {
        'last_opened': now,
        'updated_at': now,
      },
      where: 'package_name = ?',
      whereArgs: [packageName],
    );
  }

  /// End app session (when app is closed or timer expires)
  Future<void> endAppSession({
    required String packageName,
    required int sessionDurationSeconds,
    bool isTimerExpired = false,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Get current app data
    final app = await getLockedApp(packageName);
    if (app == null) return;

    final currentTimeUsed = app['time_used'] ?? 0;
    final currentRemainingTime = app['remaining_time'] ?? 0;
    final currentTotalSessions = app['total_sessions'] ?? 0;
    final currentAverageSessionTime = app['average_session_time'] ?? 0;
    final dailyUsageLimit = app['daily_usage_limit'] ?? 0;
    final weeklyUsageLimit = app['weekly_usage_limit'] ?? 0;

    // Calculate new values
    final newTimeUsed = currentTimeUsed + sessionDurationSeconds;
    final newRemainingTime = isTimerExpired ? 0 : (currentRemainingTime - sessionDurationSeconds);
    final newTotalSessions = currentTotalSessions + 1;
    final newAverageSessionTime =
        (currentAverageSessionTime + sessionDurationSeconds) ~/ newTotalSessions;

    // Update daily and weekly usage
    final today = _formatDate(DateTime.now());
    final weekStart = _getWeekStart();
    final weekEnd = _getWeekEnd();

    // Reset daily usage if it's a new day
    final lastOpened = app['last_opened'];
    if (lastOpened != null) {
      final lastOpenedDate = _formatDate(DateTime.fromMillisecondsSinceEpoch(lastOpened));
      if (lastOpenedDate != today) {
        // Reset daily usage for new day
        await _resetDailyUsage(packageName);
      }
    }

    // Update the app record
    await db.update(
      tableLockedApps,
      {
        'time_used': newTimeUsed,
        'remaining_time': newRemainingTime,
        'last_session_time': sessionDurationSeconds,
        'lock_status': isTimerExpired ? 1 : 0, // Lock if timer expired
        'total_sessions': newTotalSessions,
        'average_session_time': newAverageSessionTime,
        'daily_usage_today': (app['daily_usage_today'] ?? 0) + sessionDurationSeconds,
        'updated_at': now,
      },
      where: 'package_name = ?',
      whereArgs: [packageName],
    );

    // Update weekly usage
    await _updateWeeklyUsage(packageName, sessionDurationSeconds);
  }

  /// Reset app lock (when user manually resets or timer resets)
  Future<void> resetAppLock(String packageName) async {
    final db = await database;
    final app = await getLockedApp(packageName);
    if (app == null) return;

    final totalLockedTime = app['total_locked_time'] ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.update(
      tableLockedApps,
      {
        'remaining_time': totalLockedTime,
        'lock_status': 0, // Unlock
        'updated_at': now,
      },
      where: 'package_name = ?',
      whereArgs: [packageName],
    );
  }

  /// Get daily usage statistics for locked apps
  Future<List<Map<String, dynamic>>> getLockedAppsDailyStats() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        package_name,
        app_name,
        time_used,
        total_locked_time,
        remaining_time,
        lock_status,
        total_sessions,
        average_session_time,
        daily_usage_today,
        daily_usage_limit
      FROM $tableLockedApps
      ORDER BY time_used DESC
    ''');
  }

  /// Debug method to check what's in the locked apps table
  Future<List<Map<String, dynamic>>> debugGetAllLockedApps() async {
    final db = await database;
    final results = await db.query(tableLockedApps);
    print('DEBUG: Found ${results.length} apps in locked_apps table:');
    for (final app in results) {
      print(
          '  - ${app['app_name']} (${app['package_name']}): time_used=${app['time_used']}, total_locked_time=${app['total_locked_time']}, daily_usage_limit=${app['daily_usage_limit']}');
    }
    return results;
  }

  /// Debug method to reset time_used for all apps (for testing)
  Future<void> debugResetAllTimeUsed() async {
    final db = await database;
    await db.update(
      tableLockedApps,
      {'time_used': 0, 'total_sessions': 0, 'average_session_time': 0},
    );
    print('DEBUG: Reset all time_used to 0');
  }

  /// Test method to add a sample locked app for debugging
  Future<void> addTestLockedApp() async {
    await upsertLockedApp(
      packageName: 'com.test.app',
      appName: 'Test App',
    );
    print('DEBUG: Added test app to locked_apps table');
  }

  /// Get weekly usage statistics for locked apps
  Future<List<Map<String, dynamic>>> getLockedAppsWeeklyStats() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        package_name,
        app_name,
        weekly_usage_this_week as time_used,
        weekly_usage_limit,
        (weekly_usage_limit - weekly_usage_this_week) as remaining_time,
        lock_status,
        total_sessions,
        average_session_time
      FROM $tableLockedApps
      ORDER BY weekly_usage_this_week DESC
    ''');
  }

  /// Get individual app statistics (like the YouTube detail page)
  Future<Map<String, dynamic>?> getAppDetailedStats(String packageName) async {
    final db = await database;
    final results = await db.query(
      tableLockedApps,
      where: 'package_name = ?',
      whereArgs: [packageName],
    );

    if (results.isEmpty) return null;

    final app = results.first;

    // Get daily usage for the past 7 days
    final dailyUsage = await getAppDailyUsage(packageName);

    return {
      ...app,
      'daily_usage_data': dailyUsage,
    };
  }

  /// Get daily usage for a specific app over the past 7 days
  Future<List<Map<String, dynamic>>> getAppDailyUsage(String packageName) async {
    final db = await database;
    final now = DateTime.now();
    final weekStart = _getWeekStart();
    final weekStartDate = _formatDate(weekStart);

    // Get weekly usage data
    final weeklyData = await db.query(
      'weekly_usage',
      where: 'package_name = ? AND week_start_date = ?',
      whereArgs: [packageName, weekStartDate],
    );

    if (weeklyData.isEmpty) {
      // Return empty data for the week
      return List.generate(7, (index) {
        final dayOfWeek = index + 1; // 1 = Monday, 7 = Sunday
        return {
          'day': _getDayName(dayOfWeek),
          'usage_seconds': 0,
          'day_of_week': dayOfWeek,
        };
      });
    }

    final record = weeklyData.first;
    return [
      {
        'day': 'Mon',
        'usage_seconds': record['monday_usage'] ?? 0,
        'day_of_week': 1,
      },
      {
        'day': 'Tue',
        'usage_seconds': record['tuesday_usage'] ?? 0,
        'day_of_week': 2,
      },
      {
        'day': 'Wed',
        'usage_seconds': record['wednesday_usage'] ?? 0,
        'day_of_week': 3,
      },
      {
        'day': 'Thu',
        'usage_seconds': record['thursday_usage'] ?? 0,
        'day_of_week': 4,
      },
      {
        'day': 'Fri',
        'usage_seconds': record['friday_usage'] ?? 0,
        'day_of_week': 5,
      },
      {
        'day': 'Sat',
        'usage_seconds': record['saturday_usage'] ?? 0,
        'day_of_week': 6,
      },
      {
        'day': 'Sun',
        'usage_seconds': record['sunday_usage'] ?? 0,
        'day_of_week': 7,
      },
    ];
  }

  /// Get weekly usage data for all apps
  Future<List<Map<String, dynamic>>> getWeeklyUsageData() async {
    final db = await database;
    final weekStart = _getWeekStart();
    final weekStartDate = _formatDate(weekStart);

    return await db.query(
      'weekly_usage',
      where: 'week_start_date = ?',
      whereArgs: [weekStartDate],
      orderBy: 'total_week_usage DESC',
    );
  }

  /// Check and clear old weekly data (auto-clear on Sunday night)
  Future<void> checkAndClearOldWeeklyData() async {
    final now = DateTime.now();
    final isSunday = now.weekday == 7; // Sunday
    final isNight = now.hour >= 23; // After 11 PM

    if (isSunday && isNight) {
      // Clear all weekly usage data older than current week
      final db = await database;
      final currentWeekStart = _getWeekStart();
      final currentWeekStartDate = _formatDate(currentWeekStart);

      // Delete all weekly usage records except current week
      await db.delete(
        'weekly_usage',
        where: 'week_start_date != ?',
        whereArgs: [currentWeekStartDate],
      );

      // Also reset the weekly_usage_this_week in locked_apps table
      await db.update(
        tableLockedApps,
        {'weekly_usage_this_week': 0},
      );

      print('DEBUG: Cleared old weekly usage data');
    }
  }

  /// Get current week's usage data for chart display
  Future<List<Map<String, dynamic>>> getCurrentWeekUsageData() async {
    final db = await database;
    final weekStart = _getWeekStart();
    final weekStartDate = _formatDate(weekStart);

    // Get all apps' weekly usage for current week
    final weeklyData = await db.query(
      'weekly_usage',
      where: 'week_start_date = ?',
      whereArgs: [weekStartDate],
    );

    // Aggregate data by day of week
    final Map<int, int> dailyTotals = {};
    for (int i = 1; i <= 7; i++) {
      dailyTotals[i] = 0;
    }

    for (final record in weeklyData) {
      for (int day = 1; day <= 7; day++) {
        final dayColumn = _getDayColumn(day);
        final dayUsage = (record[dayColumn] ?? 0) as int;
        dailyTotals[day] = (dailyTotals[day] ?? 0) + dayUsage;
      }
    }

    // Convert to list format for chart
    return dailyTotals.entries.map((entry) {
      return {
        'day': _getDayName(entry.key),
        'usage_seconds': entry.value,
        'day_of_week': entry.key,
      };
    }).toList();
  }

  /// Reset daily usage for an app
  Future<void> _resetDailyUsage(String packageName) async {
    final db = await database;
    await db.update(
      tableLockedApps,
      {
        'daily_usage_today': 0,
      },
      where: 'package_name = ?',
      whereArgs: [packageName],
    );
  }

  /// Update weekly usage for an app
  Future<void> _updateWeeklyUsage(String packageName, int sessionDuration) async {
    final db = await database;
    final app = await getLockedApp(packageName);
    if (app == null) return;

    final currentWeeklyUsage = app['weekly_usage_this_week'] ?? 0;
    await db.update(
      tableLockedApps,
      {
        'weekly_usage_this_week': currentWeeklyUsage + sessionDuration,
      },
      where: 'package_name = ?',
      whereArgs: [packageName],
    );

    // Also update the new weekly usage table
    await _updateWeeklyUsageTable(packageName, sessionDuration);
  }

  /// Update weekly usage table with daily breakdown
  Future<void> _updateWeeklyUsageTable(String packageName, int sessionDuration) async {
    final db = await database;
    final app = await getLockedApp(packageName);
    if (app == null) return;

    final now = DateTime.now();
    final weekStart = _getWeekStart();
    final weekStartDate = _formatDate(weekStart);
    final dayOfWeek = now.weekday; // 1 = Monday, 7 = Sunday

    // Get or create weekly usage record
    final existingRecord = await db.query(
      'weekly_usage',
      where: 'package_name = ? AND week_start_date = ?',
      whereArgs: [packageName, weekStartDate],
    );

    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final dayColumn = _getDayColumn(dayOfWeek);

    if (existingRecord.isNotEmpty) {
      // Update existing record
      final record = existingRecord.first;
      final currentDayUsage = (record[dayColumn] ?? 0) as int;
      final currentTotalUsage = (record['total_week_usage'] ?? 0) as int;

      await db.update(
        'weekly_usage',
        {
          dayColumn: currentDayUsage + sessionDuration,
          'total_week_usage': currentTotalUsage + sessionDuration,
          'updated_at': currentTime,
        },
        where: 'package_name = ? AND week_start_date = ?',
        whereArgs: [packageName, weekStartDate],
      );
    } else {
      // Create new record
      final initialData = {
        'package_name': packageName,
        'app_name': app['app_name'] ?? 'Unknown',
        'week_start_date': weekStartDate,
        'monday_usage': 0,
        'tuesday_usage': 0,
        'wednesday_usage': 0,
        'thursday_usage': 0,
        'friday_usage': 0,
        'saturday_usage': 0,
        'sunday_usage': 0,
        'total_week_usage': sessionDuration,
        'created_at': currentTime,
        'updated_at': currentTime,
      };
      initialData[dayColumn] = sessionDuration;

      await db.insert('weekly_usage', initialData);
    }
  }

  /// Get the column name for a given day of week
  String _getDayColumn(int dayOfWeek) {
    switch (dayOfWeek) {
      case 1:
        return 'monday_usage';
      case 2:
        return 'tuesday_usage';
      case 3:
        return 'wednesday_usage';
      case 4:
        return 'thursday_usage';
      case 5:
        return 'friday_usage';
      case 6:
        return 'saturday_usage';
      case 7:
        return 'sunday_usage';
      default:
        return 'monday_usage';
    }
  }

  /// Get day name for a given day of week
  String _getDayName(int dayOfWeek) {
    switch (dayOfWeek) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return 'Mon';
    }
  }

  /// Get week start date (Monday)
  DateTime _getWeekStart() {
    final now = DateTime.now();
    final daysFromMonday = now.weekday - 1;
    return now.subtract(Duration(days: daysFromMonday));
  }

  /// Get week end date (Sunday)
  DateTime _getWeekEnd() {
    final weekStart = _getWeekStart();
    return weekStart.add(const Duration(days: 6));
  }

  /// Delete locked app
  Future<void> deleteLockedApp(String packageName) async {
    final db = await database;
    await db.delete(
      tableLockedApps,
      where: 'package_name = ?',
      whereArgs: [packageName],
    );
  }

  /// Set timer for a locked app (called when user sets timer on pause screen)
  Future<void> setAppTimer({
    required String packageName,
    required int timerSeconds,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.update(
      tableLockedApps,
      {
        'total_locked_time': timerSeconds,
        'remaining_time': timerSeconds,
        'updated_at': now,
      },
      where: 'package_name = ?',
      whereArgs: [packageName],
    );
  }

  /// Update app usage when timer expires or user exits early
  Future<void> updateAppUsage({
    required String packageName,
    required int sessionDurationSeconds,
    bool isTimerExpired = false,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Get current app data
    final app = await getLockedApp(packageName);
    if (app == null) return;

    final currentTimeUsed = app['time_used'] ?? 0;
    final currentRemainingTime = app['remaining_time'] ?? 0;
    final currentTotalSessions = app['total_sessions'] ?? 0;
    final currentAverageSessionTime = app['average_session_time'] ?? 0;

    // Calculate new values
    final newTimeUsed = currentTimeUsed + sessionDurationSeconds;
    final newRemainingTime = isTimerExpired ? 0 : (currentRemainingTime - sessionDurationSeconds);
    final newTotalSessions = currentTotalSessions + 1;
    final newAverageSessionTime =
        (currentAverageSessionTime + sessionDurationSeconds) ~/ newTotalSessions;

    print(
        'DEBUG: updateAppUsage - $packageName: currentTimeUsed=$currentTimeUsed, sessionDurationSeconds=$sessionDurationSeconds, newTimeUsed=$newTimeUsed, isTimerExpired=$isTimerExpired');
    print('DEBUG: updateAppUsage - Stack trace: ${StackTrace.current}');

    // Update the app record
    await db.update(
      tableLockedApps,
      {
        'time_used': newTimeUsed,
        'remaining_time': newRemainingTime,
        'last_session_time': sessionDurationSeconds,
        'lock_status': isTimerExpired ? 1 : 0, // Lock if timer expired
        'total_sessions': newTotalSessions,
        'average_session_time': newAverageSessionTime,
        'daily_usage_today': (app['daily_usage_today'] ?? 0) + sessionDurationSeconds,
        'updated_at': now,
      },
      where: 'package_name = ?',
      whereArgs: [packageName],
    );

    // Update weekly usage
    await _updateWeeklyUsage(packageName, sessionDurationSeconds);
  }
}
