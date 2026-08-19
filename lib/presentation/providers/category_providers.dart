import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final orderCategoriesStreamProvider = StreamProvider<List<String>>((ref) {
  final firestore = FirebaseFirestore.instance;

  return firestore.collection('order_categories').snapshots().map((snapshot) {
    if (snapshot.docs.isEmpty) {
      // First time initialization: seed default categories into Firestore
      // so they become real, deletable documents
      _seedDefaultCategories(firestore);
      return <String>['Exhibition', 'Expo', 'Wedding'];
    }

    final categories = snapshot.docs
        .map((doc) {
          final data = doc.data();
          final name = data['name'] as String?;
          return (name != null && name.trim().isNotEmpty) ? name.trim() : doc.id;
        })
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();

    categories.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return categories;
  });
});

bool _isSeeding = false;
Future<void> _seedDefaultCategories(FirebaseFirestore firestore) async {
  if (_isSeeding) return;
  _isSeeding = true;
  try {
    final snap = await firestore.collection('order_categories').limit(1).get();
    if (snap.docs.isEmpty) {
      final batch = firestore.batch();
      for (final cat in ['Exhibition', 'Expo', 'Wedding']) {
        final docRef = firestore.collection('order_categories').doc(cat);
        batch.set(docRef, {
          'name': cat,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  } catch (_) {
    // Graceful fallback
  } finally {
    _isSeeding = false;
  }
}

final categoryActionProvider = Provider((ref) => CategoryActions());

class CategoryActions {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addCategory(String category) async {
    final name = category.trim();
    if (name.isEmpty) return;

    await _firestore
        .collection('order_categories')
        .doc(name)
        .set({'name': name, 'createdAt': FieldValue.serverTimestamp()});
  }

  Future<void> deleteCategory(String category) async {
    final name = category.trim();
    if (name.isEmpty) return;

    try {
      // 1. Direct delete by ID
      await _firestore.collection('order_categories').doc(name).delete();

      // 2. Query and delete any case-insensitive or name-matched documents
      final snapshot = await _firestore.collection('order_categories').get();
      for (final doc in snapshot.docs) {
        final docName = doc.data()['name'] as String? ?? doc.id;
        if (doc.id.toLowerCase().trim() == name.toLowerCase() ||
            docName.toLowerCase().trim() == name.toLowerCase()) {
          await doc.reference.delete();
        }
      }
    } catch (_) {}
  }
}
