import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lustra_ai/screens/webview_screen.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BuyCoinsPage extends StatefulWidget {
  const BuyCoinsPage({Key? key}) : super(key: key);

  @override
  State<BuyCoinsPage> createState() => _BuyCoinsPageState();
}

class _BuyCoinsPageState extends State<BuyCoinsPage> {
  final Color _softGold = const Color(0xFFE3C887);
  final Color _matteBlack = const Color(0xFF121212);
  final Color _darkGrey = const Color(0xFF1A1A1A);

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
      'planName': 'Starter Pack',
      'coins': 100,
      'price': 199,
      'subtitle': 'Good for quick edits',
      'features': ['Basic filters', '1 export/day', '30 days validity']
    },
    {
      'title': 'Pro',
      'planName': 'Pro Pack',
      'coins': 550,
      'price': 799,
      'subtitle': 'Most popular',
      'features': ['Pro filters', '10 exports/day', '90 days validity'],
      'highlight': true
    },
    {
      'title': 'Unlimited',
      'planName': 'Unlimited Pack',
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
        backgroundColor: _darkGrey,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Confirm Purchase', style: TextStyle(color: _softGold)),
        content: Text('Buy ${plan['coins']} coins for ₹${plan['price']}?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70))),
          ElevatedButton(
              onPressed: () {
                _createOrder(plan['price']);
              },
              style: ElevatedButton.styleFrom(backgroundColor: _softGold),
              child: const Text('Buy', style: TextStyle(color: Colors.black))),
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
      backgroundColor: _matteBlack,
      appBar: AppBar(
        title: const Text('Buy Coins'),
        centerTitle: true,
        backgroundColor: _darkGrey,
        elevation: 0,
      ),
      body: Stack(
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser!.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final userData = snapshot.data!.data() as Map<String, dynamic>?;
              final purchaseHistory = (userData?['purchaseHistory'] as List<dynamic>? ?? [])
                  .map((item) => item as Map<String, dynamic>)
                  .toList();
              final purchasedPlanNames = purchaseHistory
                  .map((purchase) => purchase['planName'] as String?)
                  .where((name) => name != null)
                  .toSet();

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: plans.length,
                itemBuilder: (context, index) {
                  final plan = plans[index];
                  final isHighlight = plan['highlight'] == true;
                  final isPurchased = purchasedPlanNames.contains(plan['planName']);

                  return Card(
                    color: isHighlight ? _softGold.withOpacity(0.1) : _darkGrey,
                    elevation: isHighlight ? 6 : 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: isHighlight ? BorderSide(color: _softGold, width: 1.5) : BorderSide.none,
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
                                    color: isHighlight ? _softGold : Colors.white,
                                  ),
                                ),
                              ),
                              Text(
                                '₹${plan['price']}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: _softGold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            plan['subtitle'],
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 12),
                          ...List.generate(
                            plan['features'].length,
                            (i) => Row(
                              children: [
                                Icon(Icons.check_circle,
                                    color: _softGold, size: 18),
                                const SizedBox(width: 6),
                                Text(plan['features'][i], style: const TextStyle(color: Colors.white70)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: isPurchased
                                ? ElevatedButton(
                                    onPressed: null, // Disabled button
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _darkGrey,
                                      side: BorderSide(color: _softGold),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 32, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text('Purchased', style: TextStyle(color: _softGold)),
                                  )
                                : ElevatedButton(
                                    onPressed: _loading ? null : () => _buyPlan(plan),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _softGold,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 32, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      'Buy Now',
                                      style: TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
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
