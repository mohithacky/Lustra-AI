import 'package:flutter/material.dart';

void showOfflineDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('You are offline'),
      content: const Text('This action requires an internet connection. Please check your connection and try again.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
