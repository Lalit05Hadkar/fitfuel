import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'screens/diary_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/train_screen.dart';
import 'services/ai_service.dart';
import 'services/storage_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = StorageService();
  await storage.init();
  final state = AppState(storage)..load();
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: state),
      Provider(create: (_) => AiService()),
    ],
    child: const FitFuelApp(),
  ));
}

class FitFuelApp extends StatelessWidget {
  const FitFuelApp({super.key});

  @override
  Widget build(BuildContext context) {
    final hasProfile = context.select<AppState, bool>((s) => s.profile != null);
    return MaterialApp(
      title: 'FitFuel',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: hasProfile ? const Shell() : const OnboardingScreen(),
    );
  }
}

/// Bottom-tab shell: Home, Diary, Scan, Train, Progress.
class Shell extends StatefulWidget {
  const Shell({super.key});
  static void goTo(BuildContext context, int tab) => context.findAncestorStateOfType<_ShellState>()?.go(tab);

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;
  void go(int i) => setState(() => index = i);

  @override
  Widget build(BuildContext context) {
    const pages = [HomeScreen(), DiaryScreen(), ScanScreen(), TrainScreen(), ProgressScreen()];
    return Scaffold(
      body: SafeArea(bottom: false, child: IndexedStack(index: index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: go,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Diary'),
          NavigationDestination(icon: Icon(Icons.center_focus_weak), selectedIcon: Icon(Icons.center_focus_strong), label: 'Scan'),
          NavigationDestination(icon: Icon(Icons.fitness_center_outlined), selectedIcon: Icon(Icons.fitness_center), label: 'Train'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Progress'),
        ],
      ),
    );
  }
}
