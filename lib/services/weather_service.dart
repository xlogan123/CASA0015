import 'dart:convert';
import 'package:http/http.dart' as http;
import 'mood_engine.dart';

class WeatherService {
  // 去 openweathermap.org 注册免费账号拿key，替换下面这行
  static const _apiKey = 'YOUR_API_KEY_HERE';

  static Future<WeatherType> getWeather(double lat, double lon) async {
    final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$_apiKey'
    );
    final res = await http.get(url);
    if (res.statusCode != 200) return WeatherType.sunny;

    final data = jsonDecode(res.body);
    final id = data['weather'][0]['id'] as int;

    if (id >= 200 && id < 700) return WeatherType.rainy;  // 雨/雷/雪
    if (id >= 700 && id < 800) return WeatherType.cloudy; // 雾霾
    if (id == 800) return WeatherType.sunny;               // 晴
    return WeatherType.windy;                              // 多云
  }
}