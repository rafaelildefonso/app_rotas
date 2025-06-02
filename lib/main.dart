import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapa_teste/instructions_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mapa App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: InstructionsPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
