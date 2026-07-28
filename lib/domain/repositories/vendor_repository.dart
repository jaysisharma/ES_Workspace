import '../entities/vendor_entity.dart';

abstract class VendorRepository {
  Future<List<VendorEntity>> getAllVendors();
  Future<void> addVendor(VendorEntity vendor);
  Future<void> updateVendor(VendorEntity vendor);
  Future<void> deleteVendor(String id);
}
