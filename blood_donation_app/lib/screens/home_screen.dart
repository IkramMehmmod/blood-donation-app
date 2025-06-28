import 'package:blood_donation_app/screens/requests/accepted_requests_screen.dart';
import 'package:blood_donation_app/services/firebase_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/blood_request_card.dart';
import '../widgets/notification_badge.dart';
import '../models/request_model.dart';
import 'map/map_screen.dart';
import 'support/support_screen.dart';
import 'about/about_us_screen.dart';
import 'blood_info/blood_info_screen.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  String _userName = '';
  String _bloodType = '';
  List<RequestModel> _recentRequests = [];
  List<RequestModel> _urgentRequests = [];
  int _totalDonations = 0;
  int _livesSaved = 0;

  bool _isLoadingStats = true;

  // Standardized URL launcher
  Future<void> _launchUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (!await canLaunchUrl(uri)) {
        throw Exception('Could not launch $url');
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error launching URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $url')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoadingStats = true;
    });

    try {
      await _loadUserData();
      await _loadRequests();
    } catch (e) {
      debugPrint('Error loading home data: $e');
    } finally {
      setState(() {});
    }
  }

  Future<void> _loadUserData() async {
    try {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;

      if (user != null) {
        setState(() {
          _userName = user.name;
          _bloodType = user.bloodGroup;
        });

        // Get donation statistics from Firebase
        final stats = await _firebaseService.getUserDonationStats(user.id!);
        final totalDonations = stats['totalDonations'] ?? 0;
        setState(() {
          _totalDonations = totalDonations;
          _livesSaved = totalDonations; // 1 donation = 1 life saved

          _isLoadingStats = false;
        });
      } else {
        setState(() {
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  Future<void> _loadRequests() async {
    try {
      final currentUser =
          Provider.of<AuthService>(context, listen: false).currentUser;
      final requests = await _firebaseService.getRequests();

      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Filter out current user's own requests
      final filteredRequests = requests.where((request) {
        return currentUser == null || request.requesterId != currentUser.id;
      }).toList();

      final urgentRequests = filteredRequests
          .where((request) => request.urgency.toLowerCase() == 'urgent')
          .take(3)
          .toList();

      final recentRequests = filteredRequests
          .where((request) => request.urgency.toLowerCase() != 'urgent')
          .take(5)
          .toList();

      setState(() {
        _recentRequests = recentRequests;
        _urgentRequests = urgentRequests;
      });
    } catch (e) {
      debugPrint('Error loading requests: $e');
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.isNegative) {
      return 'just now';
    }

    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else {
      final minutes = difference.inMinutes;
      return '${minutes > 0 ? minutes : 1} ${minutes == 1 ? 'minute' : 'minutes'} ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('BloodBridge', style: TextStyle(fontSize: 20)),
        actions: [
          IconButton(
            icon: NotificationBadge(
              badgeColor: Colors.white,
              badgeTextColor: Colors.black,
              badgeSize: 12.0,
              padding: EdgeInsets.only(bottom: 40),
              child: Icon(Icons.notifications_outlined, size: 24),
            ),
            onPressed: () {
              Navigator.pushNamed(context, '/notifications');
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            InkWell(
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed('/profile');
              },
              child: DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      backgroundImage: user?.imageUrl.isNotEmpty == true
                          ? NetworkImage(user!.imageUrl)
                          : null,
                      child: user?.imageUrl.isEmpty != false
                          ? Text(
                              user?.name.isNotEmpty == true
                                  ? user!.name[0].toUpperCase()
                                  : 'U',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    SizedBox(height: 8),
                    Text(
                      user?.name ?? 'User',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      user?.email ?? '',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home_outlined, size: 24),
              title: Text('Home', style: TextStyle(fontSize: 16)),
              selected: true,
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.bloodtype_outlined, size: 24),
              title: Text('Donations', style: TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed('/donation');
              },
            ),
            ListTile(
              leading: Icon(Icons.volunteer_activism_outlined, size: 24),
              title: Text('Blood Requests', style: TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed('/requests');
              },
            ),
            ListTile(
              leading: Icon(Icons.favorite_outline, size: 24),
              title: Text('Health', style: TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed('/health');
              },
            ),
            ListTile(
              leading: Icon(Icons.info_outline, size: 24),
              title: Text('Blood Info', style: TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const BloodInfoScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.check_circle_outline, size: 24),
              title: Text('Accepted Requests', style: TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AcceptedRequestsScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.person_outline, size: 24),
              title: Text('Profile', style: TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed('/profile');
              },
            ),
            ListTile(
              leading: NotificationBadge(
                badgeColor: Colors.red,
                badgeTextColor: Colors.white,
                badgeSize: 12.0,
                child: Icon(Icons.notifications_outlined, size: 24),
              ),
              title: Text('Notifications', style: TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed('/notifications');
              },
            ),
            ListTile(
              leading: Icon(Icons.map_outlined, size: 24),
              title: Text('Blood Centers Map', style: TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MapScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.business_outlined, size: 24),
              title: Text('About Us', style: TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AboutUsScreen()),
                );
              },
            ),
            Divider(height: 1),
            ListTile(
              leading: Icon(Icons.settings_outlined, size: 24),
              title: Text('Settings', style: TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed('/settings');
              },
            ),
            ListTile(
              leading: Icon(Icons.logout, size: 24),
              title: Text('Logout', style: TextStyle(fontSize: 16)),
              onTap: () async {
                await authService.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome message
              _buildWelcomeSection(),
              SizedBox(height: 24),

              // Dashboard cards with real-time data
              _buildDashboardStats(context, user?.id),
              SizedBox(height: 24),

              // Quick actions
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildQuickAction(
                    context,
                    icon:
                        const Icon(Icons.add_circle_outline, color: Colors.red),
                    label: 'Request',
                    onTap: () {
                      Navigator.of(context).pushNamed('/requests');
                    },
                  ),
                  _buildQuickAction(
                    context,
                    icon: const Icon(
                      Icons.location_on_outlined,
                      color: Colors.red,
                    ),
                    label: 'Map',
                    onTap: () {
                      Navigator.of(context).pushNamed('/map');
                    },
                  ),
                  _buildQuickAction(
                    context,
                    icon: const Icon(Icons.chat_outlined, color: Colors.red),
                    label: 'Support',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SupportScreen()),
                      );
                    },
                  ),
                  _buildQuickAction(
                    context,
                    icon: const NotificationBadge(
                      badgeColor: Colors.white,
                      badgeSize: 12.0,
                      padding: EdgeInsets.only(top: 0.0, right: 0.0),
                      badgeTextColor: Colors.black,
                      child:
                          Icon(Icons.notifications_outlined, color: Colors.red),
                    ),
                    label: 'Notifications',
                    onTap: () {
                      Navigator.of(context).pushNamed('/notifications');
                    },
                  ),
                ],
              ),
              SizedBox(height: 24),

              // Recent blood requests
              _buildRecentRequests(),
              SizedBox(height: 24),

              // Urgent blood requests
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Urgent Blood Requests',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushNamed('/requests');
                    },
                    child: Text('View All', style: TextStyle(fontSize: 14)),
                  ),
                ],
              ),
              SizedBox(height: 8),
              _buildUrgentRequests(context),
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Theme.of(context).colorScheme.primary,
                backgroundImage: user?.imageUrl.isNotEmpty == true
                    ? NetworkImage(user!.imageUrl)
                    : null,
                child: user?.imageUrl.isEmpty != false
                    ? Text(
                        _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${user != null ? _userName : 'Guest'}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                    ),
                    if (user != null && _bloodType.isNotEmpty)
                      Text(
                        'Blood Type: $_bloodType',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            'Thank you for being a part of our blood donation community. Together, we can save lives!',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 16,
                ),
          ),
          if (user == null) ...[
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text('Sign In / Register', style: TextStyle(fontSize: 16)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentRequests() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Requests',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/requests');
              },
              child: Text('View All', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
        SizedBox(height: 16),
        _recentRequests.isEmpty
            ? Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha((255 * 0.1).round()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bloodtype_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No blood requests',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.grey.shade700,
                                  fontSize: 16,
                                ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'There are no active blood requests at the moment',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recentRequests.length,
                itemBuilder: (context, index) {
                  final request = _recentRequests[index];
                  final postedTime = _getTimeAgo(request.createdAt);

                  return Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      onTap: () {
                        _showRequestDetailsDialog(request);
                      },
                      child: BloodRequestCard(
                        bloodType: request.bloodGroup,
                        hospital: request.hospital,
                        urgency: request.urgency,
                        postedTime: postedTime,
                        requiredDate: request.requiredDate,
                      ),
                    ),
                  );
                },
              ),
      ],
    );
  }

  // Update the _buildDashboardStats method to use consistent statistics
  Widget _buildDashboardStats(BuildContext context, String? userId) {
    if (_isLoadingStats) {
      return SizedBox(
        height: 100,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (userId == null) {
      return _buildDummyDashboardStats(context);
    }

    return Row(
      children: [
        Expanded(
          child: DashboardCard(
            title: 'Total\nDonations',
            value: _totalDonations.toString(),
            icon: Icons.bloodtype_outlined,
            color: Theme.of(context).colorScheme.primary,
            onTap: () {
              Navigator.of(context).pushNamed('/donation');
            },
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: DashboardCard(
            title: 'Lives\nSaved',
            value: _livesSaved.toString(),
            icon: Icons.favorite_outline,
            color: Colors.green,
            onTap: () {
              _showImpactDetails();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDummyDashboardStats(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DashboardCard(
            title: 'Total\nDonations',
            value: '0',
            icon: Icons.bloodtype_outlined,
            color: Theme.of(context).colorScheme.primary,
            onTap: () {
              Navigator.of(context).pushNamed('/donation');
            },
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: DashboardCard(
            title: 'Lives\nSaved',
            value: '0',
            icon: Icons.favorite_outline,
            color: Colors.green,
            onTap: () {
              _showImpactDetails();
            },
          ),
        ),
      ],
    );
  }

  // Update the _showImpactDetails method to use consistent statistics
  void _showImpactDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Your Impact', style: TextStyle(fontSize: 20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite,
              size: 64,
              color: Colors.red,
            ),
            SizedBox(height: 16),
            Text(
              'You have potentially saved',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 16,
                  ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              '$_livesSaved lives',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 32,
                  ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              'Through $_totalDonations donations',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                  ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              'Every donation counts! Thank you for being a hero.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Colors.green,
                    fontSize: 14,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(fontSize: 14)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushNamed('/donation');
            },
            child: Text('View History', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildUrgentRequests(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _urgentRequests.isEmpty
            ? SizedBox(
                width: double.infinity,
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          Icons.volunteer_activism_outlined,
                          size: 48,
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withAlpha((255 * 0.5).round()),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No urgent requests',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontSize: 16,
                                  ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'There are no urgent blood requests at the moment',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: 14,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _urgentRequests.length,
                itemBuilder: (context, index) {
                  final request = _urgentRequests[index];
                  final postedTime = _getTimeAgo(request.createdAt);

                  return Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      onTap: () {
                        _showRequestDetailsDialog(request);
                      },
                      child: BloodRequestCard(
                        bloodType: request.bloodGroup,
                        hospital: request.hospital,
                        urgency: request.urgency,
                        postedTime: postedTime,
                        requiredDate: request.requiredDate,
                      ),
                    ),
                  );
                },
              ),
      ],
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required Widget icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.all(8.0),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: icon,
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRequestDetailsDialog(RequestModel request) {
    final currentUser =
        Provider.of<AuthService>(context, listen: false).currentUser;
    final formattedDate =
        DateFormat('MMM d, yyyy - h:mm a').format(request.createdAt);
    final requiredDateText =
        DateFormat('MMM d, yyyy').format(request.requiredDate);

    // Check if current user has already responded
    final hasResponded =
        currentUser != null && request.responders.contains(currentUser.id);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Request Details', style: TextStyle(fontSize: 20)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      request.bloodGroup,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),
              _buildDetailItem(context, 'Patient Name', request.patientName),
              _buildDetailItem(context, 'Hospital', request.hospital),
              _buildDetailItem(context, 'Urgency', request.urgency,
                  valueColor:
                      request.urgency == 'urgent' ? Colors.red : Colors.orange),
              _buildDetailItem(
                  context, 'Units Needed', request.units.toString()),
              _buildDetailItem(
                  context, 'Contact Number', request.contactNumber),
              _buildDetailItem(context, 'Requester', request.requesterName),
              _buildDetailItem(context, 'Created On', formattedDate),
              _buildDetailItem(context, 'Required By', requiredDateText),
              _buildDetailItem(context, 'Status', request.status,
                  valueColor: request.status == 'open'
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey),
              if (request.additionalInfo.isNotEmpty) ...[
                SizedBox(height: 8),
                Text(
                  'Additional Information:',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                ),
                SizedBox(height: 4),
                Text(
                  request.additionalInfo,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                      ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(fontSize: 14)),
          ),
          // Show accept button only if user is logged in and hasn't responded
          if (currentUser != null && !hasResponded && request.status == 'open')
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _acceptRequestFromHome(request);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: Text(
                'Accept Request',
                style: TextStyle(fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(BuildContext context, String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: valueColor,
                    fontSize: 14,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptRequestFromHome(RequestModel request) async {
    try {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You must be logged in to accept a request',
              style: TextStyle(fontSize: 14),
            ),
          ),
        );
        return;
      }

      // Check if user can donate (56 days rule)
      if (!_firebaseService.canUserDonate(user.lastDonation)) {
        final daysUntil =
            _firebaseService.getDaysUntilCanDonate(user.lastDonation);
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.access_time, color: Colors.orange),
                SizedBox(width: 8),
                Text('Cannot Donate Yet'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'You cannot accept donation requests yet as you need to wait 56 days (8 weeks) between donations.'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Last Donation: ${DateFormat('MMM d, yyyy').format(user.lastDonation!)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You can donate again in $daysUntil days',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Next eligible date: ${DateFormat('MMM d, yyyy').format(user.lastDonation!.add(const Duration(days: 56)))}',
                        style: TextStyle(
                          color: Colors.orange.shade600,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'This waiting period ensures your health and safety. Thank you for your understanding!',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Understood'),
              ),
            ],
          ),
        );
        return;
      }

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              SizedBox(
                  width: 24,
                  height: 24,
                  child: const CircularProgressIndicator()),
              SizedBox(width: 16),
              Text('Accepting request...', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
      );

      // Accept request using Firebase service
      await _firebaseService.acceptRequest(request.id!, user.id!);

      // Create notification for requester if not self
      if (request.requesterId.isNotEmpty && request.requesterId != user.id) {
        await _firebaseService.createNotification(
          userId: request.requesterId,
          title: 'New Response to Blood Request',
          message:
              '${user.name} has accepted your blood request for ${request.bloodGroup}',
          type: 'request',
          referenceId: request.id!,
          data: {
            'requestId': request.id!,
            'bloodType': request.bloodGroup,
            'patientName': request.patientName,
            'hospital': request.hospital
          },
        );
      }

      // Close loading dialog
      Navigator.pop(context);

      // Reload data to reflect changes
      await _loadData();

      // Show success message with call option
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 24),
                SizedBox(width: 8),
                Text('Request Accepted', style: TextStyle(fontSize: 20)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('You have successfully accepted this blood request!',
                    style: TextStyle(fontSize: 14)),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contact Information:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.phone, size: 20, color: Colors.green),
                          SizedBox(width: 8),
                          Text(request.contactNumber,
                              style: TextStyle(fontSize: 14)),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person, size: 20, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(request.requesterName,
                              style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Text('Would you like to contact the requester now?',
                    style: TextStyle(fontSize: 14)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Later', style: TextStyle(fontSize: 14)),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _launchUrl('tel:${request.contactNumber}');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                icon: Icon(Icons.call, color: Colors.white, size: 20),
                label: Text('Call Now',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if it's open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error accepting request: $e',
              style: TextStyle(fontSize: 14)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
