import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // 引入 debugPrint 消除警告
import 'package:audioplayers/audioplayers.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- 状态变量扩展 ---
  String currentWeather = "Sunny";
  String currentPace = "Slow";
  bool isLoadingWeather = false;

  String cityName = "定位中...";
  String temperature = "--";
  String weatherDetail = "等待获取...";

  // 填入你的 API Key
  final String apiKey = "a833233089968a714179313e8e711790";

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  StreamSubscription<UserAccelerometerEvent>? _sensorSubscription;
  DateTime _lastShakeTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    _fetchRealWeather();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _stopSensor();
    super.dispose();
  }

  // ============== API 获取逻辑 (恢复稳定版网络逻辑，仅修复警告) ==============
  Future<void> _fetchRealWeather() async {
    setState(() => isLoadingWeather = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception("权限被拒");
        }
      }

      // 恢复你原始的获取逻辑，仅仅把废弃的 desiredAccuracy 换成了官方推荐的新写法（功能完全一样）
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      );

      String url =
          "https://api.openweathermap.org/data/2.5/weather?lat=${position.latitude}&lon=${position.longitude}&appid=$apiKey&units=metric";

      var response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);

        String mainWeather = jsonResponse['weather'][0]['main'];
        String description = jsonResponse['weather'][0]['description'];
        String fetchedCity = jsonResponse['name'];
        double fetchedTemp = jsonResponse['main']['temp'];

        setState(() {
          cityName = fetchedCity;
          temperature = "${fetchedTemp.toStringAsFixed(1)}°C";
          weatherDetail = description;

          if (mainWeather.contains("Clear")) {
            currentWeather = "Sunny";
          } else if (mainWeather.contains("Rain") ||
              mainWeather.contains("Drizzle") ||
              mainWeather.contains("Thunderstorm")) {
            currentWeather = "Rainy";
          } else {
            currentWeather = "Cloudy";
          }
          isLoadingWeather = false;
        });

        if (_isPlaying) {
          _audioPlayer.play(AssetSource(_getAudioPath()));
        }
      } else {
        setState(() => isLoadingWeather = false);
      }
    } catch (e) {
      // 使用 debugPrint 替代 print 消除警告
      debugPrint("Error: $e");
      setState(() => isLoadingWeather = false);
    }
  }

  // ============== 传感器与播放逻辑 ==============
  void _startSensor() {
    _sensorSubscription = userAccelerometerEventStream().listen((event) {
      double magnitude = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      if (magnitude > 3.0) {
        _lastShakeTime = DateTime.now();
        // 增加大括号消除警告
        if (currentPace != "Fast") {
          _changePace("Fast");
        }
      } else {
        if (DateTime.now().difference(_lastShakeTime).inSeconds > 3) {
          // 增加大括号消除警告
          if (currentPace != "Slow") {
            _changePace("Slow");
          }
        }
      }
    });
  }

  void _stopSensor() => _sensorSubscription?.cancel();

  String _getAudioPath() {
    // 增加大括号消除警告
    if (currentWeather == "Sunny" && currentPace == "Slow") {
      return "audio/sunny_slow.wav";
    }
    if (currentWeather == "Sunny" && currentPace == "Fast") {
      return "audio/sunny_fast.wav";
    }
    if (currentWeather == "Rainy" && currentPace == "Slow") {
      return "audio/rainy_slow.wav";
    }
    if (currentWeather == "Rainy" && currentPace == "Fast") {
      return "audio/rainy_fast.wav";
    }
    if (currentWeather == "Cloudy" && currentPace == "Slow") {
      return "audio/cloudy_slow.wav";
    }
    if (currentWeather == "Cloudy" && currentPace == "Fast") {
      return "audio/cloudy_fast.wav";
    }
    return "audio/sunny_slow.wav";
  }

  void _toggleAudio() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      _stopSensor();
      setState(() {
        _isPlaying = false;
        currentPace = "Slow";
      });
    } else {
      String path = _getAudioPath();
      await _audioPlayer.play(AssetSource(path));
      _startSensor();
      setState(() => _isPlaying = true);
    }
  }

  void _changePace(String newPace) async {
    setState(() => currentPace = newPace);
    if (_isPlaying) {
      await _audioPlayer.play(AssetSource(_getAudioPath()));
    }
  }

  // ============== UI 界面设计 ==============
  @override
  Widget build(BuildContext context) {
    Color weatherColor;
    if (currentWeather == "Sunny") {
      weatherColor = Colors.orangeAccent;
    } else if (currentWeather == "Rainy") {
      weatherColor = Colors.blueAccent;
    } else {
      weatherColor = Colors.blueGrey;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'WalkBeat',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: isLoadingWeather
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: isLoadingWeather ? null : _fetchRealWeather,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                // 替换废弃的 withOpacity 为 withValues(alpha: x)
                color: weatherColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: weatherColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.white70,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        cityName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Text(
                        temperature,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w300,
                          color: Colors.white,
                        ),
                      ),
                      Container(width: 1, height: 40, color: Colors.white24),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentWeather,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: weatherColor,
                            ),
                          ),
                          Text(
                            weatherDetail,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 50),

            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              width: currentPace == "Fast" ? 240 : 200,
              height: currentPace == "Fast" ? 240 : 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: currentPace == "Fast"
                    ? weatherColor.withValues(alpha: 0.4)
                    : weatherColor.withValues(alpha: 0.1),
                border: Border.all(
                  color: weatherColor,
                  width: _isPlaying ? (currentPace == "Fast" ? 8 : 2) : 1,
                ),
                boxShadow: _isPlaying
                    ? [
                        BoxShadow(
                          color: weatherColor.withValues(alpha: 0.5),
                          blurRadius: 30,
                          spreadRadius: currentPace == "Fast" ? 10 : 2,
                        ),
                      ]
                    : [],
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    _isPlaying
                        ? (currentPace == "Fast"
                              ? Icons.directions_run
                              : Icons.directions_walk)
                        : Icons.headphones,
                    key: ValueKey<bool>(_isPlaying),
                    size: 80,
                    color: weatherColor,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 60),

            AnimatedOpacity(
              opacity: _isPlaying ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: Text(
                currentPace == "Fast"
                    ? "🔥 步频较快，已为您切换节奏音乐"
                    : "🍃 正在漫步，为您播放舒缓环境音",
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: _toggleAudio,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
                backgroundColor: _isPlaying ? Colors.white12 : weatherColor,
                elevation: _isPlaying ? 0 : 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isPlaying ? Icons.stop_circle_outlined : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isPlaying ? "结束行程" : "戴上耳机，开始探索",
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
