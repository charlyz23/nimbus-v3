import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nimbus/data/offline_map_store.dart';
import 'package:nimbus/data/town_pack.dart';
import 'package:nimbus/ui/storm_map.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('nimbus-map-test-');
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('reports an unsuccessful map download and removes partial data',
      () async {
    final store = OfflineMapStore(
      clientFactory: () => MockClient(
        (_) async =>
            http.Response('unavailable', HttpStatus.serviceUnavailable),
      ),
      directoryProvider: () async => directory,
    );

    await expectLater(
      store.download(onProgress: (_, __) {}),
      throwsA(isA<HttpException>()),
    );

    expect(
      await File('${directory.path}/${OfflineMapStore.mapFileName}.download')
          .exists(),
      isFalse,
    );
    store.dispose();
  });

  testWidgets('renders the first-run offline map screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StormMap(town: towns.first, tab: 'Q'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Offline Philippines map'), findsOneWidget);
  });
}
