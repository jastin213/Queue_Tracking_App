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

class OrsLocationCoordinates {
  final double lat;
  final double lon;

  const OrsLocationCoordinates({required this.lat, required this.lon});
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

  static final Map<String, OrsLocationCoordinates> _barangayCache = {};

  // Verified local override for the barangay specifically requested by the
  // project. Other barangays are resolved by the ORS public geocoder.
  static const Map<String, OrsLocationCoordinates> _knownBarangayLocations = {
    "matacon|polangui": OrsLocationCoordinates(
      lat: 13.3284,
      lon: 123.4356,
    ),
  };

  static bool get _hasUsableApiKey {
    return apiKey.trim().isNotEmpty &&
        apiKey != "PASTE_YOUR_REAL_ORS_API_KEY_HERE" &&
        apiKey.trim().startsWith("eyJ");
  }

  static String _locationKey(String barangay, String municipality) {
    return "${barangay.trim().toLowerCase()}|${municipality.trim().toLowerCase()}";
  }

  /// Resolves a specific barangay to coordinates for more accurate routing.
  /// Returning null is intentional: callers retain the municipality fallback
  /// so an ORS/geocoder outage never blocks queue tracking.
  static Future<OrsLocationCoordinates?> getBarangayCoordinates({
    required String barangay,
    required String municipality,
  }) async {
    final normalizedBarangay = barangay.trim();
    final normalizedMunicipality = municipality.trim();

    if (normalizedBarangay.isEmpty || normalizedMunicipality.isEmpty) {
      return null;
    }

    final key = _locationKey(normalizedBarangay, normalizedMunicipality);
    final knownLocation = _knownBarangayLocations[key];
    if (knownLocation != null) return knownLocation;

    final cachedLocation = _barangayCache[key];
    if (cachedLocation != null) return cachedLocation;

    if (!_hasUsableApiKey) return null;

    final query = [
      normalizedBarangay,
      normalizedMunicipality,
      "Albay",
      "Philippines",
    ].join(", ");

    final url = Uri.https(
      "api.openrouteservice.org",
      "/geocode/search",
      {
        "api_key": apiKey.trim(),
        "text": query,
        "boundary.country": "PH",
        "focus.point.lat": testingCenterLat.toString(),
        "focus.point.lon": testingCenterLon.toString(),
        "size": "1",
      },
    );

    try {
      final response = await http
          .get(url, headers: const {"Accept": "application/json"})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        debugPrint("ORS GEOCODER ERROR STATUS: ${response.statusCode}");
        return null;
      }

      final data = jsonDecode(response.body);
      final dynamic coordinates =
          data["features"]?[0]?["geometry"]?["coordinates"];

      if (coordinates is! List || coordinates.length < 2) return null;

      final lon = (coordinates[0] as num?)?.toDouble();
      final lat = (coordinates[1] as num?)?.toDouble();
      if (lat == null || lon == null) return null;

      final location = OrsLocationCoordinates(lat: lat, lon: lon);
      _barangayCache[key] = location;
      return location;
    } catch (e) {
      debugPrint("ORS GEOCODER NETWORK/PARSING ERROR: $e");
      return null;
    }
  }

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
    if (!_hasUsableApiKey) {
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
