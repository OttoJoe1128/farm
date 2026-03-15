import 'package:riverpod/riverpod.dart';
import '../../data/farm_repository_impl.dart';
import '../../data/gis_service.dart';
import '../../domain/repositories/farm_repository.dart';

final gisServiceProvider = Provider<GisService>((Ref ref) {
  return GisService();
});

final farmRepositoryProvider = Provider<FarmRepository>((Ref ref) {
  return FarmRepositoryImpl(ref.watch(gisServiceProvider));
});
