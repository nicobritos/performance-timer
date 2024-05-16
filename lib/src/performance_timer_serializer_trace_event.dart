import 'package:performance_timer/src/performance_timer.dart';
import 'package:performance_timer/src/performance_timer_serializer.dart';

typedef TraceEvent = Map<String, dynamic>;

/// Serializes a root [PerformanceTimer] to [TraceEvents] format, making it
/// possible to analyze it using tools like Google's Perfetto.
///
/// https://docs.google.com/document/d/1CvAClvFfyA5R-PhYUmn5OOQtYMH4h6I0nSsKchNAySU/preview#heading=h.jh64i9l3vwa1
///
/// This allows you to analyze the traces with several tools like
/// https://ui.perfetto.dev/
class PerformanceTimerSerializerTraceEvent
    extends PerformanceTimerSerializer<TraceEvent> {
  const PerformanceTimerSerializerTraceEvent();

  @override
  TraceEvent serialize(PerformanceTimer timer) {
    if (!timer.isRoot) {
      throw StateError('The timer to serialize should be the parent');
    }

    final TraceEvent data = {};

    data['traceEvents'] = _serializeTraceEvents(timer);
    data['stackFrames'] = _serializeStackFrames(timer);

    return data;
  }

  List<Map<String, dynamic>> _serializeTraceEvents(PerformanceTimer timer) {
    final events = <Map<String, dynamic>>[];

    events.add(_serializeTraceEvent(timer));

    for (final child in timer.children) {
      events.addAll(_serializeTraceEvents(child));
    }

    return events;
  }

  Map<String, dynamic> _serializeTraceEvent(PerformanceTimer timer) {
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
      },
      "sf": timer.id
    };

    if (timer.category != null) {
      data["cat"] = timer.category!;
    }

    return data;
  }

  Map<String, dynamic> _serializeStackFrames(PerformanceTimer timer) {
    final stacks = <String, dynamic>{};

    stacks[timer.id] = _serializeStackFrame(timer);

    for (final child in timer.children) {
      stacks.addAll(_serializeStackFrames(child));
    }

    return stacks;
  }

  Map<String, dynamic> _serializeStackFrame(PerformanceTimer timer) {
    final Map<String, dynamic> data = {"name": timer.name};
    if (timer.category != null) {
      data["category"] = timer.category;
    }
    if (timer.parent != null) {
      data["parent"] = timer.parent!.id;
    }

    return {timer.id: data};
  }
}
