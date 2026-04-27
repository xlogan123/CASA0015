import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart'; 

import 'history_screen.dart';
import 'settings_screen.dart'; 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String currentWeather = "Sunny";
  String currentPace = "Slow";
  bool isLoadingWeather = false;

  String cityName = "Locating...";
  String temperature = "--";
  String weatherDetail = "Fetching data...";

  final String apiKey = "a833233089968a714179313e8e711790";

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  StreamSubscription<UserAccelerometerEvent>? _sensorSubscription;
  DateTime _lastShakeTime = DateTime.now();
  DateTime? _sessionStartTime;

  double _userVolume = 1.0;
  double _userPaceThreshold = 3.0;

  @override
  void initState() {
    super.initState();
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    _loadSettings(); 
    _fetchRealWeather();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userVolume = prefs.getDouble('volume') ?? 1.0;
      _userPaceThreshold = prefs.getDouble('paceThreshold') ?? 3.0;
    });
    _audioPlayer.setVolume(_userVolume); 
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _stopSensor();
    super.dispose();
  }

  Future<void> _fetchRealWeather() async {
    setState(() {
      isLoadingWeather = true;
      cityName = "Locating...";
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception("Permission denied");
        }
      }

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
          weatherDetail =
              description[0].toUpperCase() + description.substring(1);

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
      debugPrint("Error: $e");
      setState(() {
        isLoadingWeather = false;
        cityName = "Location Failed";
        temperature = "N/A";
        weatherDetail = "Check network or GPS";
      });
    }
  }

  void _startSensor() {
    
    _loadSettings();

    _sensorSubscription = userAccelerometerEventStream().listen((event) {
      double magnitude = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );

     
      if (magnitude > _userPaceThreshold) {
        _lastShakeTime = DateTime.now();
        if (currentPace != "Fast") {
          _changePace("Fast");
        }
      } else {
        if (DateTime.now().difference(_lastShakeTime).inSeconds > 3) {
          if (currentPace != "Slow") {
            _changePace("Slow");
          }
        }
      }
    });
  }

  void _stopSensor() => _sensorSubscription?.cancel();

String _getAudioPath() {
    if (currentWeather == "Sunny") {
      return currentPace == "Slow"
          ? "audio/sunny_slow.mp3"
          : "audio/sunny_fast.mp3";
    }

    if (currentWeather == "Rainy") {
      return currentPace == "Slow"
          ? "audio/rain_slow.mp3"
          : "audio/rain_fast.mp3";
    }

    if (currentWeather == "Cloudy") {
      return currentPace == "Slow"
          ? "audio/cloudy_slow.mp3"
          : "audio/cloudy_fast.mp3";
    }
    return "audio/sunny_slow.mp3";
  }

  void _toggleAudio() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      _stopSensor();

      if (_sessionStartTime != null) {
        Duration duration = DateTime.now().difference(_sessionStartTime!);

        Map<String, dynamic> walkData = {
          "city": cityName,
          "weather": currentWeather,
          "weather_detail": weatherDetail,
          "temperature": temperature,
          "duration_seconds": duration.inSeconds,
          "date": DateTime.now().toIso8601String(),
        };

        try {
          await FirebaseFirestore.instance
              .collection('walk_sessions')
              .add(walkData);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("🎉 Session ended! Data synced to cloud."),
                backgroundColor: Colors.teal,
                duration: Duration(seconds: 3),
              ),
            );
          }
        } catch (e) {
          debugPrint("Upload failed: $e");
        }
      }

      setState(() {
        _isPlaying = false;
        currentPace = "Slow";
        _sessionStartTime = null;
      });
    } else {
      await _loadSettings(); 
      String path = _getAudioPath();
      await _audioPlayer.play(AssetSource(path));
      _startSensor();

      setState(() {
        _isPlaying = true;
        _sessionStartTime = DateTime.now();
      });
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
            tooltip: "Refresh Weather",
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: "Walk Diary",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: "Settings",
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
              _loadSettings();
            },
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
                    ? "🔥 Fast pace. Upbeat track playing."
                    : "🍃 Slow pace. Calming ambiance playing.",
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
                    _isPlaying ? "End Walk" : "Put on headphones & Start",
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
