import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:performance_timer/performance_timer.dart';

Future<void> main() async {
  final rootTimer = PerformanceTimer(
    name: 'main',
    tags: {
      'externalId': '12345',
    },
    category: 'root',
  );

  // Wait for some calculations
  await Future.delayed(const Duration(milliseconds: 100));

  await calculationA(rootTimer.child('calculationA'));
  await calculationB(rootTimer.child('calculationB'));

  await Future.delayed(const Duration(milliseconds: 100));

  final result = await rootTimer.measure('measure', (child) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return child.measure('data', (_) => 1);
  });

  // 1
  print(result);

  rootTimer.finish();

  // Vague trace representation, such as:
  // ----- TIMER RESULTS -----
  // Tags:
  // externalId = 12345
  // result = 3
  //
  // main - tot: 985ms - own: 221ms - root
  // + calculationA - tot: 204ms - own: 204ms - root
  // + calculationB - tot: 558ms - own: 202ms - root
  // ++ calculationB2 - tot: 356ms - own: 356ms - B2
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
  await calculationB2(timer.child('calculationB2', category: 'B2'));

  timer.finish();
}

Future<void> calculationB2(PerformanceTimer timer) async {
  await Future.delayed(const Duration(milliseconds: 340));

  // Set new tag to root Timer
  timer.setTag('result', '3');

  timer.finish();
}
