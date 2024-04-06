# Performance Timer
Performance Timer is a package that allows you to time function and method
calls, allowing for nesting/children timers, tracking real and own time spent 
inside each timer.

Also allows for printing the results or dumping them to Trace Event Format,
which can then be parsed and analyzed by a lot of Trace analyzers, like
Google Perfetto (https://ui.perfetto.dev/)

## Features
* Track time spent inside a method with `timer.ownDuration` and `timer.child`
* Track all time spent since timer creation with `timer.realDuration`
* Store additional data linked to each (root) timer with `timer.setTag`
* Print results with `PerformanceTimerSerializerString`
* Export results to TraceEventFormat with `PerformanceTimerSerializerTraceEvent`

## Usage

* Create a timer
```dart
final timer = PerformanceTimer(name: 'rootTimer', tags: {'key': 'value'});
// Do some work
timer.finish();
```

* Create a nested/child timer
```dart
// Create a child event, which pause `timer.ownDuration`.
final child = timer.child('childTimer');
// Do some work
// ...
// Stop timer and signal parent to resume `timer.ownDuration`.
child.finish();
```

* Add a tag
```dart
timer.setTag('result', '3');

// If setting a tag inside a child, then it
// sets it on the root timer (in this case, `timer`)
child.setTag('result', '3');
```

* Remove a tag
```dart
timer.setTag('result');

// If removing a tag inside a child, then it
// removes it on the root timer (in this case, `timer`)
child.setTag('result');
```

* Serialize the results
```dart
const stringSerializer = PerformanceTimerSerializerString();
print(await stringSerializer.serialize(timer));

const traceEventSerializer = PerformanceTimerSerializerTraceEvent();
print(jsonEncode(await traceEventSerializer.serialize(timer)));
```
