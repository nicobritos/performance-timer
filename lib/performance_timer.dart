/// A timer and utils to count time spent on methods and calculations.
///
/// It allows to track own and total time spent, nest timers and
/// serialize them to String or TraceEventFormat
library performance_timer;

export 'src/performance_timer.dart';
export 'src/performance_timer_serializer.dart';
export 'src/performance_timer_serializer_string.dart';
export 'src/performance_timer_serializer_trace_event.dart';
