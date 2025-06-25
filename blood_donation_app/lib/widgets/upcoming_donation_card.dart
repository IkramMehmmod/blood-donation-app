import 'package:flutter/material.dart';
import '../models/donation_model.dart';
import 'package:intl/intl.dart';

class UpcomingDonationCard extends StatelessWidget {
  final DonationModel donation;
  final VoidCallback? onTap;
  final VoidCallback? onCancel;

  const UpcomingDonationCard({
    super.key,
    required this.donation,
    this.onTap,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('MMM d, yyyy').format(donation.date);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formattedDate,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(donation.status)
                          .withAlpha((255 * 0.2).round()),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      donation.status,
                      style: TextStyle(
                        color: _getStatusColor(donation.status),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha((255 * 0.2).round()),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      donation.bloodGroup,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${donation.units} units'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16),
                  const SizedBox(width: 4),
                  Expanded(child: Text(donation.location)),
                ],
              ),
              if (onCancel != null && donation.status != 'Completed') ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Cancel Donation'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return Colors.green;
      case 'Scheduled':
        return Colors.blue;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
}
