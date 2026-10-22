import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test_do_an/venues/venue_map_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Failed lookup finishes and can be retried instead of retaining a pending future', () async {
    var calls = 0;
    final service = VenueMapService(
      client: MockClient((_) async {
        calls++;
        return http.Response(
          calls == 1
              ? '[]'
              : jsonEncode([
                  {'lat': '10.81', 'lon': '106.63', 'place_rank': 30},
                ]),
          200,
        );
      }),
    );
    expect(await service.locateAddress('missing'), isNull);
    expect((await service.locateAddress('missing'))!.latitude, 10.81);
    expect(calls, 2);
  });
  test(
    'Online geocoder uses VN, app identity, shared lookup and cache',
    () async {
      var calls = 0;
      final service = VenueMapService(
        client: MockClient((request) async {
          calls++;
          expect(request.url.queryParameters['countrycodes'], 'vn');
          expect(request.headers['User-Agent'], contains('NVHSportsDemo'));
          return http.Response(
            jsonEncode([
              {
                'lat': '10.81',
                'lon': '106.63',
                'place_rank': 30,
                'display_name': 'Test venue',
              },
            ]),
            200,
          );
        }),
      );
      final first = service.locateAddress('140 Lê Trọng Tấn, TP.HCM');
      final second = service.locateAddress('140 Lê Trọng Tấn, TP.HCM');
      expect((await first)!.latitude, 10.81);
      expect((await second)!.longitude, 106.63);
      await service.locateAddress('140 Lê Trọng Tấn, TP.HCM');
      expect(calls, 1);
      expect(service.isApproximate('140 Lê Trọng Tấn, TP.HCM'), isFalse);
    },
  );
  test(
    'Missing house number falls back to road and is explicitly approximate',
    () async {
      final queries = <String>[];
      final service = VenueMapService(
        client: MockClient((request) async {
          queries.add(request.url.queryParameters['q']!);
          return http.Response(
            queries.length == 1
                ? '[]'
                : jsonEncode([
                    {
                      'lat': '10.8075981',
                      'lon': '106.6292853',
                      'place_rank': 26,
                      'display_name': 'Đường Nguyễn Đỗ Cung',
                    },
                  ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      const address = '73/1 Nguyễn Đỗ Cung, Tây Thạnh, TP.HCM';
      expect((await service.locateAddress(address))!.latitude, 10.8075981);
      expect(queries.last, 'Nguyen Do Cung, Ho Chi Minh');
      expect(service.isApproximate(address), isTrue);
      expect(service.addressLabel(address), 'Đường Nguyễn Đỗ Cung');
    },
  );
}
