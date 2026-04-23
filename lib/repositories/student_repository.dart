// lib/repositories/student_repository.dart
//
// PURPOSE: All Firestore operations for the `students` collection.
// Repositories are the "domain layer" — they know WHAT data to store
// and in WHAT format, but delegate HOW to store it to FirestoreService.
//
// Having a StudentRepository means:
//   - The student schema is defined in one place (StudentModel).
//   - UI code just calls studentRepo.saveStudent(...), never raw Firestore.
//   - If you rename a Firestore field later, you fix it here only.

import '../services/firestore_service.dart';

// --- StudentModel ---
// A plain Dart class that mirrors one document in `students` collection.
// Using a model (vs raw Maps) catches typos at compile time.
class StudentModel {
  final String uid;        // Firebase Auth UID — used as document ID
  final String name;       // Full name from Google account
  final String email;      // Email from Google account
  final String studentId;  // PUP student ID (e.g. 2021-00123-MN-0)
  final String course;     // e.g. "BSIT"

  const StudentModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.studentId,
    required this.course,
  });

  // toMap(): converts this object → Map for Firestore storage.
  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'email': email,
        'studentId': studentId,
        'course': course,
      };

  // fromMap(): converts a Firestore Map → StudentModel.
  // The ?? '' fallback prevents null crashes if a field is missing in Firestore.
  factory StudentModel.fromMap(Map<String, dynamic> map) => StudentModel(
        uid: map['uid'] ?? '',
        name: map['name'] ?? '',
        email: map['email'] ?? '',
        studentId: map['studentId'] ?? '',
        course: map['course'] ?? '',
      );
}

// --- StudentRepository ---
class StudentRepository {
  // Takes FirestoreService as a parameter (dependency injection).
  // This makes it easy to pass a mock service during testing.
  final FirestoreService _firestoreService;

  StudentRepository({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  static const String _collection = 'students';

  // --- Save or Update a student profile ---
  // Uses setDocument with merge:true → safe to call on both
  // first login (creates doc) and profile updates (updates fields).
  Future<void> saveStudent(StudentModel student) async {
    await _firestoreService.setDocument(
      path: _collection,
      docId: student.uid,
      data: student.toMap(),
      merge: true,
    );
  }

  // --- Fetch a student by UID ---
  // Returns null if the profile hasn't been created yet
  // (e.g., new user who just signed in but hasn't filled the form).
  Future<StudentModel?> getStudent(String uid) async {
    final data = await _firestoreService.getDocument(
      path: _collection,
      docId: uid,
    );
    return data != null ? StudentModel.fromMap(data) : null;
  }

  // --- Real-time stream of a student's profile ---
  // Use this in a StreamBuilder widget so the profile UI
  // auto-updates if an admin edits the record in Firestore.
  Stream<StudentModel?> streamStudent(String uid) {
    return _firestoreService
        .streamDocument(path: _collection, docId: uid)
        .map((data) => data != null ? StudentModel.fromMap(data) : null);
  }

  // --- Update only specific fields ---
  // Use this for partial edits (e.g., student changes their course).
  Future<void> updateStudentFields(
      String uid, Map<String, dynamic> fields) async {
    await _firestoreService.updateDocument(
      path: _collection,
      docId: uid,
      data: fields,
    );
  }
}