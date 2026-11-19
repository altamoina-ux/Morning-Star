import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiminghat_tablet/core/camera_feeds.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final image = <int>[255, 216, 20, 30, 255, 217];
  ResponseBody frame() => ResponseBody.fromBytes(
    image,
    200,
    headers: {
      Headers.contentTypeHeader: ['image/jpeg'],
    },
  );
  Future<void> tick([int milliseconds = 20]) =>
      Future<void>.delayed(Duration(milliseconds: milliseconds));

  test('camera list and JPEG preview use the authenticated API', () async {
    final paths = <String>[];
    final api = mockApi((options, _) {
      paths.add(options.path);
      expect(options.headers['Authorization'], 'Bearer test-token');
      if (options.path == '/api/tablet/cameras') {
        return jsonBody([
          {'source_id': 'local_camera', 'label': '电脑网页摄像头', 'online': true},
          {'source_id': 'tablet_self', 'label': '本机', 'online': true},
        ]);
      }
      expect(options.responseType, ResponseType.bytes);
      return frame();
    });
    final feeds = CameraFeeds(api, 'tablet_self');
    addTearDown(() {
      feeds.dispose();
      api.dispose();
    });
    await feeds.refreshSources();
    expect(feeds.sources.keys, ['local_camera']);
    expect(feeds.sources['local_camera']!.online, isTrue);
    feeds.select('local_camera');
    await tick();
    expect(feeds.image, image);
    expect(feeds.status, '正在观看实时画面');
    expect(paths, contains('/api/tablet/cameras/local_camera/frame'));
  });

  test(
    'switching sources ignores late frames and never overlaps polling',
    () async {
      final pending = Completer<ResponseBody>();
      var calls = 0;
      final api = mockApi((options, _) {
        calls++;
        return pending.future;
      });
      final feeds = CameraFeeds(
        api,
        'tablet_self',
        pollInterval: const Duration(milliseconds: 5),
      );
      addTearDown(() {
        feeds.dispose();
        api.dispose();
      });
      feeds.select('local_camera');
      await tick(30);
      expect(calls, 1);
      feeds.select('tablet_self');
      pending.complete(frame());
      await tick();
      expect(feeds.image, isNull);
      expect(feeds.isLocal, isTrue);
      expect(calls, 1);
    },
  );

  test(
    'a stopped camera clears its image and recovers on a new frame',
    () async {
      var stopped = false;
      final api = mockApi(
        (options, _) =>
            stopped ? jsonBody({'detail': 'stopped'}, status: 410) : frame(),
      );
      final feeds = CameraFeeds(
        api,
        'tablet_self',
        pollInterval: const Duration(milliseconds: 10),
      );
      addTearDown(() {
        feeds.dispose();
        api.dispose();
      });
      feeds.select('local_camera');
      await tick();
      expect(feeds.image, image);
      stopped = true;
      await tick(35);
      expect(feeds.image, isNull);
      expect(feeds.status, contains('请先在电脑网页端启动摄像头'));
      stopped = false;
      await tick(35);
      expect(feeds.image, image);
    },
  );

  test('a stalled network cannot leave a frozen scene on screen', () async {
    final pending = Completer<ResponseBody>();
    var calls = 0;
    final api = mockApi(
      (options, _) => ++calls == 1 ? frame() : pending.future,
    );
    final feeds = CameraFeeds(
      api,
      'tablet_self',
      pollInterval: const Duration(milliseconds: 5),
      freshnessLimit: const Duration(milliseconds: 35),
    );
    addTearDown(() {
      feeds.dispose();
      api.dispose();
    });
    feeds.select('local_camera');
    await tick(15);
    expect(feeds.image, image);
    await tick(50);
    expect(calls, 2);
    expect(feeds.image, isNull);
    expect(feeds.status, contains('画面已中断'));
    feeds.pause();
    pending.complete(frame());
    await tick();
    expect(feeds.image, isNull);
  });

  test(
    'manual pause and background suspend requests without changing the source',
    () async {
      var calls = 0;
      final api = mockApi((options, _) {
        if (options.path == '/api/tablet/cameras') return jsonBody([]);
        calls++;
        return frame();
      });
      final feeds = CameraFeeds(
        api,
        'tablet_self',
        pollInterval: const Duration(milliseconds: 10),
      );
      addTearDown(() {
        feeds.dispose();
        api.dispose();
      });
      feeds.select('local_camera');
      await tick();
      feeds.pause();
      final pausedCalls = calls;
      await tick(35);
      expect(calls, pausedCalls);
      expect(feeds.image, isNull);
      feeds.resume();
      await tick();
      expect(calls, greaterThan(pausedCalls));
      feeds.setActive(false);
      final backgroundCalls = calls;
      await tick(35);
      expect(calls, backgroundCalls);
      expect(feeds.image, isNull);
      feeds.setActive(true);
      await tick();
      expect(calls, greaterThan(backgroundCalls));
      expect(feeds.source, 'local_camera');
    },
  );
}
