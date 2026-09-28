import 'dart:convert';

import 'package:http/http.dart' as http;

class AiAssistantService {
  AiAssistantService();

  static const String _apiKey = '';

  Future<String> askStockAssistant({
    required String question,
    required String warehouseContext,
  }) async {
    if (_apiKey.trim().isEmpty) {
      throw Exception('Lipsește cheia API Gemini.');
    }

    final limitedContext = warehouseContext.length > 24000
        ? warehouseContext.substring(0, 24000)
        : warehouseContext;

    final prompt = '''
Ești AI Assistant pentru aplicația StockIQ, un sistem Flutter + Firebase + ESP32 pentru monitorizarea stocurilor.

Rolul tău:
- ajuți utilizatorul să înțeleagă stocurile, riscurile, comenzile, consumul și forecast-ul;
- răspunzi ca un copilot de depozit;
- oferi recomandări practice, clare și sigure.

Reguli obligatorii:
- Răspunde în limba română.
- Folosește doar contextul primit de la aplicația Flutter.
- Nu inventa produse, cutii, comenzi, cantități sau valori.
- Nu spune că ai acces direct la Firebase.
- Nu muta logica AI Insights în backend.
- Dacă datele sunt insuficiente, spune clar ce lipsește.
- Răspunde complet, cu propoziții terminate.
- Nu opri răspunsul la jumătatea unei fraze.
- Pentru recomandări de comandă, menționează produsul, stocul actual, statusul și cantitatea sugerată dacă apare în context.
- Pentru risc, consum, forecast sau epuizare, explică pe baza valorilor existente în context.
- Răspunsul să fie practic și ușor de înțeles.
- Folosește maximum 5 bullet-uri când este posibil.

Întrebarea utilizatorului:
$question

Contextul depozitului StockIQ:
$limitedContext
''';

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=$_apiKey',
    );

    try {
      final response = await http
          .post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {
                  'text': prompt,
                },
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0.25,
            'maxOutputTokens': 1200,
          },
        }),
      )
          .timeout(const Duration(seconds: 45));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = decoded['error'];

        if (error is Map && error['message'] != null) {
          throw Exception(error['message'].toString());
        }

        throw Exception('Gemini API error: ${response.statusCode}');
      }

      final candidates = decoded['candidates'];

      if (candidates is List && candidates.isNotEmpty) {
        final firstCandidate = candidates.first;

        if (firstCandidate is Map) {
          final finishReason = firstCandidate['finishReason']?.toString();

          final content = firstCandidate['content'];

          if (content is Map) {
            final parts = content['parts'];

            if (parts is List && parts.isNotEmpty) {
              final buffer = StringBuffer();

              for (final part in parts) {
                if (part is Map) {
                  final text = part['text']?.toString();

                  if (text != null && text.trim().isNotEmpty) {
                    if (buffer.isNotEmpty) {
                      buffer.write('\n');
                    }

                    buffer.write(text.trim());
                  }
                }
              }

              final answer = buffer.toString().trim();

              if (answer.isNotEmpty) {
                return answer;
              }
            }
          }

          if (finishReason != null && finishReason.isNotEmpty) {
            return 'AI-ul nu a returnat text complet. Motiv: $finishReason.';
          }
        }
      }

      return 'AI-ul nu a returnat un răspuns valid.';
    } catch (e) {
      throw Exception(
        'Nu am putut comunica cu Gemini AI: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }
}