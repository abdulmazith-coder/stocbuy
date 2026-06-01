import 'package:flutter_test/flutter_test.dart';
import 'package:stocbuy_application/application/utils/ai_analysis_error_message.dart';

void main() {
  test('dedupes repeated connection error lines', () {
    final raw = '''
server closed the connection unexpectedly
This probably means the server terminated abnormally
server closed the connection unexpectedly
This probably means the server terminated abnormally
''';

    final formatted = formatAiAnalysisErrorMessage(raw);
    expect(formatted, contains('Connection lost'));
    expect(
      'server closed the connection unexpectedly'
          .allMatches(formatted.toLowerCase())
          .length,
      lessThan(2),
    );
  });

  test('detects transient connection errors', () {
    expect(
      isTransientAnalysisConnectionError('connection already closed'),
      isTrue,
    );
    expect(
      isTransientAnalysisConnectionError('Invalid API key'),
      isFalse,
    );
  });
}
