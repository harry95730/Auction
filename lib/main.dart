import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/auction_command_app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {
    return;
  }
  runApp(const AuctionCommandApp());
}
