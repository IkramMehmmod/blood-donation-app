import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class UpdateHealthScreen extends StatefulWidget {
  const UpdateHealthScreen({Key? key}) : super(key: key);

  @override
  State<UpdateHealthScreen> createState() => _UpdateHealthScreenState();
}

class _UpdateHealthScreenState extends State<UpdateHealthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _bloodPressureController = TextEditingController();
  final _hemoglobinController = TextEditingController();

  DateTime _lastCheckup = DateTime.now();
  bool _isLoading = true;

  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    _loadHealthData();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _bloodPressureController.dispose();
    _hemoglobinController.dispose();
    super.dispose();
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
          _weightController.text = healthData['weight']?.toString() ?? '';
          _heightController.text = healthData['height']?.toString() ?? '';
          _bloodPressureController.text = healthData['bloodPressure'] ?? '';
          _hemoglobinController.text =
              healthData['hemoglobin']?.toString() ?? '';

          if (healthData['lastCheckup'] != null) {
            _lastCheckup = DateTime.parse(healthData['lastCheckup']);
          }
        });
      }
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

  Future<void> _saveHealthData() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      if (user == null) {
        throw Exception('User not found');
      }

      // Parse values
      final weight = double.tryParse(_weightController.text) ?? 0;
      final height = double.tryParse(_heightController.text) ?? 0;
      final hemoglobin = double.tryParse(_hemoglobinController.text) ?? 0;

      // Prepare health data
      final healthData = {
        'userId': user.id,
        'weight': weight,
        'height': height,
        'bloodPressure': _bloodPressureController.text,
        'hemoglobin': hemoglobin,
        'lastCheckup': _lastCheckup.toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      // Update health data in Firebase
      await _firebaseService.updateHealthData(user.id!, healthData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Health data updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving health data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving health data: $e')),
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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _lastCheckup,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _lastCheckup) {
      setState(() {
        _lastCheckup = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Health Information'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Health Information',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Keep your health information up to date for better donation eligibility assessment.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onBackground
                                .withOpacity(0.7),
                          ),
                    ),
                    const SizedBox(height: 24),

                    // Weight
                    CustomTextField(
                      controller: _weightController,
                      labelText: 'Weight (kg)',
                      hintText: 'Enter your weight in kilograms',
                      prefixIcon: Icons.monitor_weight_outlined,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your weight';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Height
                    CustomTextField(
                      controller: _heightController,
                      labelText: 'Height (cm)',
                      hintText: 'Enter your height in centimeters',
                      prefixIcon: Icons.height,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your height';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Blood Pressure
                    CustomTextField(
                      controller: _bloodPressureController,
                      labelText: 'Blood Pressure',
                      hintText: 'e.g., 120/80',
                      prefixIcon: Icons.favorite_outline,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your blood pressure';
                        }
                        if (!RegExp(r'^\d+/\d+$').hasMatch(value)) {
                          return 'Please enter in format: 120/80';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Hemoglobin
                    CustomTextField(
                      controller: _hemoglobinController,
                      labelText: 'Hemoglobin (g/dL)',
                      hintText: 'Enter your hemoglobin level',
                      prefixIcon: Icons.bloodtype_outlined,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your hemoglobin level';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Last Checkup Date
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Last Checkup Date',
                          prefixIcon: Icon(Icons.calendar_today),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          DateFormat('MMMM d, yyyy').format(_lastCheckup),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Health Tips
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline,
                                  color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                'Health Tips',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '• Maintain a hemoglobin level of at least 12.5 g/dL for women and 13.0 g/dL for men to be eligible for donation.\n'
                            '• Stay hydrated and eat iron-rich foods to maintain healthy blood levels.\n'
                            '• Regular exercise helps maintain good cardiovascular health.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    CustomButton(
                      text: 'Save Health Information',
                      isLoading: _isLoading,
                      onPressed: _saveHealthData,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
