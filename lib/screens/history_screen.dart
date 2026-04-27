import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Walking Diary'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(

        stream: FirebaseFirestore.instance
            .collection('walk_sessions')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "You haven't recorded any walks yet~",
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          var docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.all(20),
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;

              // 时间显示
              String rawDate = data['date'] ?? "";
              String formattedDate = rawDate.length >= 16
                  ? rawDate.substring(0, 16).replaceAll("T", " ")
                  : rawDate;

              return Card(
                color: Colors.white10,
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(15),
                  leading: const CircleAvatar(
                    backgroundColor: Colors.teal,
                    child: Icon(Icons.directions_walk, color: Colors.white),
                  ),
                  title: Text(
                    "${data['city']} - ${data['weather']}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "duration: ${data['duration_seconds']} seconds",
                          style: const TextStyle(color: Colors.white70),
                        ),
                        Text(
                          "temperature: ${data['temperature']}",
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          formattedDate,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white30,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
