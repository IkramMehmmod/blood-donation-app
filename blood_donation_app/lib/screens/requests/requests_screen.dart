import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/request_model.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/not_signed_in_message.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseService _firebaseService = FirebaseService();

  // Form controllers for creating a new request
  final _patientNameController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _unitsNeededController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _additionalInfoController = TextEditingController();

  String _selectedBloodType = 'A+';
  String _selectedUrgency = 'normal';
  DateTime _requiredDate = DateTime.now().add(const Duration(days: 1));
  bool _isLoading = false;
  bool _isLoadingRequests = true;

  // Track which fields have been touched/edited
  Map<String, bool> _fieldTouched = {
    'patientName': false,
    'hospital': false,
    'unitsNeeded': false,
    'contactNumber': false,
  };

  // Store requests to avoid repeated fetching
  List<RequestModel> _availableRequests = [];
  List<RequestModel> _myRequests = [];

  final List<String> _bloodTypes = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Pre-fill contact number if available
    _loadUserData();

    // Check for expired requests and close them
    _closeExpiredRequests();

    // Load requests initially
    _loadAllRequests();
  }

  Future<void> _loadAllRequests() async {
    setState(() {
      _isLoadingRequests = true;
    });

    try {
      final currentUser =
          Provider.of<AuthService>(context, listen: false).currentUser;
      if (currentUser != null) {
        // Load all open requests
        final allRequests = await _firebaseService.getRequests();

        // Load user's requests (both open and closed)
        final userRequests =
            await _firebaseService.getUserRequests(currentUser.id!);

        if (mounted) {
          setState(() {
            _availableRequests = allRequests
                .where((request) => request.requesterId != currentUser.id)
                .toList();
            _myRequests = userRequests;
            _isLoadingRequests = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _availableRequests = [];
            _myRequests = [];
            _isLoadingRequests = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading requests: $e');
      if (mounted) {
        setState(() {
          _isLoadingRequests = false;
        });
      }
    }
  }

  Future<void> _loadUserData() async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user != null && user.phone.isNotEmpty) {
      setState(() {
        _contactNumberController.text = user.phone;
      });
    }
  }

  Future<void> _closeExpiredRequests() async {
    try {
      await _firebaseService.closeExpiredRequests();
    } catch (e) {
      debugPrint('Error closing expired requests: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _patientNameController.dispose();
    _hospitalController.dispose();
    _unitsNeededController.dispose();
    _contactNumberController.dispose();
    _additionalInfoController.dispose();
    super.dispose();
  }

  // Validate all fields and return true if all required fields are filled
  bool _validateFields(BuildContext dialogContext) {
    bool isValid = true;
    String errorMessage = '';

    // Update touched status for all fields
    _fieldTouched['patientName'] = true;
    _fieldTouched['hospital'] = true;
    _fieldTouched['unitsNeeded'] = true;
    _fieldTouched['contactNumber'] = true;

    if (_patientNameController.text.isEmpty) {
      errorMessage = 'Patient name is required';
      isValid = false;
    } else if (_hospitalController.text.isEmpty) {
      errorMessage = 'Hospital name is required';
      isValid = false;
    } else if (_unitsNeededController.text.isEmpty) {
      errorMessage = 'Units needed is required';
      isValid = false;
    } else if (_contactNumberController.text.isEmpty) {
      errorMessage = 'Contact number is required';
      isValid = false;
    } else if (_unitsNeededController.text.isNotEmpty &&
        int.tryParse(_unitsNeededController.text) == null) {
      errorMessage = 'Units needed must be a valid number';
      isValid = false;
    } else if (_unitsNeededController.text.isNotEmpty) {
      final units = int.parse(_unitsNeededController.text);
      if (units > 2) {
        errorMessage =
            'Maximum 2 units allowed per request. For more blood, please create another request.';
        isValid = false;
      } else if (units < 1) {
        errorMessage = 'Minimum 1 unit required';
        isValid = false;
      }
    }

    if (!isValid && errorMessage.isNotEmpty) {
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }

    return isValid;
  }

  Future<void> _createRequest(BuildContext dialogContext) async {
    // Validate fields but don't close dialog if invalid
    if (!_validateFields(dialogContext)) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Create request model
      final request = RequestModel(
        requesterId: user.id!,
        requesterName: user.name,
        bloodGroup: _selectedBloodType,
        units: int.parse(_unitsNeededController.text),
        hospital: _hospitalController.text,
        patientName: _patientNameController.text,
        location: '${user.city}, ${user.state}', // Add location from user data
        urgency: _selectedUrgency,
        status: 'open',
        contactNumber: _contactNumberController.text,
        additionalInfo: _additionalInfoController.text,
        createdAt: DateTime.now(),
        requiredDate: _requiredDate,
        responders: [],
      );

      // Add request using FirebaseService
      await _firebaseService.addRequest(request);

      // Clear form
      _patientNameController.clear();
      _hospitalController.clear();
      _unitsNeededController.clear();
      _additionalInfoController.clear();

      // Reset touched fields
      _fieldTouched = {
        'patientName': false,
        'hospital': false,
        'unitsNeeded': false,
        'contactNumber': false,
      };

      // Reload requests to show the new one
      await _loadAllRequests();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Blood request created successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Close dialog only on successful creation
        Navigator.of(dialogContext).pop();

        // Switch to my requests tab
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          SnackBar(content: Text('Error creating request: $e')),
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

  Future<void> _acceptRequest(
    String requestId,
    String bloodType,
    String patientName,
    String hospital,
    String contactNumber,
  ) async {
    try {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to accept a request'),
          ),
        );
        return;
      }

      // Check if user can donate (3 months rule)
      if (!_firebaseService.canUserDonate(user.lastDonation)) {
        final daysUntil =
            _firebaseService.getDaysUntilCanDonate(user.lastDonation);
        showDialog(
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
                    'You cannot accept donation requests yet as you need to wait 3 months between donations.'),
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

      // Rest of the existing _acceptRequest code...
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Accepting request...'),
            ],
          ),
        ),
      );

      // Accept the request using Firebase service
      await _firebaseService.acceptRequest(requestId, user.id!);

      // Get requester ID and create notification if valid
      final requesterId = await _firebaseService.getRequesterId(requestId);
      if (requesterId != null && requesterId.isNotEmpty) {
        await _firebaseService.createNotification(
          userId: requesterId,
          title: 'New Response to Blood Request',
          message:
              '${user.name} has accepted your blood request for $bloodType',
          type: 'request',
          data: {
            'requestId': requestId,
            'bloodType': bloodType,
            'patientName': patientName,
            'hospital': hospital,
          },
        );
      }

      // Close loading dialog
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Reload updated request list
      await _loadAllRequests();

      // Show success dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Request Accepted'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'You have successfully accepted this blood request!'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Contact Information:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.phone,
                              size: 20, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(contactNumber),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Would you like to contact the requester now?'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Later'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _launchPhoneCall(contactNumber);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                icon: const Icon(Icons.call, color: Colors.white),
                label: const Text('Call Now',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error accepting request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _closeRequest(String requestId) async {
    try {
      await _firebaseService.closeRequest(requestId);

      // Reload requests to reflect changes
      await _loadAllRequests();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request closed successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error closing request: $e')),
      );
    }
  }

  Future<void> _launchPhoneCall(String phoneNumber) async {
    final Uri uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not launch phone call to $phoneNumber')),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _requiredDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && picked != _requiredDate) {
      setState(() {
        _requiredDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blood Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllRequests,
            tooltip: 'Refresh Requests',
          ),
        ],
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            TabBar(
              tabs: const [
                Tab(text: 'Available Requests'),
                Tab(text: 'My Requests'),
              ],
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor:
                  Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
              indicatorColor: Theme.of(context).colorScheme.primary,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildAvailableRequestsTab(),
                  _buildMyRequestsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showCreateRequestDialog(context);
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildAvailableRequestsTab() {
    final currentUser = Provider.of<AuthService>(context).currentUser;

    if (currentUser == null) {
      return const NotSignedInMessage(
        message: 'Please sign in to view blood requests',
      );
    }

    if (_isLoadingRequests) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_availableRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.volunteer_activism_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No blood requests',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'There are no open blood requests at the moment',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onBackground
                        .withOpacity(0.7),
                  ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadAllRequests,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _availableRequests.length,
        itemBuilder: (context, index) {
          final request = _availableRequests[index];

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

          // Check if current user has already responded
          final hasResponded = request.responders.contains(currentUser.id);

          // Format required date
          final requiredDateText =
              DateFormat('MMM d, yyyy').format(request.requiredDate);

          return _buildRequestCard(
            bloodType: request.bloodGroup,
            patientName: request.patientName,
            hospital: request.hospital,
            urgency: request.urgency,
            postedTime: postedTime,
            status: request.status,
            unitsNeeded: request.units,
            contactNumber: request.contactNumber,
            requiredDate: requiredDateText,
            isMyRequest: false,
            onAcceptPressed: hasResponded || request.status != 'open'
                ? null
                : () {
                    _showAcceptDialog(
                        context,
                        request.id!,
                        request.bloodGroup,
                        request.patientName,
                        request.hospital,
                        request.contactNumber);
                  },
            onViewDetailsPressed: () {
              _showRequestDetails(context, request);
            },
          );
        },
      ),
    );
  }

  Widget _buildMyRequestsTab() {
    final currentUser = Provider.of<AuthService>(context).currentUser;
    if (currentUser == null) {
      return const NotSignedInMessage(
        message: 'Please sign in to view your blood requests',
      );
    }

    if (_isLoadingRequests) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_myRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.volunteer_activism_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No requests yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'You haven\'t created any blood requests yet',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onBackground
                        .withOpacity(0.7),
                  ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                _showCreateRequestDialog(context);
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Request'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myRequests.length,
        itemBuilder: (context, index) {
          final request = _myRequests[index];

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

          // Format required date
          final requiredDateText =
              DateFormat('MMM d, yyyy').format(request.requiredDate);

          return _buildRequestCard(
            bloodType: request.bloodGroup,
            patientName: request.patientName,
            hospital: request.hospital,
            urgency: request.urgency,
            postedTime: postedTime,
            status: request.status,
            unitsNeeded: request.units,
            contactNumber: request.contactNumber,
            requiredDate: requiredDateText,
            isMyRequest: true,
            onClosePressed: request.status == 'open'
                ? () {
                    _closeRequest(request.id!);
                  }
                : null,
            onViewDetailsPressed: () {
              _showRequestDetails(context, request);
            },
            // Show responder count
            responderCount: request.responders.length,
          );
        },
      ),
    );
  }

  Widget _buildRequestCard({
    required String bloodType,
    required String patientName,
    required String hospital,
    required String urgency,
    required String postedTime,
    required String status,
    required int unitsNeeded,
    required String contactNumber,
    String requiredDate = '',
    required bool isMyRequest,
    VoidCallback? onAcceptPressed,
    VoidCallback? onClosePressed,
    required VoidCallback onViewDetailsPressed,
    int responderCount = 0,
  }) {
    final Color urgencyColor = urgency == 'urgent' ? Colors.red : Colors.orange;
    final Color statusColor = status == 'open'
        ? Theme.of(context).colorScheme.primary
        : status == 'fulfilled'
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
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      bloodType,
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
                        patientName,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hospital,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: urgencyColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              urgency,
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
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              status,
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
            Row(
              children: [
                const Icon(
                  Icons.water_drop_outlined,
                  size: 20,
                  color: Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Units Needed: $unitsNeeded',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            if (requiredDate.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 20,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Required by: $requiredDate',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
            // Show responder count for my requests
            if (isMyRequest && responderCount > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.people_outline,
                    size: 20,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Responders: $responderCount',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            // Consistent button layout for both tabs
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onViewDetailsPressed,
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('View Details'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isMyRequest ? onClosePressed : onAcceptPressed,
                    icon: Icon(
                      isMyRequest
                          ? (status == 'open'
                              ? Icons.close
                              : Icons.check_circle)
                          : (onAcceptPressed == null
                              ? Icons.check_circle
                              : Icons.volunteer_activism),
                      size: 18,
                    ),
                    label: Text(
                      isMyRequest
                          ? (status == 'open' ? 'Close Request' : 'Closed')
                          : (onAcceptPressed == null
                              ? 'Accepted'
                              : 'Accept Request'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isMyRequest
                          ? (status == 'open' ? Colors.red : Colors.grey)
                          : (onAcceptPressed == null
                              ? Colors.green
                              : Theme.of(context).colorScheme.primary),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateRequestDialog(BuildContext context) {
    // Reset field touched status
    _fieldTouched = {
      'patientName': false,
      'hospital': false,
      'unitsNeeded': false,
      'contactNumber': false,
    };

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Blood Request'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Patient name
                CustomTextField(
                  controller: _patientNameController,
                  labelText: 'Patient Name',
                  hintText: 'Enter patient name',
                  prefixIcon: Icons.person_outline,
                  validator: (value) {
                    if (_fieldTouched['patientName'] == true &&
                        (value == null || value.isEmpty)) {
                      return 'Please enter patient name';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    setDialogState(() {
                      _fieldTouched['patientName'] = true;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Blood type
                DropdownButtonFormField<String>(
                  value: _selectedBloodType,
                  decoration: InputDecoration(
                    labelText: 'Blood Type',
                    prefixIcon: const Icon(Icons.bloodtype_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: _bloodTypes
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        _selectedBloodType = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Units needed (restricted to 1-2 only)
                CustomTextField(
                  controller: _unitsNeededController,
                  labelText: 'Units Needed (Max 2)',
                  hintText: 'Enter 1 or 2 units',
                  prefixIcon: Icons.water_drop_outlined,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (_fieldTouched['unitsNeeded'] == true) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter units needed';
                      }
                      final intValue = int.tryParse(value);
                      if (intValue == null) {
                        return 'Please enter a valid number';
                      }
                      if (intValue > 2) {
                        return 'Max 2 units per request';
                      }
                      if (intValue < 1) {
                        return 'Minimum 1 unit required';
                      }
                    }
                    return null;
                  },
                  onChanged: (value) {
                    setDialogState(() {
                      _fieldTouched['unitsNeeded'] = true;
                    });

                    // Show message if user enters more than 2
                    if (value.isNotEmpty) {
                      final intValue = int.tryParse(value);
                      if (intValue != null && intValue > 2) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Maximum 2 units allowed per request. For more blood, please create another request.'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Hospital
                CustomTextField(
                  controller: _hospitalController,
                  labelText: 'Hospital',
                  hintText: 'Enter hospital name',
                  prefixIcon: Icons.local_hospital_outlined,
                  validator: (value) {
                    if (_fieldTouched['hospital'] == true &&
                        (value == null || value.isEmpty)) {
                      return 'Please enter hospital name';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    setDialogState(() {
                      _fieldTouched['hospital'] = true;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Required Date
                InkWell(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _requiredDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (picked != null && picked != _requiredDate) {
                      setDialogState(() {
                        _requiredDate = picked;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Required By',
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      DateFormat('MMMM d, yyyy').format(_requiredDate),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Urgency
                DropdownButtonFormField<String>(
                  value: _selectedUrgency,
                  decoration: InputDecoration(
                    labelText: 'Urgency',
                    prefixIcon: const Icon(Icons.priority_high_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'normal', child: Text('Normal')),
                    DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        _selectedUrgency = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Contact number
                CustomTextField(
                  controller: _contactNumberController,
                  labelText: 'Contact Number',
                  hintText: 'Enter contact number',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (_fieldTouched['contactNumber'] == true &&
                        (value == null || value.isEmpty)) {
                      return 'Please enter contact number';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    setDialogState(() {
                      _fieldTouched['contactNumber'] = true;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Additional info
                CustomTextField(
                  controller: _additionalInfoController,
                  labelText: 'Additional Information (Optional)',
                  hintText: 'Enter any additional details',
                  prefixIcon: Icons.info_outline,
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      // Don't close dialog here, let the createRequest method handle it
                      _createRequest(dialogContext);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAcceptDialog(
      BuildContext context,
      String requestId,
      String bloodType,
      String patientName,
      String hospital,
      String contactNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Blood Request'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You are accepting a blood request for:',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        bloodType,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
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
                          patientName,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        Text(
                          hospital,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Please confirm your availability to donate blood for this request. After accepting, you will be able to contact the requester directly.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _acceptRequest(
                  requestId, bloodType, patientName, hospital, contactNumber);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _showRequestDetails(BuildContext context, RequestModel request) async {
    final formattedDate =
        DateFormat('MMM d, yyyy - h:mm a').format(request.createdAt);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Details'),
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
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
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
              const SizedBox(height: 16),
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
              _buildDetailItem(context, 'Required By',
                  DateFormat('MMM d, yyyy').format(request.requiredDate)),
              _buildDetailItem(context, 'Status', request.status,
                  valueColor: request.status == 'open'
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey),
              _buildDetailItem(
                  context, 'Responders', request.responders.length.toString()),
              if (request.additionalInfo.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Additional Information:',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  request.additionalInfo,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Close'),
          ),
          if (request.status == 'open')
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _closeRequest(request.id!);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: const Text('Close Request'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(BuildContext context, String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: valueColor,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
