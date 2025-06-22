import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../../services/firebase_service.dart';
import '../about/about_us_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _notificationsEnabled = true;
  bool _locationEnabled = true;
  bool _isLoading = false;
  bool _prefsError = false;
  final String _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Try to get shared preferences
      final prefs = await SharedPreferences.getInstance();

      setState(() {
        _notificationsEnabled = prefs.getBool('notifications') ?? true;
        _locationEnabled = prefs.getBool('location') ?? true;
        _prefsError = false;
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
      // Set default values if shared preferences fails
      setState(() {
        _notificationsEnabled = true;
        _locationEnabled = true;
        _prefsError = true;
      });

      // Try to load from Firebase as a fallback
      _loadSettingsFromFirebase();

      // Show error only if not a MissingPluginException (which is expected during hot reload)
      if (!e.toString().contains('MissingPluginException')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    try {
      // If we had an error loading prefs, don't try to save
      if (_prefsError) {
        // Save to Firebase instead
        await _saveSettingsToFirebase();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Settings saved to cloud (shared_preferences unavailable)'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool('notifications', _notificationsEnabled);
      await prefs.setBool('location', _locationEnabled);

      // Also save to Firebase for backup
      await _saveSettingsToFirebase();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving settings: $e')),
      );
    }
  }

  // Load settings from Firebase as a fallback
  Future<void> _loadSettingsFromFirebase() async {
    try {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      if (user == null) return;

      final settings = await _firebaseService.getUserSettings(user.id!);

      if (settings != null) {
        setState(() {
          _notificationsEnabled = settings['notifications'] ?? true;
          _locationEnabled = settings['location'] ?? true;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings from Firebase: $e');
    }
  }

  // Save settings to Firebase
  Future<void> _saveSettingsToFirebase() async {
    try {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      if (user == null) return;

      final themeService = Provider.of<ThemeService>(context, listen: false);

      await _firebaseService.updateUserSettings(user.id!, {
        'darkMode': themeService.isDarkMode,
        'notifications': _notificationsEnabled,
        'location': _locationEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving settings to Firebase: $e');
      throw e; // Rethrow to handle in the calling function
    }
  }

  Future<void> _deleteAccount() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      if (user == null) return;

      // Delete user data from Firebase
      await _firebaseService.deleteUserData(user.id!);

      // Delete user authentication
      await authService.deleteAccount();

      // Navigate to login screen
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (route) => false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your account has been deleted'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting account: $e')),
      );
    }
  }

  void _showBugReportDialog() {
    final descriptionController = TextEditingController();
    final stepsController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Report a Bug'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Please describe the issue you encountered:'),
                const SizedBox(height: 8),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    hintText: 'Describe the bug...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                const Text('Steps to reproduce:'),
                const SizedBox(height: 8),
                TextField(
                  controller: stepsController,
                  decoration: const InputDecoration(
                    hintText: 'Steps to reproduce the issue...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Note: Please include as much detail as possible to help us fix the issue.',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (descriptionController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Please describe the bug')),
                        );
                        return;
                      }

                      setState(() {
                        isSubmitting = true;
                      });

                      try {
                        final user =
                            Provider.of<AuthService>(context, listen: false)
                                .currentUser;

                        // Use the correct method signature for submitBugReport
                        await _firebaseService.submitBugReport(
                          userId: user?.id ?? 'anonymous',
                          title: 'Bug Report',
                          description: descriptionController.text.trim(),
                          deviceInfo: 'Not collected',
                          appVersion: _appVersion,
                        );

                        Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Bug report submitted. Thank you for helping us improve!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Error submitting report: $e')),
                        );
                      } finally {
                        setState(() {
                          isSubmitting = false;
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change Password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (newPasswordController.text !=
                          confirmPasswordController.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Passwords do not match')),
                        );
                        return;
                      }

                      if (newPasswordController.text.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Password must be at least 6 characters')),
                        );
                        return;
                      }

                      setState(() {
                        isLoading = true;
                      });

                      try {
                        final authService =
                            Provider.of<AuthService>(context, listen: false);

                        // Change password
                        final success = await authService.changePassword(
                          currentPasswordController.text,
                          newPasswordController.text,
                        );

                        Navigator.pop(context);

                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password updated successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to update password'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      } finally {
                        setState(() {
                          isLoading = false;
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning banner if shared preferences failed
            if (_prefsError)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Settings Storage Unavailable',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your settings will not be saved between app restarts. This is usually fixed by restarting the app.',
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // App Preferences
            Text(
              'App Preferences',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildSettingCard(
              title: 'Dark Mode',
              subtitle: 'Enable dark theme for the app',
              icon: Icons.dark_mode,
              trailing: Switch(
                value: themeService.isDarkMode,
                onChanged: (value) {
                  themeService.setDarkMode(value);
                },
                activeColor: Theme.of(context).colorScheme.primary,
              ),
            ),
            _buildSettingCard(
              title: 'Notifications',
              subtitle: 'Receive push notifications',
              icon: Icons.notifications,
              trailing: Switch(
                value: _notificationsEnabled,
                onChanged: (value) {
                  setState(() {
                    _notificationsEnabled = value;
                  });
                  _saveSettings();
                },
                activeColor: Theme.of(context).colorScheme.primary,
              ),
            ),
            _buildSettingCard(
              title: 'Location Services',
              subtitle: 'Allow app to access your location',
              icon: Icons.location_on,
              trailing: Switch(
                value: _locationEnabled,
                onChanged: (value) {
                  setState(() {
                    _locationEnabled = value;
                  });
                  _saveSettings();
                },
                activeColor: Theme.of(context).colorScheme.primary,
              ),
            ),

            const SizedBox(height: 24),

            // Account Settings
            Text(
              'Account Settings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildSettingCard(
              title: 'Change Password',
              subtitle: 'Update your account password',
              icon: Icons.lock,
              onTap: () {
                _showChangePasswordDialog();
              },
            ),
            _buildSettingCard(
              title: 'Delete Account',
              subtitle: 'Permanently delete your account and data',
              icon: Icons.delete_forever,
              iconColor: Colors.red,
              onTap: _deleteAccount,
            ),

            const SizedBox(height: 24),

            // Support
            Text(
              'Support',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildSettingCard(
              title: 'Report a Bug',
              subtitle: 'Help us improve the app by reporting issues',
              icon: Icons.bug_report,
              onTap: () {
                _showBugReportDialog();
              },
            ),

            const SizedBox(height: 24),

            // About
            Text(
              'About',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildSettingCard(
              title: 'About Us',
              subtitle: 'Learn more about our team and mission',
              icon: Icons.info,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AboutUsScreen()),
                );
              },
            ),
            _buildSettingCard(
              title: 'App Version',
              subtitle: 'Version $_appVersion',
              icon: Icons.phone_android,
              onTap: null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required String title,
    required String subtitle,
    required IconData icon,
    Color? iconColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (iconColor ?? Theme.of(context).colorScheme.primary)
                .withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: iconColor ?? Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        subtitle: Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color:
                    Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
              ),
        ),
        trailing: trailing ??
            (onTap != null
                ? const Icon(Icons.arrow_forward_ios, size: 16)
                : null),
        onTap: onTap,
      ),
    );
  }
}
