import 'package:performance_timer/performance_timer.dart';
import 'package:test/test.dart';

void main() {
  group('root timer', () {
    late PerformanceTimer timer;
    setUp(() {
      timer = PerformanceTimer(
        name: 'root',
        category: 'category',
        tags: {'initialKey': 'initialValue'},
      );
    });

    test('should have correct name', () {
      expect(timer.name, equals('root'));
    });

    test('should have correct category', () {
      expect(timer.category, equals('category'));
    });

    test('should have correct tags', () {
      expect(timer.tags, equals({'initialKey': 'initialValue'}));
    });

    test('should have relativeStartAt zero', () {
      expect(timer.relativeStartAt, equals(Duration.zero));
    });

    test('should have started stopwatches', () {
      expect(timer.realDuration, greaterThan(Duration.zero));
      expect(timer.ownDuration, greaterThan(Duration.zero));
    });

    test('should have zero children', () {
      expect(timer.children, isEmpty);
    });

    test('should be root', () {
      expect(timer.isRoot, isTrue);
      expect(timer.root, equals(timer));
    });

    test('should have zero as thread id', () {
      expect(timer.threadId, equals(0));
    });

    test('should not have parent', () {
      expect(timer.parent, isNull);
    });

    test('should set tag', () {
      timer.setTag('key', 'value');
      expect(timer.tags, equals({'key': 'value', 'initialKey': 'initialValue'}));
    });

    test('should delete tag', () {
      timer.setTag('initialKey');
      expect(timer.tags, isEmpty);
    });

    test('should stop stopwatches when finished', () async {
      await Future.delayed(const Duration(milliseconds: 50));
      timer.finish();
      final realDuration = timer.realDuration;
      final ownDuration = timer.ownDuration;
      await Future.delayed(const Duration(milliseconds: 50));

      expect(timer.realDuration, equals(realDuration));
      expect(timer.ownDuration, equals(ownDuration));
    });

    test('should create a child', () {
      final child = timer.child('child');
      expect(timer.children.length, equals(1));
      expect(timer.children.first, child);
    });

    test('should stop own stopwatch when creating a child', () async {
      timer.child('child');
      final ownDuration1 = timer.ownDuration;
      await Future.delayed(const Duration(milliseconds: 50));
      final ownDuration2 = timer.ownDuration;

      expect(ownDuration1, equals(ownDuration2));
    });

    test('should not stop real stopwatch when creating a child', () async {
      final realDuration1 = timer.realDuration;
      await Future.delayed(const Duration(milliseconds: 50));
      timer.child('child');
      final realDuration2 = timer.realDuration;
      await Future.delayed(const Duration(milliseconds: 50));
      final realDuration3 = timer.realDuration;

      expect(realDuration1, lessThan(realDuration2));
      expect(realDuration2, lessThan(realDuration3));
    });
  });

  group('child timer', () {
    late PerformanceTimer root, child;
    setUp(() async {
      root = PerformanceTimer(name: 'root', category: 'category');
      await Future.delayed(const Duration(milliseconds: 10));
      child = root.child('child');
    });

    test('should have correct name', () {
      expect(child.name, equals('child'));
    });

    test('should have parent\'s category', () {
      expect(child.category, equals('category'));
    });

    test('should have own category', () {
      final child2 = root.child('child', category: 'childCategory');
      expect(child2.category, equals('childCategory'));
    });

    test('should have zero tags', () {
      expect(child.tags, isEmpty);
    });

    test('should have relativeStartAt at not zero', () {
      expect(child.relativeStartAt, isNot(equals(Duration.zero)));
    });

    test('should have stopwatches with less duration than parent', () {
      expect(child.realDuration, lessThan(root.realDuration));
      expect(child.ownDuration, lessThan(root.ownDuration));
    });

    test('should have zero children', () {
      expect(child.children, isEmpty);
    });

    test('should not be root', () {
      expect(child.isRoot, isFalse);
    });

    test('should have zero as thread id', () {
      expect(child.threadId, equals(0));
      expect(child.threadId, equals(root.threadId));
    });

    test('should have parent', () {
      expect(child.parent, equals(root));
    });

    test('should have root', () {
      expect(child.root, equals(root));
    });

    test('should set tag in root', () {
      child.setTag('key', 'value');
      expect(child.tags, isEmpty);
      expect(root.tags, equals({'key': 'value'}));
    });

    test('should delete tag in root', () {
      child.setTag('key', 'value');
      child.setTag('key');
      expect(root.tags, isEmpty);
    });

    test('should stop stopwatches when finished', () async {
      await Future.delayed(const Duration(milliseconds: 50));
      child.finish();
      final realDuration = child.realDuration;
      final ownDuration = child.ownDuration;
      await Future.delayed(const Duration(milliseconds: 50));

      expect(child.realDuration, equals(realDuration));
      expect(child.ownDuration, equals(ownDuration));
    });

    test('should start ownStopwatch on parent when finished', () async {
      final ownDuration1 = root.ownDuration;
      child.finish();
      await Future.delayed(const Duration(milliseconds: 50));
      final ownDuration2 = root.ownDuration;

      expect(ownDuration1, lessThan(ownDuration2));
    });
  });

  group('measure', () {
    late PerformanceTimer root;
    setUp(() async {
      root = PerformanceTimer(name: 'root');
    });

    test('should call function', () {
      var called = false;

      root.measure('measure', (child) {
        called = true;
      });

      expect(called, isTrue);
    });

    test('should finish timer with sync function', () {
      PerformanceTimer? childTimer;

      root.measure('measure', (child) {
        childTimer = child;
      });

      expect(childTimer, isNotNull);
      expect(childTimer!.running, isFalse);
    });

    test('should finish timer with sync function if error', () {
      PerformanceTimer? childTimer;

      try {
        root.measure('measure', (child) {
          childTimer = child;
          throw Exception();
        });
      } catch (_) {}

      expect(childTimer, isNotNull);
      expect(childTimer!.running, isFalse);
    });

    test('should rethrow error with sync function', () {
      expect(
        () => root.measure('measure', (_) {
          throw Exception();
        }),
        throwsA(isA<Exception>()),
      );
    });

    test('should finish timer with async function', () async {
      PerformanceTimer? childTimer;

      await root.measure('measure', (child) async {
        childTimer = child;
        await Future.delayed(const Duration(milliseconds: 150));
      });

      expect(childTimer, isNotNull);
      expect(childTimer!.running, isFalse);
      expect(childTimer!.ownDuration.inMilliseconds, greaterThanOrEqualTo(150));
    });

    test('should finish timer with async function if error', () async {
      PerformanceTimer? childTimer;

      try {
        await root.measure('measure', (child) async {
          childTimer = child;
          await Future.delayed(const Duration(milliseconds: 150));
          throw Exception();
        });
      } catch (_) {}

      expect(childTimer, isNotNull);
      expect(childTimer!.running, isFalse);
      expect(childTimer!.ownDuration.inMilliseconds, greaterThanOrEqualTo(150));
    });

    test('should rethrow error with async function', () async {
      expect(
        () async => await root.measure('measure', (_) async {
          throw Exception();
        }),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('nested child timer', () {
    late PerformanceTimer root, child, childOfChild;
    setUp(() async {
      root = PerformanceTimer(name: 'root');
      await Future.delayed(const Duration(milliseconds: 10));
      child = root.child('child');
      await Future.delayed(const Duration(milliseconds: 10));
      childOfChild = child.child('childOfChild');
    });

    test('should have parent', () {
      expect(childOfChild.parent, equals(child));
    });

    test('should have root', () {
      expect(childOfChild.root, equals(root));
    });

    test('should set tag in root', () {
      childOfChild.setTag('key', 'value');
      expect(childOfChild.tags, isEmpty);
      expect(root.tags, equals({'key': 'value'}));
    });

    test('should delete tag in root', () {
      childOfChild.setTag('key', 'value');
      childOfChild.setTag('key');
      expect(root.tags, isEmpty);
    });
  });
}
