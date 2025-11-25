import 'package:flutter/material.dart';

class HubPage extends StatelessWidget {
  const HubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hub'),
      ),
      body: const Center(
        child: Text(
          'Hub page (placeholder)',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
