import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/debt_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('debts.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE debts(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      userId INTEGER NOT NULL,
      username TEXT NOT NULL,
      phoneNumber TEXT,
      amount REAL NOT NULL,
      dueDate TEXT NOT NULL,
      createdAt TEXT NOT NULL,
      isPaid INTEGER NOT NULL,
      notes TEXT
    )
    ''');
  }

  // حل مشكلة تكرار المستخدمين من خلال التأكد من الحصول على معرف مستخدم صحيح
  Future<int> getUserIdByUsername(String username) async {
    final db = await instance.database;
    
    // البحث عن المستخدم الموجود حسب اسم المستخدم
    final existingUser = await db.query(
      'debts',
      columns: ['userId'],
      where: 'username = ? AND isPaid = 0',  // نبحث فقط في الديون غير المسددة
      whereArgs: [username],
      groupBy: 'userId',  // لتجنب النتائج المكررة
    );
    
    if (existingUser.isNotEmpty && existingUser.first['userId'] != null) {
      return existingUser.first['userId'] as int;
    } else {
      // إنشاء معرف جديد إذا لم يتم العثور على المستخدم
      final maxIdResult = await db.rawQuery('SELECT MAX(userId) as maxId FROM debts');
      int newUserId = (maxIdResult.first['maxId'] as int? ?? 0) + 1;
      return newUserId;
    }
  }

  // تحديث إضافة دين جديد للتأكد من استخدام نفس معرف المستخدم للمستخدمين الموجودين
  Future<int> addDebt(DebtModel debt) async {
    final db = await instance.database;
    
    // التأكد من أن userId غير فارغ
    if (debt.userId == null || debt.userId == 0) {
      // الحصول على معرف المستخدم الموجود أو إنشاء واحد جديد
      final userId = await getUserIdByUsername(debt.username);
      debt = debt.copyWith(userId: userId);
    }
    
    return await db.insert('debts', debt.toMap());
  }

  Future<List<DebtModel>> getAllDebts() async {
    final db = await instance.database;
    final result = await db.query('debts', orderBy: 'userId, dueDate');
    return result.map((json) => DebtModel.fromMap(json)).toList();
  }

  Future<List<DebtModel>> getDebtsByUsername(String username) async {
    final db = await instance.database;
    final result = await db.query(
      'debts',
      where: 'username = ?',
      whereArgs: [username],
    );
    return result.map((json) => DebtModel.fromMap(json)).toList();
  }

  // الحصول على جميع الديون لمستخدم محدد بواسطة معرف المستخدم
  Future<List<DebtModel>> getDebtsByUserId(int userId) async {
    final db = await instance.database;
    final result = await db.query(
      'debts',
      where: 'userId = ? AND isPaid = 0',
      whereArgs: [userId],
    );
    return result.map((json) => DebtModel.fromMap(json)).toList();
  }

  Future<double> getTotalUnpaidDebts() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM debts WHERE isPaid = 0'
    );
    return result.first['total'] as double? ?? 0.0;
  }

  Future<int> updateDebtStatus(int debtId, bool isPaid) async {
    final db = await instance.database;
    return await db.update(
      'debts',
      {'isPaid': isPaid ? 1 : 0},
      where: 'id = ?',
      whereArgs: [debtId],
    );
  }

  Future<int> updateDebtAmount(int debtId, double newAmount) async {
    final db = await instance.database;
    return await db.update(
      'debts',
      {'amount': newAmount},
      where: 'id = ?',
      whereArgs: [debtId],
    );
  }

  Future<int> updateDebtNotes(int debtId, String notes) async {
    final db = await instance.database;
    return await db.update(
      'debts',
      {'notes': notes},
      where: 'id = ?',
      whereArgs: [debtId],
    );
  }
  
  // دالة جديدة لتحديث رقم الهاتف
  Future<int> updatePhoneNumber(int debtId, String phoneNumber) async {
    final db = await database;
    return await db.update(
      'debts',
      {'phoneNumber': phoneNumber},
      where: 'id = ?',
      whereArgs: [debtId],
    );
  }
  
  // الحصول على مجموعات المستخدمين مع إجمالي الديون
  Future<Map<int, Map<String, dynamic>>> getUserGroups() async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT 
        userId, 
        username, 
        SUM(amount) as totalAmount, 
        COUNT(*) as debtCount, 
        MIN(phoneNumber) as phoneNumber
      FROM debts 
      WHERE isPaid = 0 
      GROUP BY userId
    ''');
    
    Map<int, Map<String, dynamic>> userGroups = {};
    
    for (var row in result) {
      final userId = row['userId'] as int;
      userGroups[userId] = {
        'username': row['username'] as String,
        'totalAmount': row['totalAmount'] as double,
        'debtCount': row['debtCount'] as int,
        'phoneNumber': row['phoneNumber'] as String?,
      };
    }
    
    return userGroups;
  }
}