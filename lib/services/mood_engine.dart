
import 'package:flutter/material.dart';

enum StepFreq { stopped, slow, fast }
enum WeatherType { sunny, rainy, windy, cloudy }
enum Mood { sunnyCalm, sunnyActive, rainCalm, rainActive, windCalm, windActive }

class MoodResult {
  final Mood mood;
  final String audioFile;
  final List<Color> colors;

  MoodResult({required this.mood, required this.audioFile, required this.colors});
}

class MoodEngine {
  static MoodResult getMood(StepFreq step, WeatherType weather) {
    if (weather == WeatherType.rainy && step == StepFreq.fast) {
      return MoodResult(
        mood: Mood.rainActive,
        audioFile: 'assets/audio/rain_fast.mp3',
        colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
      );
    } else if (weather == WeatherType.rainy) {
      return MoodResult(
        mood: Mood.rainCalm,
        audioFile: 'assets/audio/rain_slow.mp3',
        colors: [Color(0xFF2c3e50), Color(0xFF3498db)],
      );
    } else if (weather == WeatherType.windy && step == StepFreq.fast) {
      return MoodResult(
        mood: Mood.windActive,
        audioFile: 'assets/audio/wind_fast.mp3',
        colors: [Color(0xFFcc5500), Color(0xFFe8871a)],
      );
    } else if (weather == WeatherType.windy) {
      return MoodResult(
        mood: Mood.windCalm,
        audioFile: 'assets/audio/wind_slow.mp3',
        colors: [Color(0xFF8e9eab), Color(0xFFeef2f3)],
      );
    } else if (step == StepFreq.fast) {
      return MoodResult(
        mood: Mood.sunnyActive,
        audioFile: 'assets/audio/sunny_fast.mp3',
        colors: [Color(0xFFf7971e), Color(0xFFffd200)],
      );
    } else {
      return MoodResult(
        mood: Mood.sunnyCalm,
        audioFile: 'assets/audio/sunny_slow.mp3',
        colors: [Color(0xFF56ab2f), Color(0xFFa8e063)],
      );
    }
  }

  // 把加速度计原始值转成三档
  static StepFreq classify(double magnitude) {
    if (magnitude < 2.0) return StepFreq.stopped;
    if (magnitude < 7.0) return StepFreq.slow;
    return StepFreq.fast;
  }
}