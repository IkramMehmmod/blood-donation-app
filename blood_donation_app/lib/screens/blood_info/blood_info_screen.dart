import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BloodInfoScreen extends StatefulWidget {
  const BloodInfoScreen({super.key});

  @override
  State<BloodInfoScreen> createState() => _BloodInfoScreenState();
}

class _BloodInfoScreenState extends State<BloodInfoScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blood Info'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Blood type compatibility section
            Text(
              'Blood Type Compatibility',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildBloodCompatibilityTable(context),
            const SizedBox(height: 32),

            // Benefits of blood donation
            Text(
              'Benefits of Blood Donation',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildBenefitCard(
              context,
              icon: Icons.favorite,
              title: 'Health Check',
              description:
                  'Free mini-physical and health screening before donation.',
            ),
            _buildBenefitCard(
              context,
              icon: Icons.local_fire_department,
              title: 'Burns Calories',
              description: 'Donating blood burns approximately 650 calories.',
            ),
            _buildBenefitCard(
              context,
              icon: Icons.monitor_heart,
              title: 'Reduces Heart Disease Risk',
              description:
                  'Regular blood donation can reduce the risk of heart attacks and strokes.',
            ),
            _buildBenefitCard(
              context,
              icon: Icons.bloodtype,
              title: 'Stimulates Blood Cell Production',
              description:
                  'Donation helps stimulate the production of new blood cells.',
            ),
            const SizedBox(height: 32),

            // Why donate blood
            Text(
              'Why Donate Blood?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Every 2 seconds, someone needs blood',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Blood is essential for surgeries, cancer treatment, chronic illnesses, and traumatic injuries. Whether a patient receives whole blood, red cells, platelets or plasma, this lifesaving care starts with one person making a generous donation.',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'The average red blood cell transfusion is approximately 3 units. A single car accident victim can require as many as 100 units of blood. Blood and platelets cannot be manufactured; they can only come from volunteer donors.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Who can donate blood
            Text(
              'Who Can Donate Blood?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEligibilityItem(
                      context,
                      title: 'Age',
                      description:
                          'You must be at least 17 years old in most states.',
                    ),
                    _buildEligibilityItem(
                      context,
                      title: 'Weight',
                      description: 'You must weigh at least 110 lbs (50 kg).',
                    ),
                    _buildEligibilityItem(
                      context,
                      title: 'Health',
                      description:
                          'You must be in good general health and feeling well.',
                    ),
                    _buildEligibilityItem(
                      context,
                      title: 'Hemoglobin',
                      description:
                          'Your hemoglobin level must be acceptable (12.5 g/dL for women, 13.0 g/dL for men).',
                    ),
                    _buildEligibilityItem(
                      context,
                      title: 'Time Between Donations',
                      description:
                          'You must wait at least 56 days between whole blood donations.',
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Blood facts
            Text(
              'Blood Facts',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildFactCard(
              context,
              icon: Icons.people,
              fact:
                  'Less than 38% of the population is eligible to donate blood.',
            ),
            _buildFactCard(
              context,
              icon: Icons.access_time,
              fact:
                  'The donation process takes about 10-15 minutes, while the entire appointment takes about an hour.',
            ),
            _buildFactCard(
              context,
              icon: Icons.water_drop,
              fact: 'One donation can save up to three lives.',
            ),
            _buildFactCard(
              context,
              icon: Icons.calendar_today,
              fact:
                  'Red blood cells must be used within 42 days of collection.',
            ),
            _buildFactCard(
              context,
              icon: Icons.science,
              fact:
                  'Type O-negative blood can be transfused to patients of all blood types.',
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildBloodCompatibilityTable(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Blood Type',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Can Donate To',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Can Receive From',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildBloodTypeRow(context,
                bloodType: 'A+',
                canDonateTo: 'A+, AB+',
                canReceiveFrom: 'A+, A-, O+, O-'),
            _buildBloodTypeRow(context,
                bloodType: 'A-',
                canDonateTo: 'A+, A-, AB+, AB-',
                canReceiveFrom: 'A-, O-'),
            _buildBloodTypeRow(context,
                bloodType: 'B+',
                canDonateTo: 'B+, AB+',
                canReceiveFrom: 'B+, B-, O+, O-'),
            _buildBloodTypeRow(context,
                bloodType: 'B-',
                canDonateTo: 'B+, B-, AB+, AB-',
                canReceiveFrom: 'B-, O-'),
            _buildBloodTypeRow(context,
                bloodType: 'AB+',
                canDonateTo: 'AB+',
                canReceiveFrom: 'All Blood Types'),
            _buildBloodTypeRow(context,
                bloodType: 'AB-',
                canDonateTo: 'AB+, AB-',
                canReceiveFrom: 'A-, B-, AB-, O-'),
            _buildBloodTypeRow(context,
                bloodType: 'O+',
                canDonateTo: 'A+, B+, AB+, O+',
                canReceiveFrom: 'O+, O-'),
            _buildBloodTypeRow(context,
                bloodType: 'O-',
                canDonateTo: 'All Blood Types',
                canReceiveFrom: 'O-'),
          ],
        ),
      ),
    );
  }

  Widget _buildBloodTypeRow(
    BuildContext context, {
    required String bloodType,
    required String canDonateTo,
    required String canReceiveFrom,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                bloodType,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Text(
                canDonateTo,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Text(
                canReceiveFrom,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEligibilityItem(
    BuildContext context, {
    required String title,
    required String description,
    bool isLast = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!isLast) const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFactCard(
    BuildContext context, {
    required IconData icon,
    required String fact,
  }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                fact,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
