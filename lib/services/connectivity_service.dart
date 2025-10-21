import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static Future<bool> isConnected() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    // The result can be a list in the new version, so we check if it contains none.
    if (connectivityResult == ConnectivityResult.none) {
      return false;
    }
    return true;
  }
}
