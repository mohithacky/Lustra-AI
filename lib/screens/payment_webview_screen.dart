import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lustra_ai/screens/webview_screen.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';

class BuyCoinsPage extends StatefulWidget {
  const BuyCoinsPage({Key? key}) : super(key: key);

  @override
  State<BuyCoinsPage> createState() => _BuyCoinsPageState();
}

class _BuyCoinsPageState extends State<BuyCoinsPage> {
  Future<void> _createOrder(int amount) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('User not logged in');
      // Optionally, show a message to the user
      return;
    }

    final idToken = await user.getIdToken();

    final url = Uri.parse(
      'https://api-5sqqk2n6ra-uc.a.run.app/order',
    );
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: json.encode({'amount': amount}),
    );
    print(response.body);
    if (response.statusCode == 200) {
      // ignore: use_build_context_synchronously
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WebViewScreen(htmlContent: response.body),
        ),
      );
    } else {
      // Handle error
      print('Failed to create order: ${response.body}');
    }
  }

  final List<Map<String, dynamic>> plans = [
    {
      'title': 'Starter',
      'coins': 100,
      'price': 199,
      'subtitle': 'Good for quick edits',
      'features': ['Basic filters', '1 export/day', '30 days validity']
    },
    {
      'title': 'Pro',
      'coins': 550,
      'price': 799,
      'subtitle': 'Most popular',
      'features': ['Pro filters', '10 exports/day', '90 days validity'],
      'highlight': true
    },
    {
      'title': 'Unlimited',
      'coins': 2000,
      'price': 2499,
      'subtitle': 'For power users',
      'features': ['All filters', 'Unlimited exports', '1 year validity']
    },
  ];

  bool _loading = false;

  void _buyPlan(Map<String, dynamic> plan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Purchase'),
        content: Text('Buy ${plan['coins']} coins for ₹${plan['price']}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () {
                _createOrder(plan['price']);
              },
              child: const Text('Buy')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);

    // Simulate payment delay
    await Future.delayed(const Duration(seconds: 2));

    setState(() => _loading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Payment successful — ${plan['coins']} coins added!',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buy Coins'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              final isHighlight = plan['highlight'] == true;

              return Card(
                color: isHighlight ? Colors.amber[50] : Colors.white,
                elevation: isHighlight ? 6 : 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              plan['title'],
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[900],
                              ),
                            ),
                          ),
                          Text(
                            '₹${plan['price']}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan['subtitle'],
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(
                        plan['features'].length,
                        (i) => Row(
                          children: [
                            const Icon(Icons.check_circle,
                                color: Colors.green, size: 18),
                            const SizedBox(width: 6),
                            Text(plan['features'][i]),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: ElevatedButton(
                          onPressed: _loading ? null : () => _buyPlan(plan),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isHighlight ? Colors.orange : Colors.blue,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Buy Now',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (_loading)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
