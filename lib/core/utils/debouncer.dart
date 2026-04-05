import 'dart:async';

/// A utility to debounce rapid calls (e.g., search input).
///
/// Usage:
/// ```dart
/// final debouncer = Debouncer(milliseconds: 300);
/// debouncer.run(() => searchVoters(query));
/// ```
class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({required this.milliseconds});

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void cancel() {
    _timer?.cancel();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
