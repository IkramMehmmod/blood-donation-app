import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BloodRequestCard extends StatelessWidget {
  final String bloodType;
  final String hospital;
  final String urgency;
  final String postedTime;
  final DateTime? requiredDate;
  final VoidCallback? onTap;
  final VoidCallback? onRespond;

  const BloodRequestCard({
    super.key,
    required this.bloodType,
    required this.hospital,
    required this.urgency,
    required this.postedTime,
    this.requiredDate,
    this.onTap,
    this.onRespond,
  });

  @override
  Widget build(BuildContext context) {
    final Color urgencyColor = _getUrgencyColor(urgency);
    final String formattedDate = requiredDate != null
        ? DateFormat('MMM d, yyyy').format(requiredDate!)
        : 'As soon as possible';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.red.shade100,
                    child: Text(
                      bloodType,
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hospital,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Required by: $formattedDate',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: urgencyColor.withAlpha((255 * 0.2).round()),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      urgency,
                      style: TextStyle(
                        color: urgencyColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Posted: $postedTime',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              if (onRespond != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onRespond,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: urgencyColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Respond'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getUrgencyColor(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'urgent':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }
}
