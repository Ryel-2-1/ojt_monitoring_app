import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/company_model.dart';
import '../services/firestore_service.dart';

class CompanyRepository {
  final FirestoreService _firestoreService;

  CompanyRepository({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  static const String _collection = 'companies';

  Stream<List<CompanyModel>> streamCompanies({
  bool activeOnly = false,
}) {
  return _firestoreService.collection(_collection).snapshots().map((snapshot) {
    final companies = snapshot.docs.map((doc) {
      return CompanyModel.fromMap(
        doc.data(),
        id: doc.id,
      );
    }).where((company) {
      if (!activeOnly) return true;
      return company.isActive;
    }).toList();

    companies.sort(
      (a, b) => a.companyName.toLowerCase().compareTo(
            b.companyName.toLowerCase(),
          ),
    );

    return companies;
  });
}

  Future<List<CompanyModel>> getActiveCompanies() async {
  final snapshot = await _firestoreService.collection(_collection).get();

  final companies = snapshot.docs.map((doc) {
    return CompanyModel.fromMap(
      doc.data(),
      id: doc.id,
    );
  }).where((company) {
    return company.isActive;
  }).toList();

  companies.sort(
    (a, b) => a.companyName.toLowerCase().compareTo(
          b.companyName.toLowerCase(),
        ),
  );

  return companies;
}

  Future<CompanyModel?> getCompanyById(String companyId) async {
    final doc = await _firestoreService
        .collection(_collection)
        .doc(companyId)
        .get();

    if (!doc.exists || doc.data() == null) return null;

    return CompanyModel.fromMap(
      doc.data()!,
      id: doc.id,
    );
  }

  Future<String> createCompany({
    required String companyName,
    required String companyAddress,
    required double assignedLatitude,
    required double assignedLongitude,
    required double allowedRadius,
    String? createdBySupervisorUid,
  }) async {
    final model = CompanyModel(
      companyName: companyName.trim(),
      companyAddress: companyAddress.trim(),
      assignedLatitude: assignedLatitude,
      assignedLongitude: assignedLongitude,
      allowedRadius: allowedRadius,
      isActive: true,
      createdBySupervisorUid: createdBySupervisorUid,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return _firestoreService.addDocument(
      path: _collection,
      data: model.toMap(),
    );
  }

  Future<void> updateCompany({
    required String companyId,
    required String companyName,
    required String companyAddress,
    required double assignedLatitude,
    required double assignedLongitude,
    required double allowedRadius,
    required bool isActive,
  }) async {
    await _firestoreService.updateDocument(
      path: _collection,
      docId: companyId,
      data: {
        'companyName': companyName.trim(),
        'companyAddress': companyAddress.trim(),
        'assignedLatitude': assignedLatitude,
        'assignedLongitude': assignedLongitude,
        'allowedRadius': allowedRadius,
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> setCompanyActive({
    required String companyId,
    required bool isActive,
  }) async {
    await _firestoreService.updateDocument(
      path: _collection,
      docId: companyId,
      data: {
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> deleteCompany(String companyId) async {
    await _firestoreService.deleteDocument(
      path: _collection,
      docId: companyId,
    );
  }
}