import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'services/ad_service.dart';
import 'services/progress_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Game sirf portrait (seedhe phone) mein chalegi
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Status bar transparent (upar gehri patti nahi), safed icons, aur app
  // poori screen par (status bar ke peeche tak) draw ho
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  // Store screenshots wale build mein koi ad nahi
  if (AppConfig.storeShots) AdService.enabled = false;

  // Save kiya hua data (level, coins, settings) load karo
  await ProgressService.instance.load();

  // Tasveerein, awaazen aur music LoadingScreen load karti hai
  // Ads (consent ke baad) HomeScreen khulne par shuru hote hain
  runApp(const BusJamApp());
}
