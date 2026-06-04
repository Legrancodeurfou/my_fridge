import 'dart:convert';
import 'dart:io';

Future<String> postAnalyzeTicket(
  String endpoint,
  Map<String, dynamic> body,
) async {
  final uri = Uri.parse(endpoint);
  final client = HttpClient();

  try {
    final request = await client.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));

    final response = await request.close();
    final text = await utf8.decoder.bind(response).join();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Analyse IA indisponible (${response.statusCode}) : $text');
    }

    return text;
  } finally {
    client.close(force: true);
  }
}
