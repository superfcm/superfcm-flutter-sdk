import 'package:sqflite/sqflite.dart';
import 'package:superfcm_flutter/src/utils/constants.dart';
import 'package:superfcm_flutter/src/utils/logger.dart';
import 'package:superfcm_flutter/src/utils/string_utils.dart';
import 'package:superfcm_flutter/superfcm_config.dart';

/// A singleton class that manages local caching of requests and events using SQLite database.
///
/// The [CacheManager] provides functionality to:
/// - Initialize and manage the SQLite database
/// - Cache requests and events for offline support
/// - Handle data retention and cleanup
/// - Retrieve cached items for processing
class CacheManager {
  static final CacheManager _instance = CacheManager._internal();

  SuperFCMConfig? _config;
  Database? _database;
  bool initialized = false;

  /// Factory constructor that returns the singleton instance
  factory CacheManager() {
    return _instance;
  }

  CacheManager._internal();

  /// Provides access to the singleton instance of [CacheManager]
  static CacheManager get instance => _instance;

  /// Gets the current database instance.
  ///
  /// Throws a [StateError] if the database is not initialized or is closed.
  Database get database {
    if (_database == null || !_database!.isOpen) {
      throw StateError('Database not initialized. Call initialize() first.');
    }
    return _database!;
  }

  /// Sets the database instance.
  ///
  /// This is primarily used by the background message handler to set up a temporary
  /// database connection in its isolate.
  set database(Database db) {
    _database = db;
  }

  /// Initializes the SQLite database with the required schema.
  ///
  /// Creates tables for requests and events if they don't exist.
  Future<void> _initializeDatabase() async {
    logger.d('Initializing cache database');
    _database = await openDatabase(
      kCacheDatabaseName,
      version: kCacheDatabaseVersion,
      onCreate: (db, version) async {
        logger.d('Creating new cache database');
        await db.execute(
          'CREATE TABLE requests(id INTEGER PRIMARY KEY, type TEXT, endpoint TEXT, data TEXT, timestamp INTEGER)',
        );
        await db.execute(
          'CREATE TABLE events(id INTEGER PRIMARY KEY, name TEXT, subscriptionId TEXT, timestamp INTEGER)',
        );
      },
    );
    logger.v('Cache database initialization complete');
  }

  /// Initializes the cache manager with configuration and database.
  ///
  /// Sets up the configuration and initializes the SQLite database with necessary tables:
  /// - requests: Stores pending API requests
  /// - events: Stores events that need to be processed
  ///
  /// This must be called before using any other CacheManager functionality.
  ///
  /// Throws an exception if initialization fails.
  Future<void> initialize(SuperFCMConfig config) async {
    if (initialized) {
      return;
    }
    _config = config;
    await _initializeDatabase();
    logger.d('Cache Manager initialized');
    initialized = true;
  }

  /// Closes the database connection and cleans up resources.
  Future<void> dispose() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
    }
    _database = null;
  }

  /// Adds an item to the specified cache table.
  ///
  /// [type] specifies the table name where the item should be stored.
  /// [data] is the item data to be cached.
  ///
  /// The item is stored with a timestamp that can be used for retention management.
  /// Throws an exception if the operation fails or if the database is not initialized.
  Future<void> addItem(
    String type,
    Map<String, dynamic> data,
  ) async {
    logger.v('Adding to $type cache: $data');

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final itemWithTimestamp = {
      ...data,
      'timestamp': timestamp,
    };

    await database.insert(type, itemWithTimestamp).then((result) {
      logger.v('Item successfully cached');
    }).catchError((e) {
      logger.e('Failed to add to $type cache');
      throw e;
    });
  }

  /// Removes an item from the specified cache table.
  ///
  /// [type] specifies the table name from which to remove the item.
  /// [id] is the unique identifier of the item to remove.
  ///
  /// Throws an exception if the operation fails or if the database is not initialized.
  Future<void> removeItem(String type, int id) async {
    logger.v('Removing $type with ID: $id');
    await database.delete(type, where: 'id = ?', whereArgs: [id]).then((_) {
      logger.v('${type.ucfirst()} removed successfully');
    }).catchError((e) {
      logger.e('Failed to remove $type');
      throw e;
    });
  }

  /// Retrieves all items from the specified cache table.
  ///
  /// [type] specifies the table name from which to retrieve items.
  ///
  /// Returns a list of cached items, ordered by timestamp (oldest first).
  /// If a retention duration is configured, automatically removes expired items
  /// and returns only valid items.
  ///
  /// Throws an exception if the operation fails or if the database is not initialized.
  Future<List<Map<String, dynamic>>> getItems(String type) async {
    logger.v('Fetching pending $type');
    final items = await database
        .query(
          type,
          orderBy: 'timestamp ASC',
        )
        .then((result) => result)
        .catchError((e) {
      logger.e('Failed to fetch pending $type');
      throw e;
    });

    final maxCacheDuration = _config?.maxCacheDuration;
    if (maxCacheDuration != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final validItems = items.where((request) {
        final timestamp = request['timestamp'] as int;
        final age = Duration(milliseconds: now - timestamp);
        return age <= maxCacheDuration;
      }).toList();

      final expiredItems = items.where((item) {
        final timestamp = item['timestamp'] as int;
        final age = Duration(milliseconds: now - timestamp);
        return age > maxCacheDuration;
      }).toList();

      for (var item in expiredItems) {
        await removeItem(type, item['id'] as int);
      }

      if (expiredItems.isNotEmpty) {
        logger.d('Removed ${expiredItems.length} expired $type');
      }

      logger.v('Found ${validItems.length} valid pending $type');
      return validItems;
    }

    logger.v('Found ${items.length} pending $type');
    return items;
  }
}
