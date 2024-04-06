import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:performance_timer/performance_timer.dart';
import 'package:performance_timer/src/performance_timer_serializer_trace_event.dart';

Future<void> main() async {
  final rootTimer = PerformanceTimer(
    name: 'main',
    tags: {
      'externalId': '12345',
    },
  );

  // Wait for some calculations
  await Future.delayed(const Duration(milliseconds: 100));

  await calculationA(rootTimer.child('calculationA'));
  await calculationB(rootTimer.child('calculationB'));

  await Future.delayed(const Duration(milliseconds: 100));

  rootTimer.finish();

  // Vague trace representation, such as:
  // ----- TIMER RESULTS -----
  // Tags:
  // externalId = 12345
  // result = 3
  //
  // main - tot: 1s - own: 237ms
  // + calculationA - tot: 215ms - own: 215ms
  // + calculationB - tot: 546ms - own: 205ms
  // ++ calculationB2 - tot: 341ms - own: 341ms
  // -----------
  final stringSerializer = const PerformanceTimerSerializerString();
  print(await stringSerializer.serialize(rootTimer));

  // Export trace information as Trace Event Format, which is a standard
  // that's supported by many tracer analyzers, such as Google's Perfetto:
  // https://ui.perfetto.dev/
  final traceEventSerializer = const PerformanceTimerSerializerTraceEvent();
  final serializedTrace =
      jsonEncode(await traceEventSerializer.serialize(rootTimer));
  final file = File('./example_trace.json');
  file.openWrite();
  await file.writeAsString(serializedTrace);
}

Future<void> calculationA(PerformanceTimer timer) async {
  await Future.delayed(const Duration(milliseconds: 200));

  timer.finish();
}

Future<void> calculationB(PerformanceTimer timer) async {
  await Future.delayed(const Duration(milliseconds: 200));
  await calculationB2(timer.child('calculationB2'));

  timer.finish();
}

Future<void> calculationB2(PerformanceTimer timer) async {
  await Future.delayed(const Duration(milliseconds: 340));

  // Set new tag to root Timer
  timer.setTag('result', '3');

  timer.finish();
}
