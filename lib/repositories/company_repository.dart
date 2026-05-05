import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/company_model.dart';
import '../services/firestore_service.dart';

class CompanyRepository {
  final FirestoreService _firestoreService;

  CompanyRepository({FirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? FirestoreService();

  static const String collectionPath = 'companies';
  static const String usersCollectionPath = 'users';

  Stream<List<CompanyModel>> streamCompanies({bool activeOnly = false}) {
    return _firestoreService.collection(collectionPath).snapshots().map((
      snapshot,
    ) {
      final companies = snapshot.docs
          .map((doc) => CompanyModel.fromMap(doc.data(), id: doc.id))
          .where((company) => !activeOnly || company.isActive)
          .toList();

      _sortCompaniesByName(companies);

      return companies;
    });
  }

  Future<List<CompanyModel>> getActiveCompanies() async {
    final snapshot = await _firestoreService.collection(collectionPath).get();

    final companies = snapshot.docs
        .map((doc) => CompanyModel.fromMap(doc.data(), id: doc.id))
        .where((company) => company.isActive)
        .toList();

    _sortCompaniesByName(companies);

    return companies;
  }

  Future<CompanyModel?> getCompanyById(String companyId) async {
    if (companyId.trim().isEmpty) return null;

    final doc = await _firestoreService
        .collection(collectionPath)
        .doc(companyId)
        .get();

    final data = doc.data();

    if (!doc.exists || data == null) return null;

    return CompanyModel.fromMap(data, id: doc.id);
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
    );

    return _firestoreService.addDocument(
      path: collectionPath,
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
    final cleanedCompanyName = companyName.trim();
    final cleanedCompanyAddress = companyAddress.trim();

    final companyUpdateData = {
      'companyName': cleanedCompanyName,
      'companyAddress': cleanedCompanyAddress,
      'assignedLatitude': assignedLatitude,
      'assignedLongitude': assignedLongitude,
      'allowedRadius': allowedRadius,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // 1. Update the company document itself.
    await _firestoreService.updateDocument(
      path: collectionPath,
      docId: companyId,
      data: companyUpdateData,
    );

    // 2. Also update all interns/users assigned to this company.
    //
    // Reason:
    // User Management, Timer, and Live Monitoring currently read copied
    // company/geofence fields from users/{internUid}. If the company radius
    // changes only in companies/{companyId}, assigned interns would still show
    // the old radius unless their user documents are synced too.
    final assignedUsersSnapshot = await _firestoreService
        .collection(usersCollectionPath)
        .where('companyId', isEqualTo: companyId)
        .get();

    if (assignedUsersSnapshot.docs.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();

    for (final userDoc in assignedUsersSnapshot.docs) {
      batch.update(userDoc.reference, {
        'companyId': companyId,
        'companyName': cleanedCompanyName,
        'companyAddress': cleanedCompanyAddress,
        'assignedLatitude': assignedLatitude,
        'assignedLongitude': assignedLongitude,
        'allowedRadius': allowedRadius,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<void> setCompanyActive({
    required String companyId,
    required bool isActive,
  }) async {
    await _firestoreService.updateDocument(
      path: collectionPath,
      docId: companyId,
      data: {'isActive': isActive, 'updatedAt': FieldValue.serverTimestamp()},
    );
  }

  Future<void> deleteCompany(String companyId) async {
    await _firestoreService.deleteDocument(
      path: collectionPath,
      docId: companyId,
    );
  }

  void _sortCompaniesByName(List<CompanyModel> companies) {
    companies.sort(
      (a, b) =>
          a.companyName.toLowerCase().compareTo(b.companyName.toLowerCase()),
    );
  }
}
