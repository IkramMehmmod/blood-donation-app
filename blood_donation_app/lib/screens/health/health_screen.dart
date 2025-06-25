import 'package:blood_donation_app/widgets/eligibility_status.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_service.dart';
import '../../widgets/custom_button.dart';
import '../../routes/app_routes.dart';
import '../../widgets/not_signed_in_message.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = false;
  Map<String, dynamic>? _healthData;
  List<Map<String, dynamic>> _donationHistory = [];
  bool _isEligible = true;
  DateTime? _nextDonationDate;

  final List<Map<String, dynamic>> _healthTips = [
    {
      'title': 'Stay Hydrated',
      'description': 'Drink plenty of water before and after donating blood.',
      'icon': Icons.water_drop,
    },
    {
      'title': 'Iron-Rich Foods',
      'description':
          'Eat iron-rich foods like spinach, red meat, and beans to maintain healthy blood levels.',
      'icon': Icons.restaurant,
    },
    {
      'title': 'Regular Exercise',
      'description':
          'Regular moderate exercise helps maintain good cardiovascular health.',
      'icon': Icons.fitness_center,
    },
    {
      'title': 'Avoid Alcohol',
      'description':
          'Avoid alcohol for at least 24 hours before donating blood.',
      'icon': Icons.no_drinks,
    },
    {
      'title': 'Get Enough Sleep',
      'description': 'Ensure you get 7-8 hours of sleep before donating blood.',
      'icon': Icons.bedtime,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadHealthData();
  }

  Future<void> _loadHealthData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      if (user == null) {
        throw Exception('User not found');
      }

      // Get health data from Firebase
      final healthData = await _firebaseService.getHealthData(user.id!);

      if (healthData != null) {
        setState(() {
          _healthData = healthData;
        });
      } else {
        // Create default health data if none exists
        final defaultHealthData = {
          'userId': user.id,
          'weight': 0,
          'height': 0,
          'bloodPressure': '0/0',
          'hemoglobin': 0,
          'lastCheckup': DateTime.now().toIso8601String(),
          'medicalConditions': [],
          'medications': [],
          'allergies': [],
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        };

        await _firebaseService.updateHealthData(user.id!, defaultHealthData);

        setState(() {
          _healthData = defaultHealthData;
        });
      }

      // Get donation history for chart
      final donations = await _firebaseService.getUserDonations(user.id!);

      // Calculate donation eligibility
      if (donations.isNotEmpty) {
        final lastDonation = donations.first.date;
        final eligibleDate = lastDonation.add(const Duration(days: 56));

        if (eligibleDate.isAfter(DateTime.now())) {
          setState(() {
            _isEligible = false;
            _nextDonationDate = eligibleDate;
          });
        }
      }

      // Process donation history for chart
      final Map<int, int> donationsByMonth = {};
      final now = DateTime.now();

      // Initialize all months with 0
      for (int i = 0; i < 12; i++) {
        final month = (now.month - i - 1) % 12 + 1; // Get previous months
        donationsByMonth[month] = 0;
      }

      // Count donations by month for the past year
      for (final donation in donations) {
        if (now.difference(donation.date).inDays <= 365) {
          final month = donation.date.month;
          donationsByMonth[month] = (donationsByMonth[month] ?? 0) + 1;
        }
      }

      // Convert to list for chart
      final List<Map<String, dynamic>> donationHistory = [];
      for (int i = 0; i < 12; i++) {
        final month = (now.month - i - 1) % 12 + 1; // Get previous months
        donationHistory.add({
          'month': month,
          'count': donationsByMonth[month] ?? 0,
        });
      }

      // Sort by month
      donationHistory.sort((a, b) => a['month'].compareTo(b['month']));

      setState(() {
        _donationHistory = donationHistory;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading health data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading health data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateHealthData() async {
    // This would typically open a form to update health data
    // For now, we'll just show a dialog
    Navigator.pushNamed(context, AppRoutes.updateHealth);
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Health Profile'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const NotSignedInMessage(
                message: 'Please sign in to view your health profile',
              ),
              const SizedBox(height: 32),
              const Text(
                'Health Tips',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildHealthTips(),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildUserHealthCard(user),
                  const SizedBox(height: 20),
                  _buildDonationEligibility(user),
                  const SizedBox(height: 20),
                  _buildHealthTips(),
                  const SizedBox(height: 20),
                  _buildDonationChart(),
                ],
              ),
            ),
    );
  }

  Widget _buildUserHealthCard(UserModel? user) {
    final lastDonation = user?.lastDonation;
    final formattedLastDonation = lastDonation != null
        ? DateFormat('MMM d, yyyy').format(lastDonation)
        : 'Never';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: user?.imageUrl.isNotEmpty == true
                      ? NetworkImage(user!.imageUrl)
                      : const AssetImage(
                              'assets/images/profile_placeholder.png')
                          as ImageProvider,
                  child: user?.imageUrl.isEmpty == true
                      ? Text(user?.name.isNotEmpty == true
                          ? user!.name[0].toUpperCase()
                          : 'U')
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'User',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withAlpha((255 * 0.2).round()),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              user?.bloodGroup ?? 'Unknown',
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            user?.isDonor == true ? 'Donor' : 'Not a Donor',
                            style: TextStyle(
                              color: user?.isDonor == true
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            _buildHealthDataRow('Last Donation', formattedLastDonation),
            _buildHealthDataRow(
                'Weight',
                _healthData?['weight'] != null && _healthData!['weight'] > 0
                    ? '${_healthData!['weight']} kg'
                    : 'Not recorded'),
            _buildHealthDataRow(
                'Height',
                _healthData?['height'] != null && _healthData!['height'] > 0
                    ? '${_healthData!['height']} cm'
                    : 'Not recorded'),
            _buildHealthDataRow('Blood Pressure',
                _healthData?['bloodPressure'] ?? 'Not recorded'),
            _buildHealthDataRow(
                'Hemoglobin',
                _healthData?['hemoglobin'] != null &&
                        _healthData!['hemoglobin'] > 0
                    ? '${_healthData!['hemoglobin']} g/dL'
                    : 'Not recorded'),
            _buildHealthDataRow(
                'Last Checkup',
                _healthData?['lastCheckup'] != null
                    ? DateFormat('MMM d, yyyy')
                        .format(DateTime.parse(_healthData!['lastCheckup']))
                    : 'Not recorded'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: 'Update Health Information',
                onPressed: _updateHealthData,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildDonationEligibility(UserModel? user) {
// 56 days = 8 weeks

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Donation Eligibility',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            EligibilityStatus(
              isEligible: _isEligible,
              daysUntilEligible: !_isEligible && _nextDonationDate != null
                  ? _nextDonationDate!.difference(DateTime.now()).inDays
                  : null,
              eligibleText: 'You are eligible to donate',
              notEligibleText: 'You are not eligible to donate yet',
            ),
            const SizedBox(height: 16),
            const Text(
              'Donation Requirements:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildRequirementItem('Must be at least 18 years old'),
            _buildRequirementItem('Weight at least 50 kg (110 lbs)'),
            _buildRequirementItem('Be in good health and feeling well'),
            _buildRequirementItem('Have not donated in the last 56 days'),
            _buildRequirementItem(
                'Have hemoglobin level of at least 12.5 g/dL'),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildHealthTips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Health Tips for Donors',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _healthTips.length,
          itemBuilder: (context, index) {
            final tip = _healthTips[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context)
                      .primaryColor
                      .withAlpha((255 * 0.2).round()),
                  child: Icon(
                    tip['icon'] as IconData,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                title: Text(
                  tip['title'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(tip['description'] as String),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDonationChart() {
    if (_donationHistory.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Donation History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _getMaxDonationCount() + 1,
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const months = [
                            'Jan',
                            'Feb',
                            'Mar',
                            'Apr',
                            'May',
                            'Jun',
                            'Jul',
                            'Aug',
                            'Sep',
                            'Oct',
                            'Nov',
                            'Dec'
                          ];
                          if (value.toInt() >= 0 &&
                              value.toInt() < _donationHistory.length) {
                            final monthIndex =
                                _donationHistory[value.toInt()]['month'] - 1;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                months[monthIndex],
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value % 1 != 0) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              value.toInt().toString(),
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(_donationHistory.length, (index) {
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: _donationHistory[index]['count'].toDouble(),
                          color: Theme.of(context).primaryColor,
                          width: 16,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getMaxDonationCount() {
    if (_donationHistory.isEmpty) return 0;
    return _donationHistory
        .map((e) => e['count'] as int)
        .reduce((a, b) => a > b ? a : b);
  }
}
