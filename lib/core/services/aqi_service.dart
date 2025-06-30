import 'dart:convert';
import 'package:http/http.dart' as http;

/// Fetches Sentinel-5P-based AQI data from Open-Meteo Air Quality API
Future<Map<String, dynamic>?> fetchSentinelAQI(double lat, double lon) async {
  final url = Uri.parse(
    'https://air-quality-api.open-meteo.com/v1/air-quality'
        '?latitude=$lat'
        '&longitude=$lon'
        '&hourly=pm2_5,pm10,nitrogen_dioxide,carbon_monoxide,ozone,sulphur_dioxide'
        '&timezone=auto',
  );

  try {
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      print('🌐 API Error: ${response.statusCode} - ${response.body}');
      return null;
    }
  } catch (e) {
    print('❌ Exception in AQI fetch: $e');
    return null;
  }
}

/// Classifies PM2.5 value based on Indian AQI standards
String classifyAQI(double pm25) {
  if (pm25 <= 30) return "Good";
  if (pm25 <= 60) return "Moderate";
  if (pm25 <= 90) return "Poor";
  if (pm25 <= 120) return "Very Poor";
  return "Severe";
}

/// Generic function to extract hourly pollutant values
List<double> getHourlyValues(Map<String, dynamic> aqiData, String pollutantKey) {
  final List<dynamic>? values = aqiData['hourly']?[pollutantKey];

  if (values == null) {
    print("⚠️ $pollutantKey data missing.");
    return [];
  }
  return values.map<double>((e) => (e ?? 0).toDouble()).toList();
}
