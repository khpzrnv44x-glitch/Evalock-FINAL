import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user_model.dart';
import '../models/data_models.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    // Bump version to v11 to ensure new columns are created
    _database = await _initDB('evalock_final_v11.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute(
      'CREATE TABLE students (id TEXT PRIMARY KEY, name TEXT, email TEXT, roll_no TEXT)',
    );

    // Added is_visible and are_results_visible columns
    // Note: 'descriptions' is used for the Topic Name based on your model
    await db.execute('''
      CREATE TABLE presentations (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        descriptions TEXT, 
        creator_email TEXT,
        is_visible INTEGER DEFAULT 1,
        are_results_visible INTEGER DEFAULT 0
      )
    ''');

    await db.execute(
      'CREATE TABLE presentation_criteria (id INTEGER PRIMARY KEY, pid INTEGER, description TEXT, marks REAL, comments_allowed TEXT)',
    );

    await db.execute('''
      CREATE TABLE student_evaluation (
        id INTEGER PRIMARY KEY, 
        evaluated_student TEXT, 
        evaluated_by TEXT, 
        category_id INTEGER, 
        obtained_marks REAL, 
        feedback_text TEXT,
        is_synced INTEGER DEFAULT 1
      )
    ''');

    await db.execute(
      'CREATE TABLE presentation_codes (id INTEGER PRIMARY KEY, presentation_id INTEGER, presentation_code TEXT)',
    );
    await db.execute(
      'CREATE TABLE download_logs (id INTEGER PRIMARY KEY, user_email TEXT, download_time TEXT)',
    );
  }

  // --- SYNC HELPERS ---
  Future<void> clearAndInsert(String table, List<dynamic> data) async {
    final db = await instance.database;
    await db.delete(table);
    Batch batch = db.batch();
    for (var row in data) {
      batch.insert(table, row);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Presentation>> getLocalPresentations() async {
    final db = await instance.database;
    final res = await db.query('presentations');
    return res.map((e) => Presentation.fromJson(e)).toList();
  }

  // --- NEW: CREATOR & ADMIN LOGIC ---

  // 1. Insert New Presentation (Used by Create Screen)
  Future<int> insertPresentation(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('presentations', row);
  }

  // 2. SUPER ADMIN: Get All Presentations (For Nabeel)
  Future<List<Map<String, dynamic>>> getAllPresentations() async {
    final db = await instance.database;
    return await db.query('presentations', orderBy: 'id DESC');
  }

  // 3. REGULAR ADMIN: Get Only My Presentations (For You/Others)
  Future<List<Map<String, dynamic>>> getMyPresentations(String email) async {
    final db = await instance.database;
    return await db.query(
      'presentations',
      where: 'creator_email = ?',
      whereArgs: [email],
      orderBy: 'id DESC',
    );
  }

  // 4. Delete Presentation (Used by Delete Icon)
  Future<int> deletePresentation(int id) async {
    final db = await instance.database;
    return await db.delete('presentations', where: 'id = ?', whereArgs: [id]);
  }

  // --- NEW: Update Visibility Methods ---
  Future<void> updatePresentationVisibility(String id, int isVisible) async {
    final db = await instance.database;
    await db.update(
      'presentations',
      {'is_visible': isVisible},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateResultVisibility(String id, int areVisible) async {
    final db = await instance.database;
    await db.update(
      'presentations',
      {'are_results_visible': areVisible},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- STANDARD HELPERS ---
  Future<bool> validateCode(String presentationId, String inputCode) async {
    final db = await instance.database;
    final res = await db.query(
      'presentation_codes',
      where: 'presentation_id = ? AND presentation_code = ?',
      whereArgs: [presentationId, inputCode],
    );
    return res.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getTeacherQueryB(String pid) async {
    final db = await instance.database;
    return await db.rawQuery(
      '''
      SELECT
          SUM(se.obtained_marks) as obtained_marks,
          SUM(pc.marks) as total_marks,
          ROUND(SUM(se.obtained_marks)/SUM(pc.marks)*100, 2) as percentage,
          count(*) as total_evaluated,
          se.evaluated_student
      FROM
          student_evaluation se
      LEFT JOIN presentation_criteria pc ON
          pc.id = se.category_id
      LEFT JOIN presentations p ON
          p.id = pc.pid
      WHERE
          p.id = ? 
      GROUP BY
          se.evaluated_student
      ORDER BY 
          evaluated_student
    ''',
      [pid],
    );
  }

  Future<List<Map<String, dynamic>>> getAdminLogs() async {
    final db = await instance.database;
    return await db.query('download_logs', orderBy: 'id DESC');
  }

  Future<List<User>> getLocalStudents() async {
    final db = await instance.database;
    final res = await db.query('students');
    return res.map((e) => User.fromMap(e)).toList();
  }

  Future<List<Map<String, dynamic>>> getCriteriaForPresentation(
    String pid,
  ) async {
    final db = await instance.database;
    return await db.query(
      'presentation_criteria',
      where: 'pid = ?',
      whereArgs: [pid],
    );
  }

  Future<List<Map<String, dynamic>>> getStudentComments(
    String pid,
    String studentId,
  ) async {
    final db = await instance.database;
    return await db.rawQuery(
      '''
      SELECT se.feedback_text, se.evaluated_by 
      FROM student_evaluation se
      JOIN presentation_criteria pc ON pc.id = se.category_id
      WHERE pc.pid = ? AND se.evaluated_student = ? AND se.feedback_text != ''
    ''',
      [pid, studentId],
    );
  }

  Future<List<Map<String, dynamic>>> getLocalEvaluation(
    String studentId,
    String evaluatorId,
    String presentationId,
  ) async {
    final db = await instance.database;
    return await db.rawQuery(
      '''
      SELECT se.* FROM student_evaluation se
      JOIN presentation_criteria pc ON pc.id = se.category_id
      WHERE se.evaluated_student = ? AND se.evaluated_by = ? AND pc.pid = ?
    ''',
      [studentId, evaluatorId, presentationId],
    );
  }

  Future<void> saveEvaluationRows(List<Map<String, dynamic>> rows) async {
    final db = await instance.database;
    Batch batch = db.batch();
    for (var row in rows) {
      batch.delete(
        'student_evaluation',
        where: 'evaluated_student = ? AND evaluated_by = ? AND category_id = ?',
        whereArgs: [
          row['evaluated_student'],
          row['evaluated_by'],
          row['category_id'],
        ],
      );
      row['is_synced'] = 0;
      batch.insert('student_evaluation', row);
    }
    await batch.commit();
  }

  Future<List<Map<String, dynamic>>> getPendingEvaluations() async {
    final db = await instance.database;
    return await db.query('student_evaluation', where: 'is_synced = 0');
  }

  Future<void> markAsSynced() async {
    final db = await instance.database;
    await db.update('student_evaluation', {
      'is_synced': 1,
    }, where: 'is_synced = 0');
  }
}
