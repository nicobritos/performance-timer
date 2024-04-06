# Performance Timer
Performance Timer is a package that allows you to time function and method
calls, allowing for nesting/children timers, real and own time spent inside
each timer.

Also allows for printing the results and exporting them to Trace Event Format,
which can then be parsed and analyzed by a lot of Trace analyzers, like
Google Perfetto (https://ui.perfetto.dev/)

## Features
* Track time spent inside a method with `timer.ownDuration` and `timer.child`
* Track all time spent in all methods with `timer.realDuration`
* Store additional data linked to each timer with `timer.setTag`
* Print results with `PerformanceTimerSerializerString`
* Export results to TraceEventFormat with `PerformanceTimerSerializerTraceEvent`

## Usage

* Create a timer
```dart
final timer = PerformanceTimer(name: 'rootTimer', tags: {'key': 'value'});
// Do some work
timer.finish()
```

* Serialize the results
```dart
const stringSerializer = PerformanceTimerSerializerString();
print(await stringSerializer.serialize(timer));

const traceEventSerializer = PerformanceTimerSerializerTraceEvent();
print(jsonEncode(await traceEventSerializer.serialize(timer)));
```
