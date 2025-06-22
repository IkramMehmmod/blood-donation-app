import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // Import ScreenUtil
import '../../services/firebase_service.dart'; // Ensure this path is correct

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  int _selectedTab = 0;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ScreenUtil is initialized at the MaterialApp level, so we can use its extensions directly.
    return Scaffold(
      appBar: AppBar(
        title: Text('Support',
            style: TextStyle(fontSize: 20.sp)), // Responsive text size
        elevation: 0,
      ),
      body: Column(
        children: [
          // Tab selector
          Container(
            color: Theme.of(context).colorScheme.primary,
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: 16.w, vertical: 8.h), // Responsive padding
              child: Row(
                children: [
                  _buildTabButton('FAQs', 0),
                  _buildTabButton('Contact Us', 1),
                ],
              ),
            ),
          ),

          // Tab content
          Expanded(
            child: IndexedStack(
              index: _selectedTab,
              children: [
                _buildFaqsTab(),
                _buildContactTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w), // Responsive padding
        child: ElevatedButton(
          onPressed: () {
            setState(() {
              _selectedTab = index;
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected
                ? Colors.white
                : Theme.of(context).colorScheme.primary,
            foregroundColor: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.white,
            elevation: isSelected ? 2.w : 0, // Responsive elevation
            padding: EdgeInsets.symmetric(vertical: 12.h), // Responsive padding
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(8.r), // Responsive border radius
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14.sp, // Responsive text size
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFaqsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _firebaseService.getFAQs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final faqs = snapshot.data ?? [];

        if (faqs.isEmpty) {
          // Default FAQs if none in database
          return _buildDefaultFaqs();
        }

        return ListView.builder(
          padding: EdgeInsets.all(16.w), // Responsive padding
          itemCount: faqs.length,
          itemBuilder: (context, index) {
            final faq = faqs[index];
            return _buildFaqItem(
              question: faq['question'] ?? 'No question available',
              answer: faq['answer'] ?? 'No answer available',
            );
          },
        );
      },
    );
  }

  Widget _buildDefaultFaqs() {
    return ListView(
      padding: EdgeInsets.all(16.w), // Responsive padding
      children: [
        _buildFaqItem(
          question: 'How often can I donate blood?',
          answer:
              'Most people can donate whole blood every 56 days (8 weeks). This waiting period allows your body to replenish the red blood cells lost during donation.',
        ),
        _buildFaqItem(
          question: 'What are the eligibility requirements for blood donation?',
          answer:
              'Generally, you must be at least 17 years old, weigh at least 50 kg, and be in good health. Specific requirements may vary based on local regulations and your medical history.',
        ),
        _buildFaqItem(
          question: 'How long does a blood donation take?',
          answer:
              'The actual blood donation takes about 8-10 minutes. However, the entire process, including registration, health screening, and refreshments after donation, takes about 1 hour.',
        ),
        _buildFaqItem(
          question: 'Is blood donation safe?',
          answer:
              'Yes, blood donation is very safe. All equipment used is sterile and disposed of after a single use, eliminating any risk of infection.',
        ),
        _buildFaqItem(
          question: 'What should I do before donating blood?',
          answer:
              'Get a good night\'s sleep, eat a healthy meal, drink plenty of fluids, and avoid fatty foods before donation. Bring a valid ID and a list of medications you\'re taking.',
        ),
        _buildFaqItem(
          question: 'How do I update my profile information?',
          answer:
              'You can update your profile information by going to the Profile tab and tapping on the Edit Profile button. From there, you can update your personal details, contact information, and preferences.',
        ),
        _buildFaqItem(
          question: 'How can I cancel or reschedule a donation appointment?',
          answer:
              'To cancel or reschedule an appointment, go to the Donations tab, find your upcoming appointment, and tap on it. You\'ll see options to reschedule or cancel the appointment.',
        ),
      ],
    );
  }

  Widget _buildFaqItem({required String question, required String answer}) {
    return Card(
      margin: EdgeInsets.only(bottom: 16.h), // Responsive margin
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r), // Responsive border radius
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16.sp, // Responsive text size
          ),
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16.w), // Responsive padding
            child: Text(
              answer,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                fontSize: 14.sp, // Responsive text size
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTab() {
    // Define a common minimum width for the action buttons
    // You might need to adjust this value based on your longest text and desired look.
    const double minButtonWidth = 120.0; // Base width from design
    final double responsiveButtonWidth = minButtonWidth.w; // Make it responsive

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w), // Responsive padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact Us',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 22.sp, // Responsive text size
                ),
          ),
          SizedBox(height: 8.h), // Responsive height
          Text(
            'We\'re here to help! Choose your preferred method of contact below.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onBackground
                      .withOpacity(0.7),
                  fontSize: 16.sp, // Responsive text size
                ),
          ),
          SizedBox(height: 24.h), // Responsive height

          // Contact methods
          _buildContactMethod(
            icon: Icons.phone,
            title: 'Call Us',
            subtitle: 'Speak directly with our support team',
            action: 'Call Support',
            onTap: () => _launchUrl('tel:+1234567890'),
            buttonWidth: responsiveButtonWidth, // Pass responsive width
          ),
          SizedBox(height: 16.h), // Responsive height
          _buildContactMethod(
            icon: Icons.email,
            title: 'Email Us',
            subtitle: 'Send us an email and we\'ll respond within 24 hours',
            action: 'Send Email',
            onTap: () => _launchUrl('mailto:support@bloodconnect.com'),
            buttonWidth: responsiveButtonWidth, // Pass responsive width
          ),
          SizedBox(height: 16.h), // Responsive height
          _buildContactMethod(
            icon: Icons.chat,
            title: 'Live Chat',
            subtitle: 'Chat with our support team in real-time',
            action: 'Start Chat',
            onTap: () {
              // Show a dialog explaining that live chat is coming soon
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Coming Soon', style: TextStyle(fontSize: 18.sp)),
                  content: Text(
                    'Live chat support will be available in the next update. Please use email or phone support for now.',
                    style: TextStyle(fontSize: 14.sp),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('OK', style: TextStyle(fontSize: 14.sp)),
                    ),
                  ],
                ),
              );
            },
            buttonWidth: responsiveButtonWidth, // Pass responsive width
          ),
          SizedBox(height: 16.h), // Responsive height
          _buildContactMethod(
            icon: Icons.location_on,
            title: 'Visit Us',
            subtitle: 'Find the nearest blood donation center',
            action: 'View Locations',
            onTap: () {
              Navigator.pushNamed(context, '/map');
            },
            buttonWidth: responsiveButtonWidth, // Pass responsive width
          ),

          SizedBox(height: 32.h), // Responsive height
          const Divider(),
          SizedBox(height: 16.h), // Responsive height

          // Social media
          Text(
            'Connect With Us',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 20.sp, // Responsive text size
                ),
          ),
          SizedBox(height: 16.h), // Responsive height
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                // Using Expanded for equal width social buttons
                child: _buildSocialButton(
                  icon: Icons.facebook,
                  label: 'Facebook',
                  onTap: () => _launchUrl(
                      'https://www.facebook.com/share/192vjqMCQR/?mibextid=wwXIfr'),
                ),
              ),
              Expanded(
                // Using Expanded for equal width social buttons
                child: _buildSocialButton(
                  icon: Icons.camera_alt,
                  label: 'Instagram',
                  onTap: () => _launchUrl(
                      'https://www.instagram.com/tech_solutions___/'),
                ),
              ),
              Expanded(
                // Using Expanded for equal width social buttons
                child: _buildSocialButton(
                  icon: Icons.message,
                  label: 'Twitter',
                  onTap: () => _launchUrl('https://twitter.com/'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactMethod({
    required IconData icon,
    required String title,
    required String subtitle,
    required String action,
    required VoidCallback onTap,
    required double buttonWidth, // Accept responsive button width
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r), // Responsive border radius
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w), // Responsive padding
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.r), // Responsive padding
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 28.sp, // Responsive icon size
              ),
            ),
            SizedBox(width: 16.w), // Responsive width
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.sp, // Responsive text size
                        ),
                  ),
                  SizedBox(height: 4.h), // Responsive height
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onBackground
                              .withOpacity(0.7),
                          fontSize: 14.sp, // Responsive text size
                        ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 16.w), // Responsive width
            SizedBox(
              width: buttonWidth, // Use the passed responsive width
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w, // Responsive padding
                    vertical: 12.h, // Responsive padding
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(8.r), // Responsive border radius
                  ),
                ),
                child: Text(
                  action,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14.sp), // Responsive text size
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r), // Responsive border radius
      child: Padding(
        padding: EdgeInsets.all(12.r), // Responsive padding
        child: Column(
          children: [
            Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 32.sp, // Responsive icon size
            ),
            SizedBox(height: 8.h), // Responsive height
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
                fontSize: 14.sp, // Responsive text size
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      print('Error launching URL: $e');
    }
  }
}
