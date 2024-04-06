import 'dart:async';

import 'package:performance_timer/src/performance_timer.dart';

abstract class PerformanceTimerSerializer<T> {
  const PerformanceTimerSerializer();

  FutureOr<T> serialize(PerformanceTimer timer);
}
