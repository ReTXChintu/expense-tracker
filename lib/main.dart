import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/storage.dart';
import 'core/notifs.dart';
import 'providers.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await NotifManager.init();
  final loggedIn = await AppStorage.hasToken();
  runApp(ProviderScope(
    overrides: [isLoggedInProvider.overrideWith((ref) => loggedIn)],
    child: const App(),
  ));
}
