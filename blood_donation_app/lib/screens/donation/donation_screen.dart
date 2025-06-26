import 'package:blood_donation_app/services/firebase_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import '../../models/donation_model.dart';
import '../../services/auth_service.dart';

class DonationScreen extends StatefulWidget {
  const DonationScreen({super.key});

  @override
  State<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends State<DonationScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Donation History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              _showDonationInfo();
            },
            tooltip: 'Donation Info',
          ),
        ],
      ),
      body: _buildHistoryTab(),
    );
  }

  void _showDonationInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Donation Tracking'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How we track your donations:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• Each accepted blood request counts as a donation'),
            Text('• Your donation history shows when you helped others'),
            Text('• Each unit donated can potentially save 1 life'),
            Text('• Track your impact and contribution to the community'),
            SizedBox(height: 16),
            Text(
              'Thank you for being a blood donation hero!',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.green,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    final user = Provider.of<AuthService>(context).currentUser;

    if (user == null) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(24),
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
            SizedBox(height: 16),
            Text(
              'Not signed in',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 8),
            Text(
              'Please sign in to view your donation history',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withAlpha((255 * 0.7).round()),
                  ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/login');
              },
              child: Text('Sign In'),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<List<DonationModel>>(
      future: _firebaseService.getUserDonations(user.id!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          debugPrint('Donation fetch error: ${snapshot.error}');
          return _buildEmptyDonationState();
        }

        final donations = snapshot.data ?? [];

        if (donations.isEmpty) {
          return _buildEmptyDonationState();
        }

        // Calculate consistent statistics
        final totalDonations = donations.length;
        final totalUnits =
            donations.fold<int>(0, (sum, donation) => sum + donation.units);
        final livesSaved = totalUnits; // 1 unit = 1 life saved

        return Column(
          children: [
            // Statistics header
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context)
                        .colorScheme
                        .primary
                        .withAlpha((255 * 0.8).round()),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    'Total Donations',
                    totalDonations.toString(),
                    Icons.bloodtype,
                  ),
                  _buildStatItem(
                    'Total Units',
                    totalUnits.toString(),
                    Icons.water_drop,
                  ),
                  _buildStatItem(
                    'Lives Saved',
                    livesSaved.toString(),
                    Icons.favorite,
                  ),
                ],
              ),
            ),
            // Donations list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: donations.length,
                itemBuilder: (context, index) {
                  final donation = donations[index];
                  final formattedDate =
                      DateFormat('MMMM d, yyyy').format(donation.date);
                  final formattedTime =
                      DateFormat('h:mm a').format(donation.date);

                  return _buildDonationCard(
                    date: formattedDate,
                    time: formattedTime,
                    location: donation.location,
                    status: donation.status,
                    bloodType: donation.bloodGroup,
                    units: donation.units.toString(),
                    patientName: donation.patientName,
                    hospital: donation.hospital,
                    requestId: donation.requestId,
                    donation: donation,
                    user: user,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyDonationState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bloodtype_outlined,
            size: 64,
            color: Theme.of(context)
                .colorScheme
                .primary
                .withAlpha((255 * 0.5).round()),
          ),
          const SizedBox(height: 16),
          Text(
            'No donation history yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Your donation history will appear here when you accept blood requests',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withAlpha((255 * 0.7).round()),
                ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/requests');
            },
            icon: const Icon(Icons.volunteer_activism),
            label: const Text('Browse Blood Requests'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha((255 * 0.1).round()),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: Colors.blue.withAlpha((255 * 0.3).round())),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'How Donations Work',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'When you accept a blood request, it automatically creates a donation record and appears in your history. Each donation helps save lives in your community!',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildDonationCard({
    required String date,
    required String time,
    required String location,
    required String status,
    required String bloodType,
    required String units,
    required String patientName,
    required String hospital,
    String? requestId,
    required DonationModel donation,
    required dynamic user,
  }) {
    final Color statusColor = status == 'Completed'
        ? Colors.green
        : status == 'Scheduled'
            ? Theme.of(context).colorScheme.primary
            : Colors.orange;

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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha((255 * 0.1).round()),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    status == 'Completed'
                        ? Icons.check_circle_outline
                        : Icons.calendar_today,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        date,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      Text(
                        time,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha((255 * 0.1).round()),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Patient and hospital info
            if (patientName.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 20,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Patient: $patientName',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 20,
                  color: Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hospital.isNotEmpty ? hospital : location,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.bloodtype_outlined,
                  size: 20,
                  color: Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Blood Type: $bloodType',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(width: 16),
                const Icon(
                  Icons.water_drop_outlined,
                  size: 20,
                  color: Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Units: $units',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            if (status == 'Completed') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _showDonationImpact(units, bloodType);
                      },
                      icon: const Icon(Icons.favorite_outline),
                      label: const Text('View Impact'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: statusColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _generateAndDownloadCertificate(
                          donation: donation,
                          user: user,
                          date: date,
                          bloodType: bloodType,
                          units: units,
                          patientName: patientName,
                          hospital: hospital,
                        );
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('Certificate'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: statusColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDonationImpact(String units, String bloodType) {
    final int unitCount = int.tryParse(units) ?? 1;
    final int livesSaved = unitCount;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your Donation Impact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.favorite,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'This donation potentially saved',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '$livesSaved ${livesSaved == 1 ? 'life' : 'lives'}',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Blood Type: $bloodType\nUnits Donated: $units',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Thank you for being a hero!',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Colors.green,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _shareImpact(livesSaved, bloodType);
            },
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAndDownloadCertificate({
    required DonationModel donation,
    required dynamic user,
    required String date,
    required String bloodType,
    required String units,
    required String patientName,
    required String hospital,
  }) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Generating certificate...'),
            ],
          ),
        ),
      );

      // Generate PDF certificate
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(40),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.red, width: 3),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // Header
                  pw.Container(
                    padding: const pw.EdgeInsets.all(20),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.red50,
                      borderRadius: pw.BorderRadius.circular(10),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'BLOOD DONATION CERTIFICATE',
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red,
                          ),
                        ),
                        pw.SizedBox(height: 10),
                        pw.Text(
                          'BloodBridge Community',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontStyle: pw.FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 40),

                  // Certificate content
                  pw.Text(
                    'This is to certify that',
                    style: pw.TextStyle(fontSize: 16),
                  ),

                  pw.SizedBox(height: 20),

                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                          bottom: pw.BorderSide(color: PdfColors.black)),
                    ),
                    child: pw.Text(
                      user.name.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red,
                      ),
                    ),
                  ),

                  pw.SizedBox(height: 30),

                  pw.Text(
                    'has generously donated',
                    style: pw.TextStyle(fontSize: 16),
                  ),

                  pw.SizedBox(height: 20),

                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(15),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.red,
                          borderRadius: pw.BorderRadius.circular(50),
                        ),
                        child: pw.Text(
                          '$units UNIT${int.parse(units) > 1 ? 'S' : ''}',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 20),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(15),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.red,
                          borderRadius: pw.BorderRadius.circular(50),
                        ),
                        child: pw.Text(
                          bloodType,
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 30),

                  pw.Text(
                    'of blood on $date',
                    style: pw.TextStyle(fontSize: 16),
                  ),

                  if (patientName.isNotEmpty) ...[
                    pw.SizedBox(height: 20),
                    pw.Text(
                      'for patient: $patientName',
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold),
                    ),
                  ],

                  if (hospital.isNotEmpty) ...[
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'at $hospital',
                      style: pw.TextStyle(fontSize: 14),
                    ),
                  ],

                  pw.SizedBox(height: 40),

                  // Impact section
                  pw.Container(
                    padding: const pw.EdgeInsets.all(20),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green50,
                      borderRadius: pw.BorderRadius.circular(10),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'IMPACT',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green,
                          ),
                        ),
                        pw.SizedBox(height: 10),
                        pw.Text(
                          'This donation potentially saved ${int.parse(units)} ${int.parse(units) == 1 ? 'life' : 'lives'}',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  pw.Spacer(),

                  // Footer
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Certificate ID: ${donation.id ?? 'N/A'}',
                            style: pw.TextStyle(
                                fontSize: 10, color: PdfColors.grey),
                          ),
                          pw.Text(
                            'Generated: ${DateFormat('MMM d, yyyy').format(DateTime.now())}',
                            style: pw.TextStyle(
                                fontSize: 10, color: PdfColors.grey),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'BloodBridge',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.red,
                            ),
                          ),
                          pw.Text(
                            'Saving Lives Together',
                            style: pw.TextStyle(
                                fontSize: 10, color: PdfColors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );

      // Save PDF to device
      final output = await getTemporaryDirectory();
      final fileName =
          'BloodDonation_Certificate_${user.name.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(donation.date)}.pdf';
      final file = File('${output.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      // Close loading dialog
      Navigator.pop(context);

      // Show success dialog with options
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Certificate\nGenerated'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.workspace_premium,
                size: 64,
                color: Colors.amber,
              ),
              SizedBox(height: 16),
              Text(
                'Your donation certificate has been generated successfully!',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                'File saved as: $fileName',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                // Share the PDF file
                await SharePlus.instance.share(
                  ShareParams(
                    text: 'My Blood Donation Certificate from BloodBridge',
                    files: [XFile(file.path)],
                  ),
                );
              },
              icon: Icon(Icons.share),
              label: Text('Share'),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                // Open PDF for viewing/printing
                await Printing.layoutPdf(
                  onLayout: (PdfPageFormat format) async => pdf.save(),
                );
              },
              icon: Icon(Icons.print),
              label: Text('Print/View'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      // Close loading dialog if open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating certificate: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _shareImpact(int livesSaved, String bloodType) {
    final String shareText =
        'I just helped save $livesSaved ${livesSaved == 1 ? 'life' : 'lives'} by donating $bloodType blood! 🩸❤️ #BloodDonation #SaveLives #BloodHero';

    SharePlus.instance.share(
      ShareParams(text: shareText),
    );
  }
}
