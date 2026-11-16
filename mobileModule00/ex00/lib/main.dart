import 'package:flutter/material.dart';

void main() {
  runApp(const Ex00App());
}

class Ex00App extends StatelessWidget {
  const Ex00App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Exercise 00',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const BasicDisplayPage(),
    );
  }
}

class BasicDisplayPage extends StatelessWidget {
  const BasicDisplayPage({super.key});

  void _onButtonPressed() {
    debugPrint('Button pressed');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Hello!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _onButtonPressed,
                  child: const Text('Press me'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
