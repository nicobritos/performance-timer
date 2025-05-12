import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:performance_timer/src/performance_timer_exception.dart';
import 'package:performance_timer/src/utils.dart';

typedef MeasurableCallback<R, T> = Future<R> Function(
    PerformanceTimer<T> timer);
typedef OnFinishedCallback<T> = void Function(
    PerformanceTimer<T> timer, T? result);

/// Tracks time spent in method calls, including bot total and own time
/// spent.
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
/// Each timer has a [name] and [category] that may be used to easily
/// distinguish it when analyzing the results.
///
/// Also, the [root] timer may have [tags] set for the same purpose.
/// However, child timers will have this map empty.
class PerformanceTimer<T> {
  final String name;
  final String? category;
  final Map<String, String?> _tags;
  final List<PerformanceTimer<T>> _children = [];
  final PerformanceTimer<T>? parent;
  late final PerformanceTimer<T> root;
  final DateTime startAt = DateTime.now();
  final Duration relativeStartAt;
  final Stopwatch _ownStopwatch = Stopwatch();
  final Stopwatch _realStopwatch = Stopwatch();
  final OnFinishedCallback<T>? _onFinished;
  final String id;
  String? errorMessage;
  String? errorType;
  bool finished = false;
  bool discarded = false;
  bool _countingOwnTimer = true;
  bool _paused = false;

  /// This is used in TraceEventFormat, but for now is zero.
  ///
  /// At first, it was set as the hashcode of the current isolate,
  /// but this must not be a negative number, which may happen when
  /// using hashcode.
  late final int threadId;

  bool get isRoot => root == this;

  /// Time elapsed from start of this timer, until [finish] is called.
  Duration get realDuration => _realStopwatch.elapsed;

  /// Time elapsed from start of this timer, without considering time
  /// spent in children timers.
  Duration get ownDuration => _ownStopwatch.elapsed;

  bool get running => !finished;
  List<PerformanceTimer> get children => UnmodifiableListView(_children);
  Map<String, String?> get tags => UnmodifiableMapView(_tags);
  bool get success => errorMessage == null && errorType == null;

  PerformanceTimer._({
    required this.name,
    required this.category,
    required this.id,
    required Map<String, String?> tags,
    required this.relativeStartAt,
    this.parent,
    OnFinishedCallback<T>? onFinished,
    bool paused = false,
  })  : _tags = tags,
        _onFinished = onFinished {
    threadId = 0;
    root = parent?.root ?? this;

    _paused = paused;

    if (!paused) {
      _realStopwatch.start();
      _ownStopwatch.start();
    }
  }

  /// Creates a timer with [name], [category] and [tags].
  ///
  /// There is no limitation in [name] nor [category] length.
  /// A new map is created based on [tags].
  factory PerformanceTimer({
    required String name,
    String? category,
    Map<String, String>? tags,
    OnFinishedCallback<T>? onFinished,
  }) {
    return PerformanceTimer._(
      name: name,
      id: Utils.generateHexId(16),
      category: category,
      tags: Map.of(tags ?? {}),
      onFinished: onFinished,
      relativeStartAt: Duration.zero,
    );
  }

  /// Adds a new tag with corresponding values if [value] is not null,
  /// or removes it if [value] is null only on the root timer
  /// (or itself, if it is the root timer).
  void setTag(String key, [String? value]) {
    if (value == null) {
      _tags.remove(key);
    } else {
      _tags[key] = value;
    }
  }

  void setError({String? type, String? message}) {
    errorType = type;
    errorMessage = message;
  }

  /// Creates a new child timer with [name] and stores it in [children].
  ///
  /// If [category] is null, then the parent's category is used.
  /// Automatically pauses the [ownDuration] of this timer,
  /// and starts both stopwatches of the created child.
  PerformanceTimer<T> child(String name, {String? category}) {
    if (!running) {
      throw StateError('Timer already finished');
    }

    // Don't count time spent on children as own
    pauseOwnTimer();

    final newStep = PerformanceTimer._(
      name: name,
      id: Utils.generateHexId(8),
      category: category ?? this.category,
      tags: {},
      parent: this,
      relativeStartAt: relativeStartAt + realDuration,
      paused: _paused,
    );
    _children.add(newStep);
    return newStep;
  }

  /// Creates a new child timer as [child] to measure time spent in the
  /// [callback]. This child timer is automatically finished when the
  /// [callback] completes or fails. If it fails, it rethrows the error.
  Future<R> measure<R>(
    String name,
    MeasurableCallback<R, T> callback, {
    String? category,
  }) async {
    final childTimer = child(name, category: category);

    try {
      final result = await callback(childTimer);
      childTimer.finish();
      return result;
    } catch (e) {
      if (childTimer.running) {
        if (e is PerformanceTimerException) {
          childTimer.finish(
            errorType: e.type,
            errorMessage: e.message,
          );
        } else {
          childTimer.finish(errorMessage: e.toString());
        }
      }
      rethrow;
    }
  }

  /// Stops all stopwatches ([ownDuration] and [realDuration]).
  /// If the timer has a parent, then it also resumes
  void finish({
    T? result,
    String? errorType,
    String? errorMessage,
    bool discarded = false,
    bool failOnStopped = true,
  }) {
    if (!running) {
      if (failOnStopped) {
        throw StateError('Timer already finished');
      }
      return;
    }

    pause();
    finished = true;

    if (parent != null) {
      parent!.startOwnTimer();
    } else {
      this.discarded = discarded;
    }

    this.errorMessage ??= errorMessage;
    this.errorType ??= errorType;

    if (_onFinished != null) {
      _onFinished(this, result);
    }
  }

  void pause() {
    if (!running) {
      return;
    }

    _realStopwatch.stop();
    _ownStopwatch.stop();
    _paused = true;

    for (final child in children) {
      child.pause();
    }
  }

  void resume() {
    if (!running) {
      return;
    }

    _paused = false;
    _realStopwatch.start();
    if (_countingOwnTimer) {
      _ownStopwatch.start();
    }

    for (final child in children) {
      child.resume();
    }
  }

  @protected
  void startOwnTimer() {
    _countingOwnTimer = true;

    if (!_paused) {
      _ownStopwatch.start();
    }
  }

  @protected
  void pauseOwnTimer() {
    _countingOwnTimer = false;
    _ownStopwatch.stop();
  }
}
