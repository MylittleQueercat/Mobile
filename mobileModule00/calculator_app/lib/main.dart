import 'package:flutter/material.dart';

import 'expression_evaluator.dart';

void main() {
  runApp(const CalculatorApp());
}

class CalculatorApp extends StatelessWidget {
  const CalculatorApp({super.key});

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

  String _expression = '0';
  String _result = '0';

  @override
  void dispose() {
    _expressionController.dispose();
    _resultController.dispose();
    super.dispose();
  }

  String _formatResult(double value) {
    if (value == 0) return '0';
    final text = value.toString();
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }

  void _onButtonPressed(String label) {
    debugPrint(label);
    setState(() {
      switch (label) {
        case 'AC':
          _expression = '0';
          _result = '0';
          break;
        case 'C':
          _expression = _expression.substring(0, _expression.length - 1);
          if (_expression.isEmpty) _expression = '0';
          _result = '0';
          break;
        case '=':
          final value = evaluateExpression(_expression);
          _result = value == null ? 'Error' : _formatResult(value);
          break;
        default:
          if (_expression == '0' && RegExp(r'^[0-9]$').hasMatch(label)) {
            _expression = label;
          } else if (_expression == '0' && label == '-') {
            _expression = '-';
          } else {
            _expression += label;
          }
          _result = '0';
          break;
      }
      _expressionController.text = _expression;
      _resultController.text = _result;
    });
  }

  Widget _button(String label) {
    return SizedBox(
      height: 64,
      child: FilledButton(
        onPressed: () => _onButtonPressed(label),
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
