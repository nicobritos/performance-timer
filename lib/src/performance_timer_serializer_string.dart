import 'package:duration/duration.dart' show DurationTersity;
import 'package:duration/duration.dart' as duration_helper show prettyDuration;
import 'package:performance_timer/src/performance_timer.dart';
import 'package:performance_timer/src/performance_timer_serializer.dart';

/// Creates a String representation of a root [PerformanceTimer].
class PerformanceTimerSerializerString
    extends PerformanceTimerSerializer<String> {
  const PerformanceTimerSerializerString();

  @override
  String serialize(PerformanceTimer timer) {
    if (!timer.isRoot) {
      throw StateError('The timer to serialize should be the parent');
    }

    final sb = StringBuffer();

    sb.writeln('----- TIMER RESULTS -----');

    _serializeTags(timer.tags, sb);
    _serialize(timer, sb, 0);

    sb.writeln('-----------');

    return sb.toString();
  }

  void _serializeTags(Map<String, String?> tags, StringBuffer sb) {
    if (tags.isEmpty) {
      return;
    }

    sb.writeln('Tags:');
    for (final entry in tags.entries) {
      sb.writeln('${entry.key} = ${entry.value}');
    }
    sb.writeln('');
  }

  void _serialize(PerformanceTimer timer, StringBuffer sb, int indent) {
    final indentStr = '+' * indent + (indent > 0 ? ' ' : '');
    final categoryStr = timer.category != null ? ' - ${timer.category}' : '';
    sb.writeln(
      '$indentStr${timer.name} - tot: ${_prettifyDuration(timer.realDuration)} - own: ${_prettifyDuration(timer.ownDuration)}$categoryStr',
    );

    for (final child in timer.children) {
      _serialize(child, sb, indent + 1);
    }
  }

  String _prettifyDuration(Duration duration) {
    return duration_helper.prettyDuration(
      duration,
      abbreviated: true,
      tersity: DurationTersity.millisecond,
      upperTersity: DurationTersity.day,
    );
  }
}
