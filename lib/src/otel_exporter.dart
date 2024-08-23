import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:performance_timer/performance_timer.dart';
import 'package:quiver/iterables.dart' as quiver;

class OtelExporter {
  final Uri endpoint;
  final Duration exportEvery;
  final Duration timeout;
  final Duration retryInterval;
  final int maxAttempts;
  final int maxGroupSize;
  final int maxQueueSize;
  final double sendFactor;
  final PerformanceTimerSerializerOtel serializer;
  final Queue<PerformanceTimer> _queue = Queue();
  final http.Client _client = http.Client();
  final Map<String, String> _headers = {};
  Timer? _timer;
  bool _active = false;

  OtelExporter({
    required this.endpoint,
    this.exportEvery = const Duration(minutes: 5),
    this.timeout = const Duration(seconds: 20),
    this.retryInterval = const Duration(minutes: 1),
    this.maxAttempts = 5,
    this.maxGroupSize = 5,
    this.maxQueueSize = 20,
    this.sendFactor = 1.0,
    this.serializer = const PerformanceTimerSerializerOtel(),
    bool startPaused = false,
  }) {
    if (!startPaused) {
      resume();
    }
  }

  void addHeader(String key, String value) {
    _headers[key] = value;
  }

  void removeHeader(String key) {
    _headers.remove(key);
  }

  void resume() {
    _active = true;
    _timer = Timer.periodic(exportEvery, (_) => _export());
  }

  void pause() {
    _active = false;
    _timer?.cancel();
    _timer = null;
  }

  void add(PerformanceTimer timer) {
    unawaited(_add(timer));
  }

  void dispose() {
    _timer?.cancel();
    _client.close();
  }

  Future<void> _add(PerformanceTimer timer) async {
    _queue.add(timer);
    if (_queue.length >= maxQueueSize) {
      _export();
    }
  }

  void _export() {
    if (_queue.isEmpty) {
      return;
    }

    final timers = _queue.toList(growable: true);
    _queue.clear();

    unawaited(_send(timers));
  }

  Future<void> _send(List<PerformanceTimer> timers) async {
    final timerBatches = quiver.partition(timers, maxGroupSize).toList();
    final serializedBatches = timerBatches.map((e) => serializer.serializeGroup(e)).toList();
    final unsentTimers = <PerformanceTimer>[];

    for (int i = 0; i < serializedBatches.length; i++) {
      final batch = serializedBatches[i];
      final body = json.encode(await batch);

      bool sent = false;
      int sentTimes = 0;
      while (!sent && sentTimes < maxAttempts && _active) {
        try {
          sentTimes++;

          final r = await _client
              .post(
                endpoint,
                headers: {
                  ..._headers,
                  'Content-Type': 'application/json',
                },
                body: body,
              )
              .timeout(timeout);

          if (r.statusCode >= 200 && r.statusCode < 300) {
            sent = true;
          } else {
            await Future.delayed(retryInterval);
          }
        } catch (_) {
          await Future.delayed(retryInterval);
        }
      }

      // Timers not processed due to not exporter not active
      if (!sent && !_active) {
        unsentTimers.addAll(timerBatches[i]);
      }
    }

    _queue.addAll(unsentTimers);
  }
}
