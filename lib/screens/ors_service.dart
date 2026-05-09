import 'dart:convert';
import 'package:http/http.dart' as http;

class OrsService {
  static const String apiKey = "eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6Ijk4MTJiNjMzNTAxODQ4MWQ5YTdjOTMxMTQzODY4ODliIiwiaCI6Im11cm11cjY0In0=";

  // NPJN / Ligao testing center coordinates
  // Replace with exact coordinates later if needed.
  static const double testingCenterLon = 123.5333;
  static const double testingCenterLat = 13.2167;

  static Future<int?> getTravelTimeMinutes({
    required double originLon,
    required double originLat,
  }) async {
    final url = Uri.parse(
      "https://api.openrouteservice.org/v2/directions/driving-car",
    );

    try {
      final response = await http.post(
        url,
        headers: {
          "Authorization": apiKey,
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "coordinates": [
            [originLon, originLat],
            [testingCenterLon, testingCenterLat],
          ],
          "instructions": false,
        }),
      );

      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body);

      final seconds =
          data["routes"][0]["summary"]["duration"];

      final minutes = (seconds / 60).round();

      return minutes;
    } catch (e) {
      return null;
    }
  }
}