import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color kGold = Color(0xFFC5A572);
const Color kBlack = Color(0xFF121212);

class ContactUsScreen extends StatefulWidget {
  final String? userId;
  const ContactUsScreen({super.key, this.userId});

  @override
  _ContactUsScreenState createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _shopAddress;
  String? _phoneNumber;
  String? _email;
  bool _isLoading = true;

  final List<String> _additionalPhoneNumbers = [];
  final List<String> _additionalEmails = [];

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchContactDetails();
  }

  Future<void> _updateContactDetails() async {
    if (widget.userId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
        'additionalPhoneNumbers': _additionalPhoneNumbers,
        'additionalEmails': _additionalEmails,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact details updated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update contact details: $e')),
      );
    }
  }

  Future<void> _fetchContactDetails() async {
    // final user = FirebaseAuth.instance.currentUser;
    if (widget.userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        setState(() {
          _shopAddress = data['shopAddress'] as String?;
          _phoneNumber = data['phoneNumber'] as String?;
          _email = data['email'] as String?;
          _additionalPhoneNumbers.addAll(
              (data['additionalPhoneNumbers'] as List<dynamic>? ?? [])
                  .cast<String>());
          _additionalEmails.addAll(
              (data['additionalEmails'] as List<dynamic>? ?? [])
                  .cast<String>());
        });
      }
    } catch (e) {
      // Handle error
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildCombinedInfoSection(
    IconData icon,
    String title,
    String? primaryItem,
    List<String> additionalItems,
  ) {
    final allItems = [if (primaryItem != null) primaryItem, ...additionalItems];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoTile(icon, title, allItems.isNotEmpty ? allItems.first : 'Not provided'),
        ...allItems.skip(1).map((item) => _buildInfoTile(null, '', item)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        onPressed: _updateContactDetails,
        backgroundColor: kGold,
        child: const Icon(Icons.save, color: Colors.white),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.white,
            floating: true,
            pinned: true,
            elevation: 0,
            centerTitle: true,
            title: Text(
              'Contact Us',
              style: GoogleFonts.playfairDisplay(
                fontSize: 26,
                color: kBlack,
                fontWeight: FontWeight.bold,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: kBlack),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          _isLoading
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              : SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoTile(Icons.location_on, 'Shop Address',
                              _shopAddress ?? 'Not provided'),
                          const SizedBox(height: 20),
                          _buildCombinedInfoSection(
                            Icons.phone,
                            'Phone Number',
                            _phoneNumber,
                            _additionalPhoneNumbers,
                          ),

                          _buildAddMoreField(
                              _phoneController, 'Add another phone number', () {
                            if (_phoneController.text.isNotEmpty) {
                              setState(() {
                                _additionalPhoneNumbers
                                    .add(_phoneController.text);
                                _phoneController.clear();
                              });
                            }
                          }),
                          const SizedBox(height: 20),
                          _buildCombinedInfoSection(
                            Icons.email,
                            'Email Address',
                            _email,
                            _additionalEmails,
                          ),

                          _buildAddMoreField(
                              _emailController, 'Add another email', () {
                            if (_emailController.text.isNotEmpty) {
                              setState(() {
                                _additionalEmails.add(_emailController.text);
                                _emailController.clear();
                              });
                            }
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData? icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Icon(icon, color: kGold, size: 24)
          else
            const SizedBox(width: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    style: GoogleFonts.lato(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: kBlack,
                    ),
                  ),
                if (title.isNotEmpty) const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    color: kBlack.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddMoreField(
      TextEditingController controller, String hintText, VoidCallback onAdd) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: GoogleFonts.lato(color: Colors.grey),
                border: const UnderlineInputBorder(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: kGold),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}
