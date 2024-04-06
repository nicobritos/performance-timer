import 'dart:collection';

/// [PerformanceTimer] can be used to track
/// time spent in method calls. It allows to track
/// real or total time spent, and own time spent.
///
/// Immediately after instantiation, both timers are started,
/// and [realDuration] is only stopped when [finish] is called,
/// allowing to track all time spent in total.
///
/// Instead, [ownDuration] allows to track time only spent
/// inside the intended method call. This is paused when a [child]
/// is created, and resumed when that child has [finish]ed.
/// This allows to truly track time spent inside a method call.
///
/// A [PerformanceTimer], once [finish]ed, cannot be started again.
///
/// Each timer has a [name] that may be used to easily distinguish it
/// when analyzing the results.
///
/// Also, the [root] timer may have [tags] set for the same purpose.
/// However, child timers will have this map empty.
class PerformanceTimer {
  final String name;
  final Map<String, String?> _tags;
  final List<PerformanceTimer> _children = [];
  final PerformanceTimer? parent;
  late final PerformanceTimer root;
  final DateTime startAt = DateTime.now();
  final Stopwatch _ownStopwatch = Stopwatch();
  final Stopwatch _realStopwatch = Stopwatch();

  /// This is used in TraceEventFormat, but for now is zero.
  ///
  /// At first, it was set as the hashcode of the current isolate,
  /// but this must not be a negative number, which may happen when
  /// using hashcode.
  late final int threadId;

  /// Moment which this timer has started, since root timer has been created.
  ///
  /// If this is the root timer, then time elapsed is zero.
  Duration get relativeStartAt =>
      isRoot ? Duration.zero : startAt.difference(root.startAt);
  bool get isRoot => root == this;

  /// Time elapsed from start of this timer, until [finish] is called.
  Duration get realDuration => _realStopwatch.elapsed;

  /// Time elapsed from start of this timer, without considering time
  /// spent in children timers.
  Duration get ownDuration => _ownStopwatch.elapsed;
  bool get running => _realStopwatch.isRunning;
  List<PerformanceTimer> get children => UnmodifiableListView(_children);
  Map<String, String?> get tags => UnmodifiableMapView(_tags);

  PerformanceTimer._({
    required this.name,
    required Map<String, String?> tags,
    this.parent,
  }) : _tags = tags {
    threadId = 0;
    root = parent?.root ?? this;

    _realStopwatch.start();
    _ownStopwatch.start();
  }

  /// Creates a timer with [name] and [tags].
  ///
  /// There is no limitation in [name] length.
  /// A new map is created based on [tags].
  factory PerformanceTimer({
    required String name,
    Map<String, String>? tags,
  }) {
    return PerformanceTimer._(name: name, tags: Map.of(tags ?? {}));
  }

  /// Adds a new tag with corresponding values if [value] is not null,
  /// or removes it if [value] is null only on the root timer
  /// (or itself, if it is the root timer).
  void setTag(String key, [String? value]) {
    if (parent != null) {
      parent!.setTag(key, value);
      return;
    }

    if (value == null) {
      _tags.remove(key);
    } else {
      _tags[key] = value;
    }
  }

  /// Creates a new child timer with [name] and stores it in [children].
  ///
  /// Automatically pauses the [ownDuration] of this timer,
  /// and starts both stopwatches of the created child.
  PerformanceTimer child(String name) {
    if (!running) {
      throw StateError('Timer already finished');
    }

    // Don't count time spent on children as own
    _ownStopwatch.stop();

    final newStep = PerformanceTimer._(name: name, tags: {}, parent: this);
    _children.add(newStep);
    return newStep;
  }

  /// Stops all stopwatches ([ownDuration] and [realDuration]).
  /// If the timer has a parent, then it also resumes
  void finish() {
    if (!running) {
      throw StateError('Timer already finished');
    }

    _realStopwatch.stop();
    _ownStopwatch.stop();

    parent?._ownStopwatch.start();
  }
}