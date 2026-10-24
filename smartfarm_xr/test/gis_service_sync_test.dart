import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_xr/features/dashboard/data/gis_service.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Future<Map<String, dynamic>> Function(Map<String, dynamic> body)
      handler;
  final List<Map<String, dynamic>> requests = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    Map<String, dynamic> body =
        Map<String, dynamic>.from(options.data as Map<dynamic, dynamic>);
    requests.add(body);
    Map<String, dynamic> response = await handler(body);
    return ResponseBody.fromString(jsonEncode(response), 200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        });
  }

  @override
  void close({bool force = false}) {}
}

GisService _service(_FakeAdapter adapter) {
  Dio dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'));
  dio.httpClientAdapter = adapter;
  return GisService(dio: dio);
}

List<String> _opTypes(Map<String, dynamic> body) => (body['ops'] as List)
    .map((dynamic op) => (op as Map)['type'].toString())
    .toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('awaited enqueue is included in the next sync and then cleared',
      () async {
    _FakeAdapter adapter = _FakeAdapter((_) async =>
        <String, dynamic>{'status': 'ok', 'version': 1, 'map': <dynamic>[]});
    GisService service = _service(adapter);

    await service.islemKuyrugunaEkle('add_asset', <String, dynamic>{'a': 1});
    await service.bekleyenIslemleriSenkronizeEt();

    expect(adapter.requests, hasLength(1));
    expect(_opTypes(adapter.requests.single), <String>['add_asset']);
    expect(await service.bekleyenIslemleriGetir(), isEmpty);
  });

  test('ops queued while a sync is in flight are not wiped by its ack',
      () async {
    late GisService service;
    bool ilkIstek = true;
    _FakeAdapter adapter = _FakeAdapter((_) async {
      if (ilkIstek) {
        ilkIstek = false;
        await service.islemKuyrugunaEkle(
            'update_asset', <String, dynamic>{'asset_id': 'x'});
      }
      return <String, dynamic>{'status': 'ok', 'version': 1, 'map': <dynamic>[]};
    });
    service = _service(adapter);

    await service.islemKuyrugunaEkle('add_asset', <String, dynamic>{});
    await service.bekleyenIslemleriSenkronizeEt();

    List<Map<String, dynamic>> kalan = await service.bekleyenIslemleriGetir();
    expect(kalan.map((Map<String, dynamic> op) => op['type']),
        <String>['update_asset']);

    await service.bekleyenIslemleriSenkronizeEt();
    expect(_opTypes(adapter.requests.last), <String>['update_asset']);
    expect(await service.bekleyenIslemleriGetir(), isEmpty);
  });

  test('concurrent sync calls never send the same op twice', () async {
    _FakeAdapter adapter = _FakeAdapter((_) async =>
        <String, dynamic>{'status': 'ok', 'version': 1, 'map': <dynamic>[]});
    GisService service = _service(adapter);

    await service.islemKuyrugunaEkle('add_asset', <String, dynamic>{});
    await Future.wait(<Future<dynamic>>[
      service.bekleyenIslemleriSenkronizeEt(),
      service.bekleyenIslemleriSenkronizeEt(),
    ]);

    expect(adapter.requests, hasLength(1));
  });

  test('version conflict keeps the queue and retries with the new version',
      () async {
    _FakeAdapter adapter = _FakeAdapter((Map<String, dynamic> body) async {
      if (body['base_version'] != 7) {
        return <String, dynamic>{
          'status': 'conflict',
          'version': 7,
          'map': <dynamic>[],
        };
      }
      return <String, dynamic>{'status': 'ok', 'version': 8, 'map': <dynamic>[]};
    });
    SharedPreferences.setMockInitialValues(
        <String, Object>{'sync_server_version': '3'});
    GisService service = _service(adapter);

    await service.islemKuyrugunaEkle('add_asset', <String, dynamic>{});
    await service.bekleyenIslemleriSenkronizeEt();

    expect(adapter.requests.map((Map<String, dynamic> b) => b['base_version']),
        <int>[3, 7]);
    expect(service.sonSenkronDurumu, 'ok');
    expect(await service.bekleyenIslemleriGetir(), isEmpty);
  });

  test('client op ids are unique even when enqueued in the same microsecond',
      () async {
    GisService service = _service(_FakeAdapter((_) async => <String, dynamic>{}));
    await Future.wait(<Future<void>>[
      for (int i = 0; i < 20; i++)
        service.islemKuyrugunaEkle('add_asset', <String, dynamic>{'i': i}),
    ]);
    List<Map<String, dynamic>> kuyruk = await service.bekleyenIslemleriGetir();
    expect(kuyruk, hasLength(20));
    expect(kuyruk.map((Map<String, dynamic> op) => op['client_op_id']).toSet(),
        hasLength(20));
  });
}
