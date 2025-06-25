import 'package:flutter/material.dart';

class EligibilityStatus extends StatelessWidget {
  final bool isEligible;
  final int? daysUntilEligible;
  final String eligibleText;
  final String notEligibleText;

  const EligibilityStatus({
    super.key,
    required this.isEligible,
    this.daysUntilEligible,
    this.eligibleText = 'You are eligible to donate',
    this.notEligibleText = 'You are not eligible to donate yet',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isEligible
                ? Colors.green.withAlpha((255 * 0.1).round())
                : Colors.orange.withAlpha((255 * 0.1).round()),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isEligible ? Icons.check_circle : Icons.access_time,
            color: isEligible ? Colors.green : Colors.orange.shade700,
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          fit: FlexFit.loose,
          child: Text(
            isEligible
                ? eligibleText
                : (daysUntilEligible != null && daysUntilEligible! > 0)
                    ? 'You can donate again in $daysUntilEligible days'
                    : notEligibleText,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color:
                  isEligible ? Colors.green.shade700 : Colors.orange.shade700,
            ),
          ),
        ),
      ],
    );
  }
}
