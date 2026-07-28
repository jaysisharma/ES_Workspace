import '../entities/event_pass_entity.dart';

abstract class EventPassRepository {
  Future<List<EventPassEntity>> getAllPasses();
  Future<void> addPass(EventPassEntity pass);
  Future<void> deletePass(String id);
  Future<EventPassEntity?> getPassById(String id);
  Future<void> redeemService(String passId, String serviceName);
  Future<List<String>> getAvailableServices();
  Future<void> saveAvailableService(String serviceName);
  Future<void> deleteAvailableService(String serviceName);
  Future<String> getSecuritySalt();
}
