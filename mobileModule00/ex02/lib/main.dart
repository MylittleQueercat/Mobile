import 'package:flutter/material.dart';

void main() {
  runApp(const Ex02App());
}

class Ex02App extends StatelessWidget {
  const Ex02App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calculator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const CalculatorPage(),
    );
  }
}

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  final TextEditingController _expressionController = TextEditingController(
    text: '0',
  );
  final TextEditingController _resultController = TextEditingController(
    text: '0',
  );

  @override
  void dispose() {
    _expressionController.dispose();
    _resultController.dispose();
    super.dispose();
  }

  Widget _button(String label) {
    return SizedBox(
      height: 64,
      child: FilledButton(
        onPressed: () => debugPrint(label),
        child: Text(label, style: const TextStyle(fontSize: 22)),
      ),
    );
  }

  Widget _buttonRow(List<String> labels, {bool wideZero = false}) {
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            flex: wideZero && labels[i] == '0' ? 3 : 1,
            child: _button(labels[i]),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calculator')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _expressionController,
                      readOnly: true,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        labelText: 'Expression',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _resultController,
                      readOnly: true,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        labelText: 'Result',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buttonRow(['AC', 'C', '/', '*']),
                    const SizedBox(height: 8),
                    _buttonRow(['7', '8', '9', '-']),
                    const SizedBox(height: 8),
                    _buttonRow(['4', '5', '6', '+']),
                    const SizedBox(height: 8),
                    _buttonRow(['1', '2', '3', '=']),
                    const SizedBox(height: 8),
                    _buttonRow(['0', '.'], wideZero: true),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
