import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _volume = 1.0;
  double _paceThreshold = 3.0; 

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _volume = prefs.getDouble('volume') ?? 1.0;
      _paceThreshold = prefs.getDouble('paceThreshold') ?? 3.0;
    });
  }
//voice
  Future<void> _saveVolume(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('volume', value);
    setState(() => _volume = value);
  }
//sensor
  Future<void> _saveThreshold(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('paceThreshold', value);
    setState(() => _paceThreshold = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Audio Settings",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              "Music Volume",
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            Row(
              children: [
                const Icon(Icons.volume_mute, color: Colors.white54),
                Expanded(
                  child: Slider(
                    value: _volume,
                    min: 0.0,
                    max: 1.0,
                    activeColor: Colors.teal,
                    onChanged: _saveVolume,
                  ),
                ),
                const Icon(Icons.volume_up, color: Colors.white54),
              ],
            ),

            const Divider(height: 50, color: Colors.white24),

            const Text(
              "Sensor Calibration",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.orangeAccent,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Adjust how hard you need to walk to trigger 'Fast Pace' mode.",
              style: TextStyle(fontSize: 14, color: Colors.white54),
            ),
            const SizedBox(height: 20),

            // sensor threshold slider
            Text(
              "Pace Threshold: ${_paceThreshold.toStringAsFixed(1)}",
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
            Slider(
              value: _paceThreshold,
              min: 1.0,
              max: 8.0,
              divisions: 14,
              activeColor: Colors.orangeAccent,
              onChanged: _saveThreshold,
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Very Sensitive",
                  style: TextStyle(fontSize: 12, color: Colors.white30),
                ),
                Text(
                  "Requires Running",
                  style: TextStyle(fontSize: 12, color: Colors.white30),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
