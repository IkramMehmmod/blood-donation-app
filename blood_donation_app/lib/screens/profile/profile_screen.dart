import 'dart:io';
import 'package:blood_donation_app/widgets/eligibility_status.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_service.dart';

import '../../widgets/custom_dropdown.dart';
import '../../widgets/custom_text_field.dart';
import 'package:intl/intl.dart';
import '../../widgets/not_signed_in_message.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController();

  String _selectedBloodGroup = 'A+';
  bool _isDonor = false;
  File? _imageFile;
  bool _isLoading = false;
  int _totalDonations = 0;
  int _points = 0;
  List<Map<String, dynamic>> _achievements = [];

  // Track which fields are being edited
  Map<String, bool> _editingField = {
    'name': false,
    'phone': false,
    'address': false,
    'city': false,
    'state': false,
    'country': false,
  };

  // Track original values to enable/disable update button
  String _originalName = '';
  String _originalPhone = '';
  String _originalAddress = '';
  String _originalCity = '';
  String _originalState = '';
  String _originalCountry = '';
  String _originalBloodGroup = '';
  bool _originalIsDonor = false;
  bool _hasChanges = false;

  final List<String> _bloodGroups = [
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
    _loadUserData();
    _loadAchievements();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  void _loadUserData() async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user != null) {
      // Data is already decrypted by FirebaseService
      _nameController.text = user.name;
      _phoneController.text = user.phone;
      _addressController.text = user.address;
      _cityController.text = user.city;
      _stateController.text = user.state;
      _countryController.text = user.country;

      // Store original values
      _originalName = user.name;
      _originalPhone = user.phone;
      _originalAddress = user.address;
      _originalCity = user.city;
      _originalState = user.state;
      _originalCountry = user.country;
      _originalBloodGroup = user.bloodGroup;
      _originalIsDonor = user.isDonor;

      setState(() {
        _selectedBloodGroup = user.bloodGroup;
        _isDonor = user.isDonor;
      });
    }
  }

  void _checkForChanges() {
    setState(() {
      _hasChanges = _nameController.text != _originalName ||
          _phoneController.text != _originalPhone ||
          _addressController.text != _originalAddress ||
          _cityController.text != _originalCity ||
          _stateController.text != _originalState ||
          _countryController.text != _originalCountry ||
          _selectedBloodGroup != _originalBloodGroup ||
          _isDonor != _originalIsDonor ||
          _imageFile != null;
    });
  }

  void _toggleEditField(String field) {
    setState(() {
      // Set all fields to non-editing state
      _editingField.forEach((key, value) {
        _editingField[key] = false;
      });
      // Toggle the selected field
      _editingField[field] = true;
    });
  }

  Future<void> _loadAchievements() async {
    try {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      if (user == null) return;

      // Get donation count
      final donations = await _firebaseService.getUserDonations(user.id!);
      final donationCount = donations.length;

      setState(() {
        _totalDonations = donationCount;
        _points = donationCount * 10; // 10 points per donation
        _achievements = [
          {
            'title': 'First Time Donor',
            'description': 'Completed your first blood donation',
            'isUnlocked': donationCount >= 1,
          },
          {
            'title': 'Regular Donor',
            'description': 'Donated blood 5 times',
            'isUnlocked': donationCount >= 5,
          },
          {
            'title': 'Lifesaver',
            'description': 'Donated blood 10 times',
            'isUnlocked': donationCount >= 10,
          },
          {
            'title': 'Blood Hero',
            'description': 'Donated blood 25 times',
            'isUnlocked': donationCount >= 25,
          },
        ];
      });
    } catch (e) {
      debugPrint('Error loading achievements: $e');
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _hasChanges = true;
      });
    } else {
      debugPrint('No image selected');
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate() || !_hasChanges) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;

      if (user == null) {
        throw Exception('User not found');
      }

      String imageUrl = user.imageUrl;

      // Upload new image if selected
      if (_imageFile != null) {
        try {
          final uploadedUrl = await _firebaseService.uploadImageToCloudinary(
              _imageFile!, user.id!);
          if (uploadedUrl != null) {
            imageUrl = uploadedUrl;
          }
        } catch (e) {
          debugPrint('Error uploading image: $e');
          // Continue with profile update even if image upload fails
        }
      }

      // Create updated user model with current lastDonation from user state
      final updatedUser = UserModel(
        id: user.id,
        name: _nameController.text.trim(),
        email: user.email,
        phone: _phoneController.text.trim(),
        bloodGroup: _selectedBloodGroup,
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        country: _countryController.text.trim(),
        imageUrl: imageUrl,
        isDonor: _isDonor,
        lastDonation: user.lastDonation,
        createdAt: user.createdAt,
        updatedAt: DateTime.now(),
      );

      // Update user using FirebaseService
      await _firebaseService.updateUser(updatedUser);

      // Refresh the current user in AuthService
      await authService.refreshCurrentUser();

      if (mounted) {
        setState(() {
          _isLoading = false;
          // Update original values after successful update
          _originalName = _nameController.text;
          _originalPhone = _phoneController.text;
          _originalAddress = _addressController.text;
          _originalCity = _cityController.text;
          _originalState = _stateController.text;
          _originalCountry = _countryController.text;
          _originalBloodGroup = _selectedBloodGroup;
          _originalIsDonor = _isDonor;
          _imageFile = null;
          _hasChanges = false;

          // Reset all editing states
          _editingField.forEach((key, value) {
            _editingField[key] = false;
          });
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
        ),
        body: const NotSignedInMessage(
          message: 'Please sign in to view your profile',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Show confirmation dialog
              final bool? shouldLogout = await showDialog<bool>(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Logout',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  );
                },
              );

              if (shouldLogout == true) {
                final authService =
                    Provider.of<AuthService>(context, listen: false);
                await authService.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              }
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Profile Image
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!)
                          : (user.imageUrl.isNotEmpty
                                  ? NetworkImage(user.imageUrl)
                                  : const AssetImage(
                                      'assets/images/profile_placeholder.png'))
                              as ImageProvider,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                user.email,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),

              // Donation statistics
              Card(
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
                        'Donation Statistics',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            context,
                            icon: Icons.bloodtype,
                            value: _totalDonations.toString(),
                            label: 'Donations',
                          ),
                          _buildStatItem(
                            context,
                            icon: Icons.favorite,
                            value: _totalDonations.toString(),
                            label: 'Lives Saved',
                          ),
                          _buildStatItem(
                            context,
                            icon: Icons.star,
                            value: (_totalDonations * 10).toString(),
                            label: 'Points',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Donation Eligibility Card
              if (user.isDonor) ...[
                Card(
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
                        if (user.lastDonation != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.calendar_today,
                                  color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                'Last Donation: ${DateFormat('MMM d, yyyy').format(user.lastDonation!)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          EligibilityStatus(
                            isEligible: _firebaseService
                                .canUserDonate(user.lastDonation),
                            daysUntilEligible: !_firebaseService
                                    .canUserDonate(user.lastDonation)
                                ? _firebaseService
                                    .getDaysUntilCanDonate(user.lastDonation)
                                : null,
                            eligibleText: 'You are eligible to donate blood',
                            notEligibleText:
                                'You are not eligible to donate yet',
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info, color: Colors.blue),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'No previous donation recorded. You are eligible to donate.',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        const Text(
                          'Note: You must wait 3 months between blood donations for your health and safety.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Personal Information Section
              const Text(
                'Personal Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),

              // Name field with edit icon
              Stack(
                children: [
                  CustomTextField(
                    controller: _nameController,
                    labelText: 'Full Name',
                    hintText: 'Enter your full name',
                    prefixIcon: Icons.person,
                    readOnly: !_editingField['name']!,
                    onChanged: (_) => _checkForChanges(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  Positioned(
                    right: 10,
                    top: 15,
                    child: GestureDetector(
                      onTap: () => _toggleEditField('name'),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: _editingField['name']!
                              ? Theme.of(context).primaryColor.withOpacity(0.1)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: _editingField['name']!
                              ? Theme.of(context).primaryColor
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // Phone field with edit icon
              Stack(
                children: [
                  CustomTextField(
                    controller: _phoneController,
                    labelText: 'Phone Number',
                    hintText: 'Enter your phone number',
                    prefixIcon: Icons.phone,
                    keyboardType: TextInputType.phone,
                    readOnly: !_editingField['phone']!,
                    onChanged: (_) => _checkForChanges(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your phone number';
                      }
                      return null;
                    },
                  ),
                  Positioned(
                    right: 10,
                    top: 15,
                    child: GestureDetector(
                      onTap: () => _toggleEditField('phone'),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: _editingField['phone']!
                              ? Theme.of(context).primaryColor.withOpacity(0.1)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: _editingField['phone']!
                              ? Theme.of(context).primaryColor
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // Blood Group dropdown
              CustomDropdown(
                labelText: 'Blood Group',
                value: _selectedBloodGroup,
                items: _bloodGroups.map((group) {
                  return DropdownMenuItem(
                    value: group,
                    child: Text(group),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedBloodGroup = value.toString();
                    _checkForChanges();
                  });
                },
              ),
              const SizedBox(height: 15),

              // Donor switch
              SwitchListTile(
                title: const Text('I want to be a donor'),
                value: _isDonor,
                activeColor: Theme.of(context).primaryColor,
                onChanged: (value) {
                  setState(() {
                    _isDonor = value;
                    _checkForChanges();
                  });
                },
              ),

              // Last donation date (only show if user is a donor)
              if (_isDonor) ...[
                const SizedBox(height: 15),
                InkWell(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: user.lastDonation ??
                          DateTime.now().subtract(const Duration(days: 90)),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                      helpText: 'Select your last donation date',
                    );
                    if (picked != null) {
                      setState(() {
                        _hasChanges = true;
                      });
                      // Update the user model temporarily for UI and mark as changed
                      final authService =
                          Provider.of<AuthService>(context, listen: false);
                      final updatedUser = user.copyWith(lastDonation: picked);
                      authService.updateCurrentUser(updatedUser);
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Last Donation Date',
                      prefixIcon: const Icon(Icons.calendar_today),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixIcon: user.lastDonation != null
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _hasChanges = true;
                                });
                                final authService = Provider.of<AuthService>(
                                    context,
                                    listen: false);
                                final updatedUser =
                                    user.copyWith(lastDonation: null);
                                authService.updateCurrentUser(updatedUser);
                              },
                            )
                          : null,
                    ),
                    child: Text(
                      user.lastDonation != null
                          ? DateFormat('MMMM d, yyyy')
                              .format(user.lastDonation!)
                          : 'No previous donation recorded',
                      style: TextStyle(
                        color: user.lastDonation != null
                            ? Colors.black
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 15),

              // Address field with edit icon
              Stack(
                children: [
                  CustomTextField(
                    controller: _addressController,
                    labelText: 'Address',
                    hintText: 'Enter your address',
                    prefixIcon: Icons.home,
                    maxLines: 2,
                    readOnly: !_editingField['address']!,
                    onChanged: (_) => _checkForChanges(),
                  ),
                  Positioned(
                    right: 10,
                    top: 15,
                    child: GestureDetector(
                      onTap: () => _toggleEditField('address'),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: _editingField['address']!
                              ? Theme.of(context).primaryColor.withOpacity(0.1)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: _editingField['address']!
                              ? Theme.of(context).primaryColor
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // City field with edit icon
              Stack(
                children: [
                  CustomTextField(
                    controller: _cityController,
                    labelText: 'City',
                    hintText: 'Enter your city',
                    prefixIcon: Icons.location_city,
                    readOnly: !_editingField['city']!,
                    onChanged: (_) => _checkForChanges(),
                  ),
                  Positioned(
                    right: 10,
                    top: 15,
                    child: GestureDetector(
                      onTap: () => _toggleEditField('city'),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: _editingField['city']!
                              ? Theme.of(context).primaryColor.withOpacity(0.1)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: _editingField['city']!
                              ? Theme.of(context).primaryColor
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // State field with edit icon
              Stack(
                children: [
                  CustomTextField(
                    controller: _stateController,
                    labelText: 'State',
                    hintText: 'Enter your state',
                    prefixIcon: Icons.map,
                    readOnly: !_editingField['state']!,
                    onChanged: (_) => _checkForChanges(),
                  ),
                  Positioned(
                    right: 10,
                    top: 15,
                    child: GestureDetector(
                      onTap: () => _toggleEditField('state'),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: _editingField['state']!
                              ? Theme.of(context).primaryColor.withOpacity(0.1)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: _editingField['state']!
                              ? Theme.of(context).primaryColor
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // Country field with edit icon
              Stack(
                children: [
                  CustomTextField(
                    controller: _countryController,
                    labelText: 'Country',
                    hintText: 'Enter your country',
                    prefixIcon: Icons.flag,
                    readOnly: !_editingField['country']!,
                    onChanged: (_) => _checkForChanges(),
                  ),
                  Positioned(
                    right: 10,
                    top: 15,
                    child: GestureDetector(
                      onTap: () => _toggleEditField('country'),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: _editingField['country']!
                              ? Theme.of(context).primaryColor.withOpacity(0.1)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: _editingField['country']!
                              ? Theme.of(context).primaryColor
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Update Profile Button
              Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  gradient: _hasChanges
                      ? LinearGradient(
                          colors: [
                            Theme.of(context).primaryColor,
                            Theme.of(context).primaryColor.withOpacity(0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: _hasChanges ? null : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _hasChanges
                      ? [
                          BoxShadow(
                            color:
                                Theme.of(context).primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : null,
                ),
                child: ElevatedButton(
                  onPressed: _hasChanges ? _updateProfile : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.save_outlined,
                              color: _hasChanges ? Colors.white : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Update Profile',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _hasChanges ? Colors.white : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 30),

              // Achievements section
              if (_achievements.isNotEmpty) ...[
                const Text(
                  'Achievements',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                ..._achievements.map((achievement) => _buildAchievementCard(
                      context,
                      title: achievement['title'] as String,
                      description: achievement['description'] as String,
                      isUnlocked: achievement['isUnlocked'] as bool,
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementCard(
    BuildContext context, {
    required String title,
    required String description,
    required bool isUnlocked,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isUnlocked
                ? Colors.amber.withOpacity(0.2)
                : Colors.grey.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.emoji_events,
            color: isUnlocked ? Colors.amber : Colors.grey,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isUnlocked ? Colors.black : Colors.grey,
          ),
        ),
        subtitle: Text(
          description,
          style: TextStyle(
            color: isUnlocked ? Colors.black87 : Colors.grey,
          ),
        ),
        trailing: isUnlocked
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.lock, color: Colors.grey),
      ),
    );
  }
}
