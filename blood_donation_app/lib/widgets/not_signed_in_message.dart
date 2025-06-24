import 'package:flutter/material.dart';

class NotSignedInMessage extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const NotSignedInMessage({
    Key? key,
    this.title = 'Not signed in',
    this.message = 'Please sign in to view this content',
    this.icon = Icons.account_circle_outlined,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
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
                      .onBackground
                      .withOpacity(0.7),
                ),
          ),
        ],
      ),
    );
  }
}
