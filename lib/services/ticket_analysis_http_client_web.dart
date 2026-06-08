import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<String> postAnalyzeTicket(
  String endpoint,
  Map<String, dynamic> body,
) async {
  final headers = web.Headers()..set('Content-Type', 'application/json');

  late final web.Response response;
  try {
    response = await web.window
        .fetch(
          endpoint.toJS,
          web.RequestInit(
            method: 'POST',
            headers: headers,
            body: jsonEncode(body).toJS,
          ),
        )
        .toDart;
  } catch (error) {
    throw Exception('Connexion au service d’analyse impossible : $error');
  }

  final status = response.status;
  final text = (await response.text().toDart).toDart;

  if (status < 200 || status >= 300) {
    throw Exception('Analyse IA indisponible ($status) : $text');
  }

  return text;
}
