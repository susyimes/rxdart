import 'dart:async';

/// Deprecated: Use RaceStream
///
/// Given two or more source streams, emit all of the items from only
/// the first of these streams to emit an item or notification.
///
/// [Interactive marble diagram](http://rxmarbles.com/#amb)
///
/// ### Example
///
///     new AmbStream([
///       new TimerStream(1, new Duration(days: 1)),
///       new TimerStream(2, new Duration(days: 2)),
///       new TimerStream(3, new Duration(seconds: 3))
///     ]).listen(print); // prints 3
@deprecated
class AmbStream<T> extends Stream<T> {
  final StreamController<T> controller;

  AmbStream(Iterable<Stream<T>> streams)
      : controller = _buildController(streams);

  @override
  StreamSubscription<T> listen(void onData(T event),
      {Function onError, void onDone(), bool cancelOnError}) {
    return controller.stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  static StreamController<T> _buildController<T>(Iterable<Stream<T>> streams) {
    if (streams == null) {
      throw ArgumentError('streams cannot be null');
    } else if (streams.isEmpty) {
      throw ArgumentError('provide at least 1 stream');
    }

    final subscriptions = <StreamSubscription<T>>[];
    var isDisambiguated = false;

    StreamController<T> controller;

    controller = StreamController<T>(
        sync: true,
        onListen: () {
          void doUpdate(int i, T value) {
            try {
              if (!isDisambiguated)
                for (var k = subscriptions.length - 1; k >= 0; k--) {
                  if (k != i) {
                    subscriptions[k].cancel();
                    subscriptions.removeAt(k);
                  }
                }

              isDisambiguated = true;

              controller.add(value);
            } catch (e, s) {
              controller.addError(e, s);
            }
          }

          for (var i = 0, len = streams.length; i < len; i++) {
            var stream = streams.elementAt(i);

            subscriptions.add(stream.listen((value) => doUpdate(i, value),
                onError: controller.addError,
                onDone: () => controller.close()));
          }
        },
        onPause: ([Future<dynamic> resumeSignal]) => subscriptions.forEach(
            (StreamSubscription<T> subscription) =>
                subscription.pause(resumeSignal)),
        onResume: () => subscriptions.forEach(
            (StreamSubscription<T> subscription) => subscription.resume()),
        onCancel: () => Future.wait<dynamic>(
                subscriptions.map((StreamSubscription<T> subscription) {
              if (subscription != null) return subscription.cancel();

              return Future<dynamic>.value();
            }).where((Future<dynamic> cancelFuture) => cancelFuture != null)));

    return controller;
  }
}
