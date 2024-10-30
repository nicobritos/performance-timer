import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:meta/meta.dart';
import 'package:performance_timer/src/performance_timer.dart';
import 'package:performance_timer/src/performance_timer_serializer.dart';

/// Serializes a root [PerformanceTimer] to [TraceEvents] format, making it
/// possible to analyze it using tools like Google's Perfetto.
///
/// https://docs.google.com/document/d/1CvAClvFfyA5R-PhYUmn5OOQtYMH4h6I0nSsKchNAySU/preview#heading=h.jh64i9l3vwa1
///
/// This allows you to analyze the traces with several tools like
/// https://ui.perfetto.dev/
class PerformanceTimerSerializerOtel
    extends PerformanceTimerSerializer<Map<String, dynamic>> {
  const PerformanceTimerSerializerOtel();

  @override
  FutureOr<Map<String, dynamic>> serialize(PerformanceTimer timer) {
    return serializeGroup([timer]);
  }

  FutureOr<Map<String, dynamic>> serializeGroup(List<PerformanceTimer> timers) {
    final timersByResource = <String, List<PerformanceTimer>>{};
    for (final timer in timers) {
      final resource = timer.keyName;
      timersByResource.putIfAbsent(resource, () => []).add(timer);
    }

    final traces = <Map<String, dynamic>>[];
    final otelTraces = {'resourceSpans': traces};

    for (final timerGroup in timersByResource.values) {
      traces.add(_serializeGroup(timerGroup));
    }

    return otelTraces;
  }

  @protected
  List<Map<String, dynamic>> attributesOfTimer(PerformanceTimer timer,
      {required bool isRoot}) {
    return [
      if (timer.errorMessage != null)
        {
          'key': 'exception.message',
          'value': {'stringValue': timer.errorMessage!},
        },
      if (timer.errorType != null)
        {
          'key': 'exception.type',
          'value': {'stringValue': timer.errorType!},
        }
    ];
  }

  @protected
  List<Map<String, dynamic>> attributesOfGroup(List<PerformanceTimer> group) {
    return [];
  }

  @protected
  List<Map<String, dynamic>> statusAttributes(PerformanceTimer timer) {
    return [
      {
        'key': 'otel.status_code',
        'value': {'stringValue': timer.success ? 'OK' : 'ERROR'},
      },
    ];
  }

  Map<String, dynamic> _serializeGroup(List<PerformanceTimer> group) {
    final spans = <Map<String, dynamic>>[];
    final otelTrace = {
      'resource': {
        'attributes': [
          {
            'key': 'service.name',
            'value': {'stringValue': group.first.serviceName}
          },
          ...attributesOfGroup(group),
        ]
      },
      'scopeSpans': [
        {
          'scope': {
            'name': group.first.scopeName,
            'version': group.first.versionName,
            'attributes': []
          },
          'spans': spans,
        }
      ]
    };

    for (final timer in group) {
      final traceId = _generateTraceId(timer);
      _serializeTimer(timer, spans, traceId);
    }

    return otelTrace;
  }

  void _serializeTimer(
    PerformanceTimer timer,
    List<Map<String, dynamic>> spans,
    String traceId, [
    String? parentSpanId,
  ]) {
    final spanId = _generateSpanId(timer);

    final isRoot = parentSpanId == null;
    final attributes = attributesOfTimer(timer, isRoot: isRoot);
    if (isRoot) {
      attributes.addAll(statusAttributes(timer));
    }

    spans.add({
      'name': timer.spanName,
      'spanId': spanId,
      'traceId': traceId,
      if (!isRoot) 'parentSpanId': parentSpanId,
      if (attributes.isNotEmpty) 'attributes': attributes,
      'startTimeUnixNano': timer.startAt.nanoSecondsSinceEpoch.toString(),
      'endTimeUnixNano': timer.startAt
          .add(timer.realDuration)
          .nanoSecondsSinceEpoch
          .toString(),
    });

    for (final child in timer.children) {
      _serializeTimer(child, spans, traceId, spanId);
    }
  }

  String _generateTraceId(PerformanceTimer timer) {
    return timer.root.id;
  }

  String _generateSpanId(PerformanceTimer timer) {
    return timer.id.substring(0, 16);
  }
}

extension _DateTimeNano on DateTime {
  Int64 get nanoSecondsSinceEpoch => Int64(microsecondsSinceEpoch) * 1000;
}

extension _PTExtension on PerformanceTimer {
  String get serviceName => tags['service'] ?? '';

  String get scopeName => tags['scope'] ?? '';

  String get keyName => '$serviceName-$scopeName';

  String get versionName => tags['version'] ?? '';

  String get spanName => name;
}
