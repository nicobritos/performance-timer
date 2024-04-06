import 'dart:collection';

class PerformanceTimer {
  final String name;
  final Map<String, String?> _tags;
  final List<PerformanceTimer> _children = [];
  final PerformanceTimer? parent;
  late final PerformanceTimer root;
  final DateTime startAt = DateTime.now();
  final Stopwatch _ownStopwatch = Stopwatch();
  final Stopwatch _realStopwatch = Stopwatch();
  late final int threadId;

  Duration get relativeStartAt => isRoot ? Duration.zero : startAt.difference(root.startAt);
  bool get isRoot => root == this;
  Duration get realDuration => _realStopwatch.elapsed;
  Duration get ownDuration => _ownStopwatch.elapsed;
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

  factory PerformanceTimer({
    required String name,
    Map<String, String>? tags,
  }) {
    return PerformanceTimer._(name: name, tags: Map.of(tags ?? {}));
  }

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

  PerformanceTimer child(String name) {
    // Don't count time spent on children as own
    _ownStopwatch.stop();

    final newStep = PerformanceTimer._(name: name, tags: {}, parent: this);
    _children.add(newStep);
    return newStep;
  }

  void finish() {
    if (!_realStopwatch.isRunning) {
      throw StateError('Timer already finished');
    }

    _realStopwatch.stop();
    _ownStopwatch.stop();

    parent?._ownStopwatch.start();
  }
}
