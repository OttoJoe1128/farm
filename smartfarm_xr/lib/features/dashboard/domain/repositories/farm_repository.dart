abstract class FarmRepository {
  Future<List<dynamic>?> haritayiGetir();
  Future<List<dynamic>?> bekleyenIslemleriSenkronizeEt();
  Future<void> islemKuyrugunaEkle(String type, Map<String, dynamic> payload);
  Future<List<dynamic>?> sahaVerisiniIceriAktar({
    required List<Map<String, dynamic>> features,
    required List<Map<String, dynamic>> gpsPoints,
    Map<String, dynamic>? tkgmContext,
  });
  Future<Map<String, dynamic>?> isEmriOlustur({
    required String assetId,
    required String title,
    String description,
    String assignee,
    String priority,
    String? dueAt,
  });
  Future<List<Map<String, dynamic>>> isEmirleriniGetir();
  Future<Map<String, dynamic>?> isEmriGuncelle({
    required String workOrderId,
    String? status,
    String? assignee,
    String? note,
  });
  Future<Map<String, dynamic>?> telemetryGonder({
    required String assetId,
    required String deviceId,
    required Map<String, dynamic> metrics,
    String? measuredAt,
  });
  Future<List<Map<String, dynamic>>> alarmListesiniGetir();
  Future<Map<String, dynamic>?> kpiGetir();
  Future<Map<String, dynamic>?> erpSenkronBaslat({String connector});
}
