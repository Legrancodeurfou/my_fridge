import 'dart:convert';
import 'dart:html' as html;

Future<String> postAnalyzeTicket(
  String endpoint,
  Map<String, dynamic> body,
) async {
  final response = await html.HttpRequest.request(
    endpoint,
    method: 'POST',
    requestHeaders: const {
      'Content-Type': 'application/json',
    },
    sendData: jsonEncode(body),
  );

  final status = response.status ?? 0;
  final text = response.responseText ?? '';

  if (status < 200 || status >= 300) {
    throw Exception('Analyse IA indisponible ($status) : $text');
  }

  return text;
}
