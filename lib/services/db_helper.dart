import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/chat_message.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;

  DBHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('chat_cache.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sender TEXT,
            message TEXT,
            timestamp INTEGER,
            is_me INTEGER,
            is_delivered INTEGER
          )
        ''');
      },
    );
  }

  Future<void> insertMessages(List<ChatMessage> list) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var m in list) {
      batch.insert('messages', m.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<ChatMessage>> getDeliveredMessages() async {
    final db = await instance.database;
    final result = await db.query(
      'messages',
      where: 'is_delivered = ?',
      whereArgs: [1],
      orderBy: 'timestamp ASC',
    );
    return result.map((e) => ChatMessage.fromMap(e)).toList();
  }

  Future<List<ChatMessage>> getPendingMessagesUpTo(int timestamp) async {
    final db = await instance.database;
    final result = await db.query(
      'messages',
      where: 'is_delivered = 0 AND timestamp <= ?',
      whereArgs: [timestamp],
      orderBy: 'timestamp ASC',
    );
    return result.map((e) => ChatMessage.fromMap(e)).toList();
  }

  Future<void> markAsDelivered(int id) async {
    final db = await instance.database;
    await db.update(
      'messages',
      {'is_delivered': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearAll() async {
    final db = await instance.database;
    await db.delete('messages');
  }
}
