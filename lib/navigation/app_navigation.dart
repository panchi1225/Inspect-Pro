import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/inspection_record.dart';
import '../models/machine.dart';

abstract final class AppPaths {
  static const login = '/login';
  static const home = '/home';
  static const sites = '$home/sites';
  static const inspectors = '$sites/inspectors';
  static const machines = '$inspectors/machines';
  static const input = '$machines/input';
  static const records = '$home/records';
  static const detail = '$records/detail';
  static const masters = '$home/masters';
}

class AppRouteData {
  const AppRouteData({
    this.siteName,
    this.inspectorName,
    this.machine,
    this.record,
    this.onRecordDeleted,
  });
  final String? siteName;
  final String? inspectorName;
  final Machine? machine;
  final InspectionRecord? record;
  final VoidCallback? onRecordDeleted;
}

/// History keeps opaque session keys, never names, inspection results or photos.
/// Refreshing or reopening an expired session safely redirects through the router.
class SessionRouteDataCodec extends Codec<Object?, Object?> {
  final Map<String, AppRouteData> _values = {};
  final Map<AppRouteData, String> _keys = HashMap.identity();
  int _nextKey = 0;
  final String _session =
      '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(0x7fffffff)}';

  @override
  Converter<Object?, Object?> get encoder => _RouteDataEncoder(this);
  @override
  Converter<Object?, Object?> get decoder => _RouteDataDecoder(this);
}

class _RouteDataEncoder extends Converter<Object?, Object?> {
  _RouteDataEncoder(this.codec);
  final SessionRouteDataCodec codec;
  @override
  Object? convert(Object? input) {
    if (input is! AppRouteData) return null;
    final key = codec._keys.putIfAbsent(
      input,
      () => '${codec._session}-${++codec._nextKey}',
    );
    codec._values[key] = input;
    if (codec._values.length > 128) {
      final oldest = codec._values.keys.first;
      codec._keys.remove(codec._values.remove(oldest));
    }
    return {'inspectRoute': key};
  }
}

class _RouteDataDecoder extends Converter<Object?, Object?> {
  _RouteDataDecoder(this.codec);
  final SessionRouteDataCodec codec;
  @override
  Object? convert(Object? input) =>
      input is Map ? codec._values[input['inspectRoute']] : null;
}
