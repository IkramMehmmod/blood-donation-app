import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../services/firebase_service.dart';
import '../../services/donation_service.dart';

class DonorsScreen extends StatefulWidget {
  const DonorsScreen({super.key});

  @override
  State<DonorsScreen> createState() => _DonorsScreenState();
}

class _DonorsScreenState extends State<DonorsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final DonationService _donationService = DonationService();
  List<UserModel> _donors = [];
  List<UserModel> _filteredDonors = [];
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
        _filteredDonors = donors;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading donors: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading donors: $e'),
            duration: Duration(seconds: 16),
          ),
        );
      }
    }
  }

  List<UserModel> _getFilteredDonors() {
    List<UserModel> filtered = _donors;

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((donor) {
        final name = donor.name.toLowerCase();
        final city = donor.city.toLowerCase();
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || city.contains(query);
      }).toList();
    }

    // Filter by blood group
    if (_selectedBloodGroup != 'All') {
      filtered = filtered.where((donor) {
        return donor.bloodGroup == _selectedBloodGroup;
      }).toList();
    }

    return filtered;
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
      print('Error launching phone call: $e');
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
                      color: Colors.red.withOpacity(0.2),
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

    return Column(
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
                  hintStyle: const TextStyle(fontSize: 14.0),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 20.0,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 12.0,
                    horizontal: 16.0,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
              const SizedBox(height: 12.0),
              SizedBox(
                height: 40.0,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _bloodGroups.map((group) {
                    final isSelected = _selectedBloodGroup == group;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text(
                          group,
                          style: const TextStyle(fontSize: 12.0),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedBloodGroup = group;
                          });
                        },
                        backgroundColor: Colors.white,
                        selectedColor: Colors.red.withOpacity(0.2),
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
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 3.0,
                  ),
                )
              : filteredDonors.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64.0,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16.0),
                          Text(
                            'No donors found',
                            style: TextStyle(
                              fontSize: 18.0,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          Text(
                            'Try adjusting your search or filters',
                            style: TextStyle(
                              fontSize: 14.0,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredDonors.length,
                      itemBuilder: (context, index) {
                        final donor = filteredDonors[index];
                        final canDonate = _donationService
                            .isEligibleToDonate(donor.lastDonation);
                        final daysUntilCanDonate = _donationService
                            .getDaysUntilEligible(donor.lastDonation);

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 4.0,
                          ),
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16.0),
                            leading: CircleAvatar(
                              radius: 25.0,
                              backgroundImage: donor.imageUrl.isNotEmpty
                                  ? NetworkImage(donor.imageUrl)
                                  : null,
                              backgroundColor: Colors.red.withOpacity(0.1),
                              child: donor.imageUrl.isEmpty
                                  ? Text(
                                      donor.name.isNotEmpty
                                          ? donor.name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18.0,
                                      ),
                                    )
                                  : null,
                            ),
                            title: Text(
                              donor.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16.0,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4.0),
                                Text(
                                  '${donor.city}${donor.state.isNotEmpty ? ', ${donor.state}' : ''}',
                                  style: TextStyle(
                                    fontSize: 14.0,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8.0),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0,
                                        vertical: 4.0,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(6.0),
                                      ),
                                      child: Text(
                                        donor.bloodGroup,
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.0,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8.0),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0,
                                        vertical: 4.0,
                                      ),
                                      decoration: BoxDecoration(
                                        color: canDonate
                                            ? Colors.green.withOpacity(0.1)
                                            : Colors.orange.withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(6.0),
                                      ),
                                      child: Text(
                                        canDonate
                                            ? 'Available'
                                            : 'Not Available',
                                        style: TextStyle(
                                          color: canDonate
                                              ? Colors.green
                                              : Colors.orange,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.0,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (donor.lastDonation != null) ...[
                                  const SizedBox(height: 4.0),
                                  Text(
                                    'Last donation: ${_formatDate(donor.lastDonation!)}',
                                    style: TextStyle(
                                      fontSize: 11.0,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ] else ...[
                                  const SizedBox(height: 4.0),
                                  Text(
                                    'No previous donation recorded',
                                    style: TextStyle(
                                      fontSize: 11.0,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                                if (!canDonate && daysUntilCanDonate > 0) ...[
                                  const SizedBox(height: 4.0),
                                  Text(
                                    'Available in $daysUntilCanDonate days',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12.0,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.phone,
                                size: 20.0,
                                color: Colors.red,
                              ),
                              onPressed: () =>
                                  _showCallConfirmationDialog(donor),
                            ),
                            onTap: () {
                              // Show donor details
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
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildDonorDetails(UserModel donor) {
    final canDonate = _donationService.isEligibleToDonate(donor.lastDonation);
    final daysUntilCanDonate =
        _donationService.getDaysUntilEligible(donor.lastDonation);

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
                backgroundColor: Colors.red.withOpacity(0.1),
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: canDonate
                                ? Colors.green.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
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
          _buildInfoRow(Icons.location_on, 'Address',
              '${donor.address}${donor.address.isNotEmpty ? ', ' : ''}${donor.city}${donor.state.isNotEmpty ? ', ${donor.state}' : ''}${donor.country.isNotEmpty ? ', ${donor.country}' : ''}'),

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
            if (!canDonate && daysUntilCanDonate > 0)
              _buildInfoRow(Icons.access_time, 'Available Again',
                  'In $daysUntilCanDonate days'),
          ] else ...[
            _buildInfoRow(Icons.info, 'Donation History',
                'No previous donation recorded'),
          ],

          _buildInfoRow(
              Icons.health_and_safety,
              'Donation Status',
              canDonate
                  ? 'Eligible to donate'
                  : 'Not eligible (3-month waiting period)'),

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
