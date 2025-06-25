import 'package:flutter/material.dart';

class NotSignedInMessage extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const NotSignedInMessage({
    super.key,
    this.title = 'Not signed in',
    this.message = 'Please sign in to view this content',
    this.icon = Icons.account_circle_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Theme.of(context)
                .colorScheme
                .primary
                .withAlpha((255 * 0.5).round()),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withAlpha((255 * 0.7).round()),
                ),
          ),
        ],
      ),
    );
  }
}
