import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/request_model.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_service.dart';

class AcceptedRequestsScreen extends StatefulWidget {
  const AcceptedRequestsScreen({super.key});

  @override
  State<AcceptedRequestsScreen> createState() => _AcceptedRequestsScreenState();
}

class _AcceptedRequestsScreenState extends State<AcceptedRequestsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  List<RequestModel> _acceptedRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAcceptedRequests();
  }

  Future<void> _loadAcceptedRequests() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser =
          Provider.of<AuthService>(context, listen: false).currentUser;
      if (currentUser != null) {
        // Get requests that the current user has accepted
        final acceptedRequests =
            await _firebaseService.getAcceptedRequests(currentUser.id!);

        if (mounted) {
          setState(() {
            _acceptedRequests = acceptedRequests;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _acceptedRequests = [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading accepted requests: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      // print('Error launching URL: $e');
    }
  }

  Future<void> _launchPhoneCall(String phoneNumber) async {
    await _launchUrl('tel:$phoneNumber');
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AuthService>(context).currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accepted Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAcceptedRequests,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: currentUser == null
          ? _buildNotSignedInView()
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _acceptedRequests.isEmpty
                  ? _buildEmptyView()
                  : _buildRequestsList(),
    );
  }

  Widget _buildNotSignedInView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_circle_outlined,
            size: 64,
            color: Theme.of(context)
                .colorScheme
                .primary
                .withAlpha((255 * 0.5).round()),
          ),
          const SizedBox(height: 16),
          Text(
            'Not signed in',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Please sign in to view your accepted requests',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withAlpha((255 * 0.7).round()),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.volunteer_activism_outlined,
            size: 64,
            color: Theme.of(context)
                .colorScheme
                .primary
                .withAlpha((255 * 0.5).round()),
          ),
          const SizedBox(height: 16),
          Text(
            'No accepted requests',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'You haven\'t accepted any blood requests yet',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withAlpha((255 * 0.7).round()),
                ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/requests');
            },
            icon: const Icon(Icons.search),
            label: const Text('Browse Requests'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList() {
    return RefreshIndicator(
      onRefresh: _loadAcceptedRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _acceptedRequests.length,
        itemBuilder: (context, index) {
          final request = _acceptedRequests[index];
          return _buildAcceptedRequestCard(request);
        },
      ),
    );
  }

  Widget _buildAcceptedRequestCard(RequestModel request) {
    // Calculate time since posted
    final now = DateTime.now();
    final difference = now.difference(request.createdAt);

    String postedTime;
    if (difference.inDays > 0) {
      postedTime =
          '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      postedTime =
          '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else {
      postedTime =
          '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    }

    final Color urgencyColor =
        request.urgency == 'urgent' ? Colors.red : Colors.orange;
    final Color statusColor = request.status == 'open'
        ? Theme.of(context).colorScheme.primary
        : request.status == 'fulfilled'
            ? Colors.green
            : Colors.grey;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withAlpha((255 * 0.1).round()),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      request.bloodGroup,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.patientName,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        request.hospital,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  urgencyColor.withAlpha((255 * 0.1).round()),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              request.urgency,
                              style: TextStyle(
                                color: urgencyColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withAlpha((255 * 0.1).round()),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              request.status,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            postedTime,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey,
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

            // Request details
            Row(
              children: [
                const Icon(Icons.water_drop_outlined,
                    size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Units Needed: ${request.units}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Required by: ${DateFormat('MMM d, yyyy').format(request.requiredDate)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Requester: ${request.requesterName}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Location: ${request.location}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // Contact section
            Row(
              children: [
                const Icon(Icons.phone, size: 20, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Contact: ${request.contactNumber}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _launchPhoneCall(request.contactNumber),
                  icon: const Icon(Icons.call, size: 18),
                  label: const Text('Call'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),

            if (request.additionalInfo.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Additional Information:',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.additionalInfo,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
