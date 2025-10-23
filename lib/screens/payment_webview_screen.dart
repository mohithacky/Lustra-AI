import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lustra_ai/services/connectivity_service.dart';
import 'package:lustra_ai/services/firestore_service.dart';
import 'package:lustra_ai/widgets/offline_dialog.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:lustra_ai/services/backend_config.dart';

class PaymentWebViewScreen extends StatefulWidget {
  const PaymentWebViewScreen({Key? key}) : super(key: key);

  @override
  _PaymentWebViewScreenState createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  late Future<DocumentSnapshot> _userFuture;

  final List<Map<String, dynamic>> _allPlans = [
    {
      'name': 'Starter Pack',
      'coins': 100,
      'amount': 100,
      'description': 'Perfect for trying out a few designs.',
      'color': Colors.blue.shade300,
    },
    {
      'name': 'Creator Pack',
      'coins': 500,
      'amount': 450,
      'description': 'Best value for frequent users.',
      'color': Colors.purple.shade300,
    },
    {
      'name': 'Pro Pack',
      'coins': 1000,
      'amount': 800,
      'description': 'For power users and professionals.',
      'color': Colors.green.shade300,
    },
  ];

  bool _isProcessing = false;
  String? _errorMessage;
  final String _backendUrl = backendBaseUrl;

  @override
  void initState() {
    super.initState();
    _userFuture = _firestoreService.getUserStream().first;
  }

  Future<void> _selectPlan(Map<String, dynamic> plan) async {
    if (!await ConnectivityService.isConnected()) {
      if (mounted) showOfflineDialog(context);
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final order = await _createOrder(
        amount: plan['amount'],
        receipt: 'order_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (order != null && order['id'] != null) {
        final orderId = order['id'];
        final url = '$_backendUrl/checkout/$orderId';

        if (!mounted) return;

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WebViewScreen(
              url: url,
              plan: plan,
              onError: (message) {
                setState(() => _errorMessage = message);
              },
            ),
          ),
        );
        // Refresh user data after returning from webview
        setState(() {
          _userFuture = _firestoreService.getUserStream().first;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Failed to create payment order. Please try again later.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<Map<String, dynamic>?> _createOrder({
    required int amount,
    required String receipt,
    String currency = 'INR',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/create_order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': amount,
          'receipt': receipt,
          'currency': currency,
        }),
      );
      print(response.body);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw error['error'] ?? 'Failed to create order';
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buy Coins'),
        backgroundColor: const Color(0xFF121212),
        foregroundColor: const Color(0xFFE3C887),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: _userFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting ||
              _isProcessing) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Error loading your data: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white)));
          }

          final userData = snapshot.data?.data() as Map<String, dynamic>?;
          final purchaseHistory =
              (userData?['purchaseHistory'] as List<dynamic>? ?? [])
                  .reversed
                  .toList();
          final int coinsLeft = (userData?['coins'] as int?) ?? 0;
          final Set<String> purchasedPlanNames = purchaseHistory
              .map((e) => (e as Map<String, dynamic>)['name'] as String)
              .toSet();
          final List<Map<String, dynamic>> plansToShow = purchaseHistory.isEmpty
              ? _allPlans
              : _allPlans
                  .where((p) => !purchasedPlanNames.contains(p['name']))
                  .toList();

          return Container(
            color: const Color(0xFF1A1A1A),
            child: Column(
              children: [
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0.0),
                          child: Card(
                            color: const Color(0xFF2A2A2A),
                            child: ListTile(
                              leading: const Icon(Icons.account_balance_wallet, color: Colors.white70),
                              title: const Text('Total Coins Left',
                                  style: TextStyle(color: Colors.white70)),
                              subtitle: Text('$coinsLeft',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ),
                      if (purchaseHistory.isNotEmpty)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0),
                            child: Text('Your Purchase History',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      if (purchaseHistory.isNotEmpty)
                        _buildPurchaseHistory(purchaseHistory),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding:
                              const EdgeInsets.fromLTRB(16.0, 32.0, 16.0, 16.0),
                          child: Text(
                            purchaseHistory.isEmpty
                                ? 'Choose a Plan'
                                : 'Upgrade your Plan',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      if (_errorMessage != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 8.0),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                  color: Colors.redAccent, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        sliver: _buildPlansList(plansToShow),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  SliverList _buildPurchaseHistory(List<dynamic> history) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final item = history[index] as Map<String, dynamic>;
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            color: const Color(0xFF2A2A2A),
            child: ListTile(
              title: Text(item['name'],
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text('${item['coins']} Coins - ₹${item['amount']}',
                  style: const TextStyle(color: Colors.white70)),
              leading: const Icon(Icons.receipt_long, color: Colors.white54),
            ),
          );
        },
        childCount: history.length,
      ),
    );
  }

  SliverList _buildPlansList(List<Map<String, dynamic>> plans) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final plan = plans[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16.0),
            color: const Color(0xFF2A2A2A),
            child: InkWell(
              onTap: () => _selectPlan(plan),
              borderRadius: BorderRadius.circular(12.0),
              child: Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(
                    color: (plan['color'] as Color).withOpacity(0.5),
                    width: 2.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${plan['coins']} Coins',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: 6.0,
                          ),
                          decoration: BoxDecoration(
                            color: (plan['color'] as Color).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          child: Text(
                            '₹${plan['amount']}',
                            style: TextStyle(
                              color: plan['color'] as Color,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      plan['description'],
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12.0),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      decoration: BoxDecoration(
                        color: (plan['color'] as Color).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(
                          color: (plan['color'] as Color).withOpacity(0.3),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'BUY NOW',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        childCount: plans.length,
      ),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  final String url;
  final Map<String, dynamic> plan;
  final Function(String) onError;

  const WebViewScreen({
    Key? key,
    required this.url,
    required this.plan,
    required this.onError,
  }) : super(key: key);

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  final FirestoreService _firestoreService = FirestoreService();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'PaymentHandler',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'success') {
            final coinsToCredit = widget.plan['coins'] as int;
            // Use Future.wait to run both Firestore operations concurrently
            Future.wait([
              _firestoreService.creditCoins(coinsToCredit),
              _firestoreService.updateUserPlan(widget.plan),
            ]).then((_) {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content:
                        Text('$coinsToCredit coins credited successfully!')),
              );
            }).catchError((error) {
              widget.onError(
                  'An error occurred while updating your balance. Please contact support.');
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            });
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            setState(() {
              isLoading = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
        backgroundColor: const Color(0xFF121212),
        foregroundColor: const Color(0xFFE3C887),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
