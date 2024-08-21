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
  late final Timer _timer;

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
  }) {
    _timer = Timer.periodic(exportEvery, (_) => _export());
  }

  void add(PerformanceTimer timer) {
    unawaited(_add(timer));
  }

  void dispose() {
    _timer.cancel();
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
    final timerBatches = quiver.partition(timers, maxGroupSize).map((e) => serializer.serializeGroup(e)).toList();

    for (final batch in timerBatches) {
      final body = json.encode(await batch);

      bool send = false;
      int sentTimes = 0;
      while (!send && sentTimes < maxAttempts) {
        try {
          sentTimes++;

          final r = await _client
              .post(
                endpoint,
                headers: {'Content-Type': 'application/json'},
                body: body,
              )
              .timeout(timeout);

          if (r.statusCode >= 200 && r.statusCode < 300) {
            send = true;
          } else {
            await Future.delayed(retryInterval);
          }
        } catch (_) {
          await Future.delayed(retryInterval);
        }
      }
    }
  }
}
