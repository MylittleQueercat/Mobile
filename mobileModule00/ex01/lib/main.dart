import 'package:flutter/material.dart';

void main() {
  runApp(const Ex01App());
}

class Ex01App extends StatelessWidget {
  const Ex01App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Exercise 01',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const ToggleTextPage(),
    );
  }
}

class ToggleTextPage extends StatefulWidget {
  const ToggleTextPage({super.key});

  @override
  State<ToggleTextPage> createState() => _ToggleTextPageState();
}

class _ToggleTextPageState extends State<ToggleTextPage> {
  bool _showHelloWorld = false;

  void _onButtonPressed() {
    debugPrint('Button pressed');
    setState(() {
      _showHelloWorld = !_showHelloWorld;
    });
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
              children: [
                Text(
                  _showHelloWorld ? 'Hello World!' : 'Hello!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24),
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
