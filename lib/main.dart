import 'package:flutter/material.dart';
import 'screens/home_screen.dart'; 
import 'package:firebase_core/firebase_core.dart'; // 1. 导入核心库
import 'firebase_options.dart'; // 2. 导入刚才生成的配置文件

void main() async {
  // 3. 确保插件服务初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 4. 根据当前平台自动加载 Firebase 配置
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const WalkBeatApp());
}

class WalkBeatApp extends StatelessWidget {
  const WalkBeatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WalkBeat', // App 的名字
      debugShowCheckedModeBanner: false, // 隐藏右上角丑陋的 Debug 标签
      // 设置 App 的全局主题为深色模式，符合高级感
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blueGrey,
        scaffoldBackgroundColor: const Color(0xFF121212), // 极黑背景
      ),
      home: const HomeScreen(), // App 启动后显示的第一个页面
    );
  }
}
