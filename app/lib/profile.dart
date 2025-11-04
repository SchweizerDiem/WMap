import 'package:flutter/material.dart';
import 'user.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushNamedAndRemoveUntil('/home', (Route<dynamic> route) => false);
            }
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 8),
            // Placeholder for user photo
            const CircleAvatar(
              radius: 48,
              backgroundColor: Colors.grey,
              child: Icon(
                Icons.person,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            // Name (listens to userNameNotifier)
            ValueListenableBuilder<String>(
              valueListenable: userNameNotifier,
              builder: (context, name, child) {
                return Text(
                  name.isEmpty ? 'Guest' : name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            // Stats placeholders
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Number of countries visited:'),
                Text('0'),
              ],
            ),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Percentage of the world visited:'),
                Text('0%'),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'More profile features (photo upload, stats tracking) will be added later.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
