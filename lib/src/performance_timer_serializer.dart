import 'dart:async';

import 'package:performance_timer/src/performance_timer.dart';

/// [PerformanceTimerSerializer] allows you to serialize and dump
/// a [PerformanceTimer] result, including their children.
abstract class PerformanceTimerSerializer<T> {
  const PerformanceTimerSerializer();

  FutureOr<T> serialize(PerformanceTimer timer);
}
