// lib/services/weather_api_service.dart

import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../../models/weather_forecast.dart'; // Importe o modelo de dados de previsão do tempo, se aplicável

class WeatherApiService {
  Future<WeatherForecast> fetchWeatherForCuritiba() async {
    try {
      final apiKey = dotenv.env['OPENWEATHERMAP_API_KEY'] ?? '';
      const lat = '-25.4325';
      const lon = '-49.2827';
      final url = Uri.parse('https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return WeatherForecast.fromJson(data);
      } else {
        throw "Falha ao carregar dados de previsão do tempo: ${response.statusCode}";
      }
    } catch (e) {
      throw "Erro ao carregar dados de previsão do tempo: $e";
    }
  }
}
