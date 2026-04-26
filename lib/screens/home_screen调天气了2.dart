import 'dart:async';
import 'dart:math';
import 'dart:convert'; // 用于解析 JSON
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart'; // 定位包
import 'package:http/http.dart' as http; // 网络请求包

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String currentWeather = "Sunny"; // 默认状态
  String currentPace = "Slow";
  bool isLoadingWeather = false; // 是否正在加载天气，用于显示 loading 圈圈

  // ⚠️ 把这里换成你在 OpenWeather 申请的 API Key ！！！
  final String apiKey = "a833233089968a714179313e8e711790";

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  StreamSubscription<UserAccelerometerEvent>? _sensorSubscription;
  DateTime _lastShakeTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    // 页面一加载，就自动去获取真实天气！
    _fetchRealWeather();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _stopSensor();
    super.dispose();
  }

  // ============== 核心：获取GPS位置 & 调用天气API ==============
  Future<void> _fetchRealWeather() async {
    setState(() => isLoadingWeather = true); // 开启 Loading 动画

    try {
      // 1. 获取定位权限
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied)
          throw Exception("用户拒绝了定位权限");
      }

      // 2. 获取当前经纬度
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );

      // 3. 拼接 OpenWeather API 链接
      String url =
          "https://api.openweathermap.org/data/2.5/weather?lat=${position.latitude}&lon=${position.longitude}&appid=$apiKey";

      // 4. 发送 HTTP 请求获取真实天气数据
      var response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        String mainWeather =
            jsonResponse['weather'][0]['main']; // 返回的结果可能是 "Clear", "Rain", "Clouds" 等

        print("🌍 真实天气数据抓取成功: $mainWeather");

        // 5. 把复杂的真实天气，映射到我们简单的 3 种状态上
        setState(() {
          if (mainWeather.contains("Clear")) {
            currentWeather = "Sunny";
          } else if (mainWeather.contains("Rain") ||
              mainWeather.contains("Drizzle") ||
              mainWeather.contains("Thunderstorm")) {
            currentWeather = "Rainy";
          } else {
            currentWeather = "Cloudy"; // 其他的如多云、下雪、大雾都算阴天
          }
          isLoadingWeather = false;
        });

        // 如果音乐正在播放，天气变了，自动无缝切歌！
        if (_isPlaying) {
          _audioPlayer.play(AssetSource(_getAudioPath()));
        }
      } else {
        print("❌ API 请求失败: ${response.statusCode}");
        setState(() => isLoadingWeather = false);
      }
    } catch (e) {
      print("❌ 获取位置或天气出错: $e");
      setState(() => isLoadingWeather = false);
    }
  }
  // ============================================================

  // 之前的传感器代码保持不变
  void _startSensor() {
    _sensorSubscription = userAccelerometerEventStream().listen((event) {
      double magnitude = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      if (magnitude > 3.0) {
        _lastShakeTime = DateTime.now();
        if (currentPace != "Fast") _changePace("Fast");
      } else {
        if (DateTime.now().difference(_lastShakeTime).inSeconds > 3) {
          if (currentPace != "Slow") _changePace("Slow");
        }
      }
    });
  }

  void _stopSensor() => _sensorSubscription?.cancel();

  // 注意：确保你的 assets/audio 文件夹里有这 6 个文件
  String _getAudioPath() {
    if (currentWeather == "Sunny" && currentPace == "Slow")
      return "audio/sunny_slow.wav";
    if (currentWeather == "Sunny" && currentPace == "Fast")
      return "audio/sunny_fast.wav";
    if (currentWeather == "Rainy" && currentPace == "Slow")
      return "audio/rainy_slow.wav";
    if (currentWeather == "Rainy" && currentPace == "Fast")
      return "audio/rainy_fast.wav";
    if (currentWeather == "Cloudy" && currentPace == "Slow")
      return "audio/cloudy_slow.wav";
    if (currentWeather == "Cloudy" && currentPace == "Fast")
      return "audio/cloudy_fast.wav";
    return "audio/sunny_slow.wav"; // 兜底保护
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'WalkBeat',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // 在右上角加一个手动刷新天气的按钮，方便你做 Presentation 时演示
          IconButton(
            icon: isLoadingWeather
                ? const CircularProgressIndicator(color: Colors.white)
                : const Icon(Icons.refresh),
            onPressed: isLoadingWeather ? null : _fetchRealWeather,
            tooltip: "刷新当前真实天气",
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 用优雅的方式展示当前状态
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "🌍 天气: $currentWeather",
                style: const TextStyle(fontSize: 22, color: Colors.white),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: currentPace == "Fast"
                    ? Colors.deepOrange.withOpacity(0.2)
                    : Colors.blueGrey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "👟 步伐: $currentPace",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: currentPace == "Fast"
                      ? Colors.deepOrangeAccent
                      : Colors.lightBlueAccent,
                ),
              ),
            ),
            const SizedBox(height: 60),

            // 视觉中心区
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: currentPace == "Fast"
                    ? Colors.deepOrange.withOpacity(0.3)
                    : Colors.blueGrey.withOpacity(0.2),
                border: Border.all(
                  color: currentPace == "Fast"
                      ? Colors.deepOrange
                      : Colors.blueGrey,
                  width: _isPlaying ? 4 : 1,
                ),
              ),
              child: Center(
                child: Icon(
                  _isPlaying ? Icons.directions_walk : Icons.accessibility_new,
                  size: 80,
                  color: currentPace == "Fast"
                      ? Colors.deepOrange
                      : Colors.blueGrey,
                ),
              ),
            ),
            const SizedBox(height: 60),

            ElevatedButton.icon(
              onPressed: _toggleAudio,
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              label: Text(_isPlaying ? "结束行程" : "开始你的散步"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
                backgroundColor: _isPlaying ? Colors.redAccent : Colors.teal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
