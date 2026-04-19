// lib/services/firestore_service.dart
//
// PURPOSE: A low-level wrapper around Cloud Firestore.
// Repositories (student, attendance) call this instead of calling
// FirebaseFirestore directly. This means:
//   1. One place to handle errors, retries, or logging.
//   2. Easy to mock in unit tests by replacing this service.
//   3. Developers never import 'cloud_firestore' outside this file.

import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  // --- Singleton ---
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- GET a collection reference ---
  // Used internally by repositories to build queries.
  CollectionReference<Map<String, dynamic>> collection(String path) {
    return _db.collection(path);
  }

  // --- CREATE / SET a document ---
  // [path]: e.g. 'students'
  // [docId]: the document ID (usually the user's UID)
  // [data]: a Map of the fields to store
  // [merge]: if true, only updates provided fields instead of overwriting.
  //          Use merge: true for "upsert" behavior (create or update).
  Future<void> setDocument({
    required String path,
    required String docId,
    required Map<String, dynamic> data,
    bool merge = true,
  }) async {
    try {
      await _db.collection(path).doc(docId).set(data, SetOptions(merge: merge));
    } on FirebaseException catch (e) {
      throw Exception('Firestore set error [${e.code}]: ${e.message}');
    }
  }

  // --- ADD a document (auto-generated ID) ---
  // Best for collections where you don't control the ID, like attendance logs.
  // Returns the auto-generated document ID so you can reference it later.
  Future<String> addDocument({
    required String path,
    required Map<String, dynamic> data,
  }) async {
    try {
      final docRef = await _db.collection(path).add(data);
      return docRef.id;
    } on FirebaseException catch (e) {
      throw Exception('Firestore add error [${e.code}]: ${e.message}');
    }
  }

  // --- READ a single document ---
  // Returns null if the document doesn't exist.
  Future<Map<String, dynamic>?> getDocument({
    required String path,
    required String docId,
  }) async {
    try {
      final snapshot = await _db.collection(path).doc(docId).get();
      return snapshot.exists ? snapshot.data() : null;
    } on FirebaseException catch (e) {
      throw Exception('Firestore get error [${e.code}]: ${e.message}');
    }
  }

  // --- STREAM a single document (real-time) ---
  // Returns a Stream so widgets can use StreamBuilder and auto-update
  // whenever this document changes in Firestore.
  Stream<Map<String, dynamic>?> streamDocument({
    required String path,
    required String docId,
  }) {
    return _db.collection(path).doc(docId).snapshots().map(
          (snapshot) => snapshot.exists ? snapshot.data() : null,
        );
  }

  // --- QUERY a collection ---
  // Returns a list of document data maps matching a field condition.
  // [field]: the Firestore field name to filter by
  // [value]: the value to match
  Future<List<Map<String, dynamic>>> queryCollection({
    required String path,
    required String field,
    required dynamic value,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          _db.collection(path).where(field, isEqualTo: value);

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }
      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } on FirebaseException catch (e) {
      throw Exception('Firestore query error [${e.code}]: ${e.message}');
    }
  }

  // --- STREAM a collection query (real-time) ---
  // Like queryCollection but returns a Stream for live updates.
  Stream<List<Map<String, dynamic>>> streamCollection({
    required String path,
    required String field,
    required dynamic value,
    String? orderBy,
    bool descending = false,
  }) {
    Query<Map<String, dynamic>> query =
        _db.collection(path).where(field, isEqualTo: value);

    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }

    return query.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  // --- UPDATE specific fields ---
  // Unlike set(merge:true), this fails if the document doesn't exist.
  // Use for partial updates when the doc is guaranteed to exist.
  Future<void> updateDocument({
    required String path,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _db.collection(path).doc(docId).update(data);
    } on FirebaseException catch (e) {
      throw Exception('Firestore update error [${e.code}]: ${e.message}');
    }
  }

  // --- DELETE a document ---
  Future<void> deleteDocument({
    required String path,
    required String docId,
  }) async {
    try {
      await _db.collection(path).doc(docId).delete();
    } on FirebaseException catch (e) {
      throw Exception('Firestore delete error [${e.code}]: ${e.message}');
    }
  }
}