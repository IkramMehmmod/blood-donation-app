import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../../models/user_model.dart';
import '../../services/firebase_service.dart';

class DonersScreen extends StatefulWidget {
  const DonersScreen({super.key});

  @override
  State<DonersScreen> createState() => _DonersScreenState();
}

class _DonersScreenState extends State<DonersScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  List<UserModel> _donors = [];
  bool _isLoading = true;
  String _selectedBloodGroup = 'All';
  String _searchQuery = '';

  final List<String> _bloodGroups = [
    'All',
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-'
  ];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDonors();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String formatPhoneNumber(String phone) {
    if (phone.startsWith('+')) return phone; // already international
    if (phone.startsWith('03')) {
      return '+92${phone.substring(1)}'; // e.g., 0301 => +92301
    }
    return phone;
  }

  Future<void> _loadDonors() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get all users who are donors from Firebase
      final donors = await _firebaseService.getDonors();

      setState(() {
        _donors = donors;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading donors: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading donors: $e')),
        );
      }
    }
  }

  List<UserModel> _getFilteredDonors() {
    return _donors.where((donor) {
      // Filter by blood group if not 'All'
      final bloodGroupMatch = _selectedBloodGroup == 'All' ||
          donor.bloodGroup == _selectedBloodGroup;

      // Filter by search query
      final searchMatch = _searchQuery.isEmpty ||
          donor.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          donor.city.toLowerCase().contains(_searchQuery.toLowerCase());

      return bloodGroupMatch && searchMatch;
    }).toList();
  }

  Future<void> _launchPhoneCall(String phoneNumber, String donorName) async {
    try {
      if (phoneNumber.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$donorName has not provided a phone number')),
        );
        return;
      }

      final Uri uri = Uri(scheme: 'tel', path: phoneNumber);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch phone call to $phoneNumber');
      }
    } catch (e) {
      // print('Error launching phone call: $e');
    }
  }

  void _showCallConfirmationDialog(UserModel donor) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;

        return AlertDialog(
          title: const Text('Call Donor'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Do you want to call ${donor.name}?'),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.phone, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    donor.phone.isNotEmpty ? donor.phone : 'No phone number',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      donor.bloodGroup,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: donor.phone.isNotEmpty
                  ? () {
                      Navigator.of(context).pop();
                      _launchPhoneCall(donor.phone, donor.name);
                    }
                  : null,
              icon: const Icon(Icons.call),
              label: const Text('Call'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: Size(screenWidth * 0.35, screenHeight * 0.06),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredDonors = _getFilteredDonors();

    // Uncomment and use this block if you have a not-signed-in logic
    // final user = Provider.of<AuthService>(context).currentUser;
    // if (user == null) {
    //   return Scaffold(
    //     appBar: AppBar(
    //       title: const Text('Blood Donors'),
    //       backgroundColor: Colors.red,
    //       foregroundColor: Colors.white,
    //     ),
    //     body: SingleChildScrollView(
    //       padding: EdgeInsets.all(24),
    //       child: NotSignedInMessage(
    //         message: 'Please sign in to view the list of donors',
    //       ),
    //     ),
    //   );
    // }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blood Donors'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDonors,
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            color: Colors.grey[50],
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name or city',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _bloodGroups.map((group) {
                      final isSelected = _selectedBloodGroup == group;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          label: Text(group),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedBloodGroup = group;
                            });
                          },
                          backgroundColor: Colors.white,
                          selectedColor: Colors.red.withValues(alpha: 0.2),
                          checkmarkColor: Colors.red,
                          side: BorderSide(
                            color: isSelected ? Colors.red : Colors.grey[300]!,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filteredDonors.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No donors found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try adjusting your search or filters',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
          else
            ...filteredDonors.map((donor) {
              final canDonate =
                  _firebaseService.canUserDonate(donor.lastDonation);
              final daysUntilCanDonate =
                  _firebaseService.getDaysUntilCanDonate(donor.lastDonation);
              return GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    builder: (context) => _buildDonorDetails(donor),
                  );
                },
                child: Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar
                        CircleAvatar(
                          radius: 25,
                          backgroundImage: donor.imageUrl.isNotEmpty
                              ? NetworkImage(donor.imageUrl)
                              : null,
                          backgroundColor: Colors.red.withValues(alpha: 0.1),
                          child: donor.imageUrl.isEmpty
                              ? Text(
                                  donor.name.isNotEmpty
                                      ? donor.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        // Main info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                donor.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                // ignore: unnecessary_null_comparison
                                '${donor.city} ${donor.state != null ? ', ${donor.state}' : ''}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  // Blood group pill
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      donor.bloodGroup,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Status pill
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: canDonate
                                          ? Colors.green.withValues(alpha: 0.1)
                                          : Colors.orange
                                              .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      canDonate ? 'Available' : 'Not Available',
                                      style: TextStyle(
                                        color: canDonate
                                            ? Colors.green
                                            : Colors.orange,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (donor.lastDonation != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Last donation: ${_formatDate(donor.lastDonation!)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(height: 4),
                                Text(
                                  'No previous donation recorded',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                              if (!canDonate && daysUntilCanDonate > 0) ...[
                                Text(
                                  'Available in $daysUntilCanDonate days',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Next eligible: ${_formatDate(donor.lastDonation!.add(const Duration(days: 56)))}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[500],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Call icon
                        IconButton(
                          icon: const Icon(Icons.call, color: Colors.green),
                          onPressed: () => _showCallConfirmationDialog(donor),
                          tooltip: 'Call donor',
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDonorDetails(UserModel donor) {
    final canDonate = _firebaseService.canUserDonate(donor.lastDonation);
    final daysUntilCanDonate =
        _firebaseService.getDaysUntilCanDonate(donor.lastDonation);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle for bottom sheet
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              CircleAvatar(
                radius: 35,
                backgroundImage: donor.imageUrl.isNotEmpty
                    ? NetworkImage(donor.imageUrl)
                    : null,
                backgroundColor: Colors.red.withValues(alpha: 0.1),
                child: donor.imageUrl.isEmpty
                    ? Text(
                        donor.name.isNotEmpty
                            ? donor.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 28,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      donor.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Blood group pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            donor.bloodGroup,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Eligibility status pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: canDonate
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            canDonate ? 'Available' : 'Not Available',
                            style: TextStyle(
                              color: canDonate ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          const Text(
            'Contact Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          _buildInfoRow(Icons.email, 'Email', donor.email),
          _buildInfoRow(Icons.phone, 'Phone',
              donor.phone.isNotEmpty ? donor.phone : 'Not provided'),
          _buildInfoRow(
              Icons.location_on,
              'Address',
              // ignore: unnecessary_null_comparison
              '${donor.address} ${donor.city != null ? ', ${donor.city}' : ''} ${donor.state != null ? ', ${donor.state}' : ''} ${donor.country != null ? ', ${donor.country}' : ''}'),

          const SizedBox(height: 16),
          const Text(
            'Donation Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          if (donor.lastDonation != null) ...[
            _buildInfoRow(Icons.calendar_today, 'Last Donation',
                _formatDate(donor.lastDonation!)),
            if (!canDonate && daysUntilCanDonate > 0) ...[
              _buildInfoRow(Icons.access_time, 'Available Again',
                  'In $daysUntilCanDonate days'),
              _buildInfoRow(
                  Icons.event,
                  'Next Eligible Date',
                  _formatDate(
                      donor.lastDonation!.add(const Duration(days: 56)))),
            ],
          ] else ...[
            _buildInfoRow(Icons.info, 'Donation History',
                'No previous donation recorded'),
          ],

          _buildInfoRow(
              Icons.health_and_safety,
              'Donation Status',
              canDonate
                  ? 'Eligible to donate'
                  : 'Not eligible (56-day waiting period)'),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: donor.phone.isNotEmpty
                  ? () {
                      Navigator.pop(context);
                      _launchPhoneCall(donor.phone, donor.name);
                    }
                  : null,
              icon: const Icon(Icons.call),
              label: Text(
                donor.phone.isNotEmpty
                    ? 'Call ${donor.name}'
                    : 'No phone number available',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // Add bottom padding for safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text.isNotEmpty ? text : 'Not provided',
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        text.isNotEmpty ? Colors.grey[800] : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }
}
