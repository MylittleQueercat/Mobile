/// Returns null when the expression cannot produce a finite result.
double? evaluateExpression(String expression) {
  try {
    final parser = _ExpressionParser(expression);
    final result = parser.parse();
    return result.isFinite ? result : null;
  } catch (_) {
    return null;
  }
}

class _ExpressionParser {
  _ExpressionParser(this._input);

  final String _input;
  int _index = 0;

  double parse() {
    final value = _parseExpression();
    _skipSpaces();
    if (_index != _input.length) {
      throw const FormatException('Unexpected character');
    }
    return value;
  }

  double _parseExpression() {
    var value = _parseTerm();
    while (true) {
      _skipSpaces();
      if (_take('+')) {
        value += _parseTerm();
      } else if (_take('-')) {
        value -= _parseTerm();
      } else {
        return value;
      }
      _requireFinite(value);
    }
  }

  double _parseTerm() {
    var value = _parseFactor();
    while (true) {
      _skipSpaces();
      if (_take('*')) {
        value *= _parseFactor();
      } else if (_take('/')) {
        final divisor = _parseFactor();
        if (divisor == 0) {
          throw const FormatException('Division by zero');
        }
        value /= divisor;
      } else {
        return value;
      }
      _requireFinite(value);
    }
  }

  double _parseFactor() {
    _skipSpaces();
    if (_take('-')) {
      return -_parseFactor();
    }
    if (_take('+')) {
      return _parseFactor();
    }
    return _parseNumber();
  }

  double _parseNumber() {
    _skipSpaces();
    final start = _index;
    var hasDigit = false;
    var hasPoint = false;

    while (_index < _input.length) {
      final character = _input[_index];
      if (_isDigit(character)) {
        hasDigit = true;
      } else if (character == '.' && !hasPoint) {
        hasPoint = true;
      } else {
        break;
      }
      _index++;
    }

    if (!hasDigit) {
      throw const FormatException('Expected number');
    }
    final value = double.tryParse(_input.substring(start, _index));
    if (value == null) {
      throw const FormatException('Invalid number');
    }
    _requireFinite(value);
    return value;
  }

  bool _take(String character) {
    if (_index < _input.length && _input[_index] == character) {
      _index++;
      return true;
    }
    return false;
  }

  void _skipSpaces() {
    while (_index < _input.length && _input[_index].trim().isEmpty) {
      _index++;
    }
  }

  bool _isDigit(String character) {
    return character.codeUnitAt(0) >= 48 && character.codeUnitAt(0) <= 57;
  }

  void _requireFinite(double value) {
    if (!value.isFinite) {
      throw const FormatException('Result is not finite');
    }
  }
}
