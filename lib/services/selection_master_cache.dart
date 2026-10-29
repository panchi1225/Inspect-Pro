/// Small session cache for the inspection chooser; concurrent opens share a read.
/// An expired snapshot remains available for immediate display during refresh.
class SelectionMasterCache<T> {
  SelectionMasterCache({
    this.ttl = const Duration(minutes: 1),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Duration ttl;
  final DateTime Function() _now;
  List<T>? _value;
  DateTime? _fetchedAt;
  Future<List<T>>? _pending;
  int _generation = 0;

  List<T>? get snapshot => _value == null ? null : List<T>.of(_value!);

  Future<List<T>> load(
    Future<List<T>> Function() fetch, {
    bool refresh = false,
  }) async {
    if (!refresh &&
        _fetchedAt != null &&
        _now().difference(_fetchedAt!) < ttl) {
      return snapshot!;
    }
    if (_pending == null) {
      final generation = _generation;
      late final Future<List<T>> request;
      request = Future<List<T>>.sync(fetch)
          .then((value) {
            if (generation == _generation) {
              _value = List<T>.of(value);
              _fetchedAt = _now();
            }
            return value;
          })
          .whenComplete(() {
            if (identical(_pending, request)) _pending = null;
          });
      _pending = request;
    }
    return List<T>.of(await _pending!);
  }

  void invalidate() {
    _generation++;
    _value = null;
    _fetchedAt = null;
    _pending = null;
  }
}
