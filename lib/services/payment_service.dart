import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../screens/payment_webview_screen.dart';

class PaymentService {
  static const String _razorpayKey = 'rzp_test_RU3vmBmQqfVRbc';
  static const String _razorpaySecret = 'Iun47L1o0V8KzE44QT8ic6hG';

  // Generate a unique order ID
  static String _generateOrderId() {
    final now = DateTime.now();
    final formatter = DateFormat('yyyyMMddHHmmss');
    return 'ORDER_${formatter.format(now)}_${now.millisecondsSinceEpoch}';
  }

  // Initiate payment
  static Future<Map<String, dynamic>> initiatePayment({
    required BuildContext context,
    required double amount,
    required String name,
    required String email,
    required String phone,
  }) async {
    final orderId = _generateOrderId();

    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => const PaymentWebViewScreen(),
      ),
    );

    return result ?? {'status': 'cancelled'};
  }

  // Verify payment signature (to be implemented on the backend)
  static bool verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) {
    // This should be implemented on your backend for security
    // For now, we'll just return true for demonstration
    // In production, make an API call to your backend to verify the payment
    return true;
  }
}
