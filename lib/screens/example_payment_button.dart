import 'package:flutter/material.dart';
import '../services/payment_service.dart';

class ExamplePaymentButton extends StatelessWidget {
  final double amount;
  final String name;
  final String email;
  final String phone;

  const ExamplePaymentButton({
    Key? key,
    required this.amount,
    required this.name,
    required this.email,
    required this.phone,
  }) : super(key: key);

  Future<void> _initiatePayment(BuildContext context) async {
    try {
      final result = await PaymentService.initiatePayment(
        context: context,
        amount: amount,
        name: name,
        email: email,
        phone: phone,
      );

      if (result['status'] == 'success') {
        // Payment successful
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment successful!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Verify payment with your backend
        final isVerified = PaymentService.verifyPayment(
          orderId: result['orderId'],
          paymentId: result['paymentId'],
          signature: result['signature'],
        );

        if (!isVerified) {
          // Handle unverified payment (potential fraud)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment verification failed. Please contact support.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else if (result['status'] == 'error') {
        // Payment failed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: ${result['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Handle any errors
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _initiatePayment(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      child: const Text('Pay Now', style: TextStyle(color: Colors.white)),
    );
  }
}
