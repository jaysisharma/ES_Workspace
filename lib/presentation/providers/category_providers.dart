import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final orderCategoriesStreamProvider = StreamProvider<List<String>>((ref) {
  return FirebaseFirestore.instance
      .collection('order_categories')
      .snapshots()
      .map((snapshot) {
        final cloudCategories = snapshot.docs.map((doc) => doc.id).toList();

        // Default categories that should always be available
        final defaults = ['Expo', 'Wedding', 'Exhibition'];

        // Combine and remove duplicates
        final all = {...defaults, ...cloudCategories}.toList();
        all.sort();
        return all;
      });
});

final categoryActionProvider = Provider((ref) => CategoryActions());

class CategoryActions {
  Future<void> addCategory(String category) async {
    final name = category.trim();
    if (name.isEmpty) return;

    await FirebaseFirestore.instance
        .collection('order_categories')
        .doc(name)
        .set({'name': name, 'createdAt': FieldValue.serverTimestamp()});
  }
}
