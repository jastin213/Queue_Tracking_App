import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class TravelEstimateResult {
  final int minutes;
  final bool fromLiveOrs;
  final String message;

  TravelEstimateResult({
    required this.minutes,
    required this.fromLiveOrs,
    required this.message,
  });
}

class OrsService {
  // Paste your FULL ORS API key here.
  // Example format usually starts with eyJ...
  static const String apiKey = "eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjI1ODE5ZDFkZTkzNTRhY2NiZTdlY2JiYmY1YTZkYWQ3IiwiaCI6Im11cm11cjY0In0=";

  // NPJN / Ligao testing center coordinates
  // ORS requires longitude, latitude.
  static const double testingCenterLon = 123.5333;
  static const double testingCenterLat = 13.2167;

  // Fallback travel time in minutes.
  // This is used only if ORS fails.
  static final Map<String, int> fallbackTravelMinutes = {
    "Ligao": 5,
    "Guinobatan": 30,
    "Jovellar": 45,
    "Libon": 40,
    "Oas": 18,
    "Pio Duran": 55,
    "Polangui": 25,
  };

  static Future<TravelEstimateResult> getTravelTimeWithFallback({
    required String municipality,
    required double originLon,
    required double originLat,
  }) async {
    final liveMinutes = await getTravelTimeMinutes(
      originLon: originLon,
      originLat: originLat,
    );

    if (liveMinutes != null && liveMinutes > 0) {
      return TravelEstimateResult(
        minutes: liveMinutes,
        fromLiveOrs: true,
        message: "Live ORS travel time used.",
      );
    }

    final fallback = fallbackTravelMinutes[municipality] ?? 30;

    return TravelEstimateResult(
      minutes: fallback,
      fromLiveOrs: false,
      message: "ORS unavailable. Using regional average.",
    );
  }

  static Future<int?> getTravelTimeMinutes({
    required double originLon,
    required double originLat,
  }) async {
    if (apiKey == "PASTE_YOUR_REAL_ORS_API_KEY_HERE" ||
        apiKey.trim().isEmpty ||
        !apiKey.trim().startsWith("eyJ")) {
      debugPrint("ORS ERROR: API key is missing, incomplete, or placeholder.");
      return null;
    }

    final url = Uri.parse(
      "https://api.openrouteservice.org/v2/directions/driving-car/json",
    );

    try {
      final response = await http
          .post(
            url,
            headers: {
              "Authorization": apiKey.trim(),
              "Content-Type": "application/json; charset=utf-8",
              "Accept": "application/json",
            },
            body: jsonEncode({
              "coordinates": [
                [originLon, originLat],
                [testingCenterLon, testingCenterLat],
              ],
              "instructions": false,
              "units": "m",
            }),
          )
          .timeout(
            const Duration(seconds: 12),
          );

      if (response.statusCode != 200) {
        debugPrint("ORS ERROR STATUS: ${response.statusCode}");
        debugPrint("ORS ERROR BODY: ${response.body}");
        return null;
      }

      final data = jsonDecode(response.body);

      final dynamic seconds = data["routes"]?[0]?["summary"]?["duration"];

      if (seconds == null) {
        debugPrint("ORS ERROR: Duration not found in response.");
        return null;
      }

      final minutes = (seconds / 60).round();

      return minutes <= 0 ? 1 : minutes;
    } catch (e) {
      debugPrint("ORS NETWORK/PARSING ERROR: $e");
      return null;
    }
  }
}