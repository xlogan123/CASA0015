import 'dart:async'; // 处理传感器数据流
import 'dart:math'; // 用于开平方根计算
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:sensors_plus/sensors_plus.dart'; // 引入传感器包
//api key：a833233089968a714179313e8e711790

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- 状态变量区 ---
  String currentWeather = "Sunny";
  String currentPace = "Slow";

  // 音频相关
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  // 传感器相关
  StreamSubscription<UserAccelerometerEvent>? _sensorSubscription; // 监听器
  DateTime _lastShakeTime = DateTime.now(); // 记录最后一次剧烈晃动的时间

  @override
  void initState() {
    super.initState();
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _stopSensor(); // 页面销毁时，务必关闭传感器，省电拿高分细节！
    super.dispose();
  }

  // --- 核心算法：监听传感器数据 ---
  void _startSensor() {
    // userAccelerometerEventStream 会滤除重力，只保留用户自身的加速度，非常适合用来计步
    _sensorSubscription = userAccelerometerEventStream().listen((
      UserAccelerometerEvent event,
    ) {
      // 高中物理：求 X, Y, Z 三个方向加速度的合力 (向量长度)
      double magnitude = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );

      // 阈值设定：如果合力大于 3.0，判定为正在快走/跑步 (你可以根据真机测试修改这个值)
      if (magnitude > 3.0) {
        _lastShakeTime = DateTime.now(); // 更新最后一次晃动的时间
        if (currentPace != "Fast") {
          _changePace("Fast"); // 触发快走状态
        }
      } else {
        // 如果合力小，说明可能停下来了。但为了防止手抖导致的误判，
        // 我们要求：必须距离上一次剧烈晃动超过 3 秒钟，才真正切换回"慢走"
        if (DateTime.now().difference(_lastShakeTime).inSeconds > 3) {
          if (currentPace != "Slow") {
            _changePace("Slow");
          }
        }
      }
    });
  }

  void _stopSensor() {
    _sensorSubscription?.cancel(); // 取消监听
  }

  // --- 逻辑：获取该放哪首歌 ---
  String _getAudioPath() {
    if (currentWeather == "Sunny" && currentPace == "Slow") {
      return "audio/sunny_slow2.wav";
    } else if (currentWeather == "Sunny" && currentPace == "Fast") {
      return "audio/sunny_fast.wav";
    }
    // TODO: 等你加了雨天和阴天的 wav，在这里补充 else if 逻辑
    return "audio/sunny_slow.wav";
  }

  // --- 播放/暂停控制 ---
  void _toggleAudio() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      _stopSensor(); // 音乐暂停时，也关闭传感器以省电
      setState(() {
        _isPlaying = false;
        currentPace = "Slow"; // 暂停后默认重置为慢走
      });
    } else {
      String path = _getAudioPath();
      await _audioPlayer.play(AssetSource(path));
      _startSensor(); // 音乐开始时，启动传感器监听！
      setState(() {
        _isPlaying = true;
      });
    }
  }

  // --- 切换步伐逻辑 ---
  void _changePace(String newPace) async {
    setState(() {
      currentPace = newPace;
    });
    if (_isPlaying) {
      String path = _getAudioPath();
      await _audioPlayer.play(AssetSource(path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'WalkBeat 节奏伴侣',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "当前环境: $currentWeather",
              style: const TextStyle(fontSize: 24, color: Colors.white70),
            ),
            const SizedBox(height: 10),

            // 动态显示当前的步伐，如果是快走，字会变成醒目的橙红
            Text(
              "你的步伐: $currentPace",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: currentPace == "Fast"
                    ? Colors.deepOrangeAccent
                    : Colors.lightBlueAccent,
              ),
            ),
            const SizedBox(height: 60),

            // 视觉中心区域
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // 根据步伐动态改变 UI 颜色，快走是狂热的橙色，慢走是冷静的灰色
                color: currentPace == "Fast"
                    ? Colors.deepOrange.withOpacity(0.3)
                    : Colors.blueGrey.withOpacity(0.2),
                border: Border.all(
                  color: currentPace == "Fast"
                      ? Colors.deepOrange
                      : Colors.blueGrey,
                  width: _isPlaying ? 4 : 1, // 播放时边框变粗
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

            // 主播放按钮
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
