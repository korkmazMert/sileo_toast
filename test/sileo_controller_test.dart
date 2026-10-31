// promise() returns the caller's own future; tests drive it via fakeAsync.
// ignore_for_file: discarded_futures
import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sileo_toast/sileo_toast.dart';

const _s = Duration(seconds: 1);

SileoItem _only(SileoController c) => c.items.single;

void main() {
  late SileoController c;
  setUp(() => c = SileoController());
  tearDown(() {
    // Tests that dispose themselves must not double-dispose.
    c.dispose();
  });

  group('stacking', () {
    test('same-id show replaces in place with a new instanceId', () {
      final firstId = c.show(const SileoOptions(title: 'a'));
      final firstInstance = _only(c).instanceId;
      final secondId = c.show(const SileoOptions(title: 'b'));
      expect(secondId, firstId);
      expect(c.items, hasLength(1));
      expect(_only(c).options.title, 'b');
      expect(_only(c).instanceId, isNot(firstInstance));
    });

    test('distinct ids stack in insertion order', () {
      c
        ..show(const SileoOptions(id: 'a'))
        ..show(const SileoOptions(id: 'b'));
      expect(c.items.map((i) => i.id), ['a', 'b']);
    });

    test('ids come from a per-controller counter', () {
      final other = SileoController();
      addTearDown(other.dispose);
      final a = c.show(const SileoOptions());
      final b = other.show(const SileoOptions());
      expect(a, b);
      expect(c.items.single.instanceId, other.items.single.instanceId);
    });

    test('items is read-only', () {
      c.show(const SileoOptions());
      expect(() => c.items.clear(), throwsUnsupportedError);
    });

    test('position falls back to defaultPosition, then explicit wins', () {
      expect(c.defaultPosition, SileoPosition.topRight);
      c
        ..show(const SileoOptions(id: 'a'))
        ..defaultPosition = SileoPosition.bottomLeft
        ..show(const SileoOptions(id: 'b'))
        ..show(const SileoOptions(id: 'c', position: SileoPosition.topCenter));
      expect(c.items.map((i) => i.position), [
        SileoPosition.topRight,
        SileoPosition.bottomLeft,
        SileoPosition.topCenter,
      ]);
    });

    test('defaultOptions fill unset fields', () {
      c
        ..defaultOptions = const SileoOptions(roundness: 4, title: 'x')
        ..show(const SileoOptions(title: 'y'));
      expect(_only(c).options.roundness, 4);
      expect(_only(c).options.title, 'y');
    });

    test('typed helpers set the state', () {
      c
        ..success(const SileoOptions(id: '1'))
        ..error(const SileoOptions(id: '2'))
        ..warning(const SileoOptions(id: '3'))
        ..info(const SileoOptions(id: '4'))
        ..action(const SileoOptions(id: '5'));
      expect(c.items.map((i) => i.options.type), [
        SileoState.success,
        SileoState.error,
        SileoState.warning,
        SileoState.info,
        SileoState.action,
      ]);
    });

    test('update merges over the toast with a new instanceId', () {
      c.info(const SileoOptions(id: 'a', title: 'old', roundness: 3));
      final before = _only(c).instanceId;
      c.update('a', const SileoOptions(title: 'new'));
      expect(_only(c).options.title, 'new');
      expect(_only(c).options.roundness, 3);
      expect(_only(c).options.type, SileoState.info);
      expect(_only(c).instanceId, isNot(before));
      c.update('missing', const SileoOptions(title: 'z'));
      expect(c.items, hasLength(1));
    });
  });

  group('dismiss', () {
    test('marks exiting, removes after 600 ms; repeat dismiss is a no-op', () {
      fakeAsync((async) {
        var notified = 0;
        c
          ..show(const SileoOptions(id: 'a', persistent: true))
          ..addListener(() => notified++)
          ..dismiss('a');
        expect(_only(c).exiting, isTrue);
        expect(notified, 1);
        async.elapse(const Duration(milliseconds: 300));
        c
          ..dismiss('a')
          ..dismiss('unknown');
        expect(notified, 1);
        async.elapse(const Duration(milliseconds: 299));
        expect(c.items, hasLength(1));
        async.elapse(const Duration(milliseconds: 1));
        expect(c.items, isEmpty);
      });
    });

    test('default duration auto-dismisses at 6 s', () {
      fakeAsync((async) {
        c.show(const SileoOptions());
        async.elapse(const Duration(milliseconds: 5999));
        expect(_only(c).exiting, isFalse);
        async.elapse(const Duration(milliseconds: 1));
        expect(_only(c).exiting, isTrue);
        async.elapse(const Duration(milliseconds: 600));
        expect(c.items, isEmpty);
      });
    });

    test('custom duration is honored', () {
      fakeAsync((async) {
        c.show(const SileoOptions(duration: Duration(seconds: 2)));
        async.elapse(const Duration(seconds: 2));
        expect(_only(c).exiting, isTrue);
      });
    });

    test('persistent and non-positive durations never auto-dismiss', () {
      fakeAsync((async) {
        c
          ..show(const SileoOptions(id: 'p', persistent: true))
          ..show(const SileoOptions(id: 'z', duration: Duration.zero))
          ..show(const SileoOptions(id: 'n', duration: Duration(seconds: -1)));
        async.elapse(const Duration(hours: 1));
        expect(c.items, hasLength(3));
        expect(c.items.any((i) => i.exiting), isFalse);
      });
    });

    test('replacing a toast cancels the old instance timer', () {
      fakeAsync((async) {
        c.show(const SileoOptions(id: 'a'));
        async.elapse(const Duration(seconds: 5));
        c.show(const SileoOptions(id: 'a', title: 'new'));
        async.elapse(const Duration(milliseconds: 1500));
        expect(_only(c).exiting, isFalse);
        async.elapse(const Duration(milliseconds: 4500));
        expect(_only(c).exiting, isTrue);
      });
    });

    test('2+ show/dismiss cycles keep timers correct', () {
      fakeAsync((async) {
        for (var i = 0; i < 3; i++) {
          c.show(const SileoOptions(id: 'a', duration: _s));
          expect(_only(c).exiting, isFalse);
          async.elapse(_s);
          expect(_only(c).exiting, isTrue);
          async.elapse(const Duration(milliseconds: 600));
          expect(c.items, isEmpty);
          c
            ..show(const SileoOptions(id: 'b', persistent: true))
            ..dismiss('b');
          async.elapse(const Duration(milliseconds: 600));
          expect(c.items, isEmpty);
        }
        expect(async.nonPeriodicTimerCount, 0);
      });
    });

    test('a toast re-shown while exiting is live again', () {
      fakeAsync((async) {
        c
          ..show(const SileoOptions(id: 'a', persistent: true))
          ..dismiss('a')
          ..show(const SileoOptions(id: 'a', persistent: true));
        async.elapse(const Duration(seconds: 1));
        expect(_only(c).exiting, isFalse);
      });
    });
  });

  group('clear', () {
    test('clear(position) removes only that position', () {
      c
        ..show(const SileoOptions(id: 'a', position: SileoPosition.topLeft))
        ..show(const SileoOptions(id: 'b', position: SileoPosition.bottomLeft))
        ..show(const SileoOptions(id: 'c', position: SileoPosition.topLeft))
        ..clear(SileoPosition.topLeft);
      expect(c.items.map((i) => i.id), ['b']);
    });

    test('clear() removes everything and cancels timers', () {
      fakeAsync((async) {
        c
          ..show(const SileoOptions(id: 'a'))
          ..show(const SileoOptions(id: 'b'))
          ..clear();
        expect(c.items, isEmpty);
        expect(async.nonPeriodicTimerCount, 0);
      });
    });
  });

  group('pause / resume', () {
    test('pause stops dismissal; resume reschedules the full duration', () {
      fakeAsync((async) {
        c.show(const SileoOptions());
        async.elapse(const Duration(seconds: 3));
        c.pause();
        async.elapse(const Duration(hours: 1));
        expect(_only(c).exiting, isFalse);
        c.resume();
        async.elapse(const Duration(milliseconds: 5999));
        expect(_only(c).exiting, isFalse);
        async.elapse(const Duration(milliseconds: 1));
        expect(_only(c).exiting, isTrue);
      });
    });

    test('an exiting toast keeps its removal timer while paused', () {
      fakeAsync((async) {
        c
          ..show(const SileoOptions(id: 'a', persistent: true))
          ..dismiss('a')
          ..pause();
        async.elapse(const Duration(milliseconds: 600));
        expect(c.items, isEmpty);
      });
    });

    test('resume does not revive exiting toasts or persistent ones', () {
      fakeAsync((async) {
        c
          ..show(const SileoOptions(id: 'a', persistent: true))
          ..show(const SileoOptions(id: 'b'))
          ..dismiss('b')
          ..pause()
          ..resume();
        async.elapse(const Duration(hours: 1));
        expect(c.items.map((i) => i.id), ['a']);
      });
    });
  });

  group('autopilot', () {
    SileoItem item(SileoOptions o) {
      final controller = SileoController()..show(o);
      addTearDown(controller.dispose);
      return controller.items.single;
    }

    test('defaults are 150 ms / 4000 ms', () {
      final i = item(const SileoOptions());
      expect(i.autoExpandDelay, const Duration(milliseconds: 150));
      expect(i.autoCollapseDelay, const Duration(milliseconds: 4000));
    });

    test('custom values are used and clamped to the duration', () {
      final custom = item(
        const SileoOptions(
          duration: Duration(seconds: 2),
          autopilot: SileoAutopilot(
            expand: Duration(milliseconds: 100),
            collapse: Duration(milliseconds: 500),
          ),
        ),
      );
      expect(custom.autoExpandDelay, const Duration(milliseconds: 100));
      expect(custom.autoCollapseDelay, const Duration(milliseconds: 500));

      final clamped = item(
        const SileoOptions(
          duration: _s,
          autopilot: SileoAutopilot(
            expand: Duration(seconds: 5),
            collapse: Duration(seconds: 9),
          ),
        ),
      );
      expect(clamped.autoExpandDelay, _s);
      expect(clamped.autoCollapseDelay, _s);
    });

    test('off, persistent and non-positive durations give none', () {
      for (final o in const [
        SileoOptions(autopilot: SileoAutopilot.off),
        SileoOptions(persistent: true),
        SileoOptions(duration: Duration.zero),
        SileoOptions(duration: Duration(seconds: -2)),
      ]) {
        final i = item(o);
        expect(i.autoExpandDelay, isNull);
        expect(i.autoCollapseDelay, isNull);
      }
    });
  });

  group('promise', () {
    test('shows persistent loading, then success; returns the same future', () {
      fakeAsync((async) {
        final completer = Completer<int>();
        final future = completer.future;
        final returned = c.promise<int>(
          future,
          SileoPromiseOptions<int>(
            loading: const SileoOptions(title: 'wait'),
            success: (d) => SileoOptions(title: 'ok $d'),
            error: (e) => SileoOptions(title: 'bad $e'),
          ),
        );
        expect(returned, same(future));
        expect(_only(c).options.type, SileoState.loading);
        async.elapse(const Duration(hours: 1));
        expect(_only(c).exiting, isFalse);
        final id = _only(c).id;

        completer.complete(7);
        async.flushMicrotasks();
        expect(c.items, hasLength(1));
        expect(_only(c).id, id);
        expect(_only(c).options.type, SileoState.success);
        expect(_only(c).options.title, 'ok 7');
        // The loading toast's persistence must not leak into the result.
        async.elapse(const Duration(seconds: 6));
        expect(_only(c).exiting, isTrue);
      });
    });

    test('action(data) wins over success', () {
      fakeAsync((async) {
        c.promise<int>(
          Future.value(1),
          SileoPromiseOptions<int>(
            loading: const SileoOptions(),
            success: (_) => const SileoOptions(title: 's'),
            action: (_) => const SileoOptions(title: 'a'),
            error: (_) => const SileoOptions(),
          ),
        );
        async.flushMicrotasks();
        expect(_only(c).options.type, SileoState.action);
        expect(_only(c).options.title, 'a');
      });
    });

    test('failure shows error and the returned future rethrows', () {
      fakeAsync((async) {
        final completer = Completer<int>();
        final returned = c.promise<int>(
          completer.future,
          SileoPromiseOptions<int>(
            loading: const SileoOptions(),
            success: (_) => const SileoOptions(),
            error: (e) => SileoOptions(title: 'bad $e'),
          ),
        );
        Object? caught;
        returned.catchError((Object e) {
          caught = e;
          return 0;
        });
        completer.completeError('boom');
        async.flushMicrotasks();
        expect(caught, 'boom');
        expect(_only(c).options.type, SileoState.error);
        expect(_only(c).options.title, 'bad boom');
      });
    });

    test('settling after dispose does not throw or notify', () {
      fakeAsync((async) {
        final ok = Completer<int>();
        final bad = Completer<int>();
        var notified = 0;
        SileoPromiseOptions<int> opts() => SileoPromiseOptions<int>(
          loading: const SileoOptions(),
          success: (_) => const SileoOptions(),
          error: (_) => const SileoOptions(),
        );
        c.promise<int>(ok.future, opts());
        c.promise<int>(bad.future, opts()).ignore();
        c
          ..addListener(() => notified++)
          ..dispose();
        ok.complete(1);
        bad.completeError('x');
        async.flushMicrotasks();
        expect(notified, 0);
      });
    });
  });

  group('dispose', () {
    test('cancels every timer; later calls are no-ops', () {
      fakeAsync((async) {
        var notified = 0;
        c
          ..show(const SileoOptions(id: 'a'))
          ..show(const SileoOptions(id: 'b', persistent: true))
          ..dismiss('b')
          ..addListener(() => notified++)
          ..dispose();
        expect(async.nonPeriodicTimerCount, 0);

        expect(() {
          c
            ..show(const SileoOptions())
            ..success(const SileoOptions())
            ..update('a', const SileoOptions())
            ..dismiss('a')
            ..clear()
            ..pause()
            ..resume();
        }, returnsNormally);
        async.elapse(const Duration(hours: 1));
        expect(async.nonPeriodicTimerCount, 0);
        expect(notified, 0);
        expect(c.items, hasLength(2));
      });
    });

    test('dispose twice does not throw', () {
      c
        ..dispose()
        ..dispose();
    });
  });
}
