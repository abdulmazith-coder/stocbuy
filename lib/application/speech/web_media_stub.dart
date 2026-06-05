import 'dart:html' as html;

Future<void> requestMicPermission() async {
  try {
    await html.window.navigator.mediaDevices?.getUserMedia({
      'audio': true,
    });
  } catch (e) {
    print("Mic error: $e");
  }
}