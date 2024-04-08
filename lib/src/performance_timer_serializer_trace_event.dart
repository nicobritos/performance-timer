import 'dart:async';

import 'package:performance_timer/src/performance_timer.dart';
import 'package:performance_timer/src/performance_timer_serializer.dart';

typedef TraceEvent = Map<String, dynamic>;
typedef TraceEvents = List<TraceEvent>;

/// Serializes a root [PerformanceTimer] to [TraceEvents] format, making it
/// possible to analyze it using tools like Google's Perfetto.
///
/// https://docs.google.com/document/d/1CvAClvFfyA5R-PhYUmn5OOQtYMH4h6I0nSsKchNAySU/preview#heading=h.jh64i9l3vwa1
///
/// This allows you to analyze the traces with several tools like
/// https://ui.perfetto.dev/
class PerformanceTimerSerializerTraceEvent
    extends PerformanceTimerSerializer<TraceEvents> {
  const PerformanceTimerSerializerTraceEvent();

  @override
  FutureOr<TraceEvents> serialize(PerformanceTimer timer) {
    if (!timer.isRoot) {
      throw StateError('The timer to serialize should be the parent');
    }

    final TraceEvents events = [];

    _serializeTraceEvents(timer, events);

    return events;
  }

  void _serializeTraceEvents(PerformanceTimer timer, TraceEvents events) {
    events.add(_serializeTraceEvent(timer));

    for (final child in timer.children) {
      _serializeTraceEvents(child, events);
    }
  }

  TraceEvent _serializeTraceEvent(PerformanceTimer timer) {
    final data = {
      "name": timer.name,
      "ph": "X",
      "ts": timer.relativeStartAt.inMicroseconds,
      "dur": timer.realDuration.inMicroseconds,
      "pid": 0,
      "tid": timer.threadId,
      "args": {
        ...timer.tags,
        "ownTimeMs": timer.ownDuration.inMilliseconds,
      }
    };

    if (timer.category != null) {
      data["cat"] = timer.category!;
    }

    return data;
  }
}
