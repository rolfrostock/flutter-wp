//lib/models/weather_forecast.dart

class WeatherForecast {
  final double temperature;
  final String description;
  final String? iconCode; // Make this nullable

  WeatherForecast({
    required this.temperature,
    required this.description,
    this.iconCode, // Now it's okay to be null
  });

  factory WeatherForecast.fromJson(Map<String, dynamic> json) {
    return WeatherForecast(
      temperature: json['main']['temp'],
      description: json['weather'][0]['description'],
      iconCode: json['weather'][0]['icon'] as String?, // Safely cast as nullable String
    );
  }
}
