import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityHelper {
  final Connectivity _connectivity = Connectivity();

  Stream<bool> get onConnectivityChanged {
    try {
      return _connectivity.onConnectivityChanged.map((results) {
        return results.any((r) => r != ConnectivityResult.none);
      }).handleError((_) {
        return Stream.value(true);
      });
    } catch (_) {
      return const Stream.empty();
    }
  }

  Future<bool> get hasInternet async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (results.any((r) => r != ConnectivityResult.none)) {
        return true;
      }
      return await _pingInternet();
    } catch (_) {
      return true;
    }
  }

  Future<bool> _pingInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
