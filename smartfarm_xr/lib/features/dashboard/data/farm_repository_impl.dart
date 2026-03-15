import '../domain/repositories/farm_repository.dart';
import 'gis_service.dart';

class FarmRepositoryImpl implements FarmRepository {
  final GisService _gisService;

  FarmRepositoryImpl(this._gisService);

  @override
  Future<List<dynamic>?> haritayiGetir() => _gisService.haritayiGetir();

  @override
  Future<List<dynamic>?> bekleyenIslemleriSenkronizeEt() =>
      _gisService.bekleyenIslemleriSenkronizeEt();

  @override
  Future<void> islemKuyrugunaEkle(String type, Map<String, dynamic> payload) =>
      _gisService.islemKuyrugunaEkle(type, payload);

  @override
  Future<List<dynamic>?> sahaVerisiniIceriAktar({
    required List<Map<String, dynamic>> features,
    required List<Map<String, dynamic>> gpsPoints,
    Map<String, dynamic>? tkgmContext,
  }) {
    return _gisService.sahaVerisiniIceriAktar(
      features: features,
      gpsPoints: gpsPoints,
      tkgmContext: tkgmContext,
    );
  }

  @override
  Future<Map<String, dynamic>?> isEmriOlustur({
    required String assetId,
    required String title,
    String description = '',
    String assignee = '',
    String priority = 'normal',
    String? dueAt,
  }) {
    return _gisService.isEmriOlustur(
      assetId: assetId,
      title: title,
      description: description,
      assignee: assignee,
      priority: priority,
      dueAt: dueAt,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> isEmirleriniGetir() =>
      _gisService.isEmirleriniGetir();

  @override
  Future<Map<String, dynamic>?> isEmriGuncelle({
    required String workOrderId,
    String? status,
    String? assignee,
    String? note,
  }) {
    return _gisService.isEmriGuncelle(
      workOrderId: workOrderId,
      status: status,
      assignee: assignee,
      note: note,
    );
  }

  @override
  Future<Map<String, dynamic>?> telemetryGonder({
    required String assetId,
    required String deviceId,
    required Map<String, dynamic> metrics,
    String? measuredAt,
  }) {
    return _gisService.telemetryGonder(
      assetId: assetId,
      deviceId: deviceId,
      metrics: metrics,
      measuredAt: measuredAt,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> alarmListesiniGetir() =>
      _gisService.alarmListesiniGetir();

  @override
  Future<Map<String, dynamic>?> kpiGetir() => _gisService.kpiGetir();

  @override
  Future<Map<String, dynamic>?> erpSenkronBaslat(
          {String connector = 'generic'}) =>
      _gisService.erpSenkronBaslat(connector: connector);
}
