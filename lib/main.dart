import 'package:flutter/material.dart';
import 'home_page.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'reports_page.dart' as reports;
import 'settings_page.dart';
import 'notification_controller.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('Initializing app and notifications...');
  try {
    // Initialize the Awesome Notifications
    await AwesomeNotifications().initialize(
      null, // no default icon for now
      [
        NotificationChannel(
          channelGroupKey: 'basic_channel_group',
          channelKey: 'basic_channel',
          channelName: 'Basic Notifications',
          channelDescription: 'Channel for basic notifications',
          defaultColor: Colors.blue,
          ledColor: Colors.white,
          importance: NotificationImportance.High,
          channelShowBadge: true,
          enableVibration: true,
          enableLights: true,
        ),
      ],
      debug: true,
    );

    debugPrint('Awesome Notifications initialized successfully');

    // Set up notification listeners
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: NotificationController.onActionReceivedMethod,
      onDismissActionReceivedMethod:
          NotificationController.onDismissActionReceivedMethod,
    );

    // Request notification permissions
    await AwesomeNotifications().isNotificationAllowed().then((
      isAllowed,
    ) async {
      if (!isAllowed) {
        await AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });
  } catch (error) {
    debugPrint('Error initializing notifications: $error');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sunrise Sunset App',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
        ),
        colorScheme: ColorScheme.light(
          primary: Colors.blue,
          secondary: Colors.blue.shade700,
          surface: Colors.grey[100]!,
        ),
        cardColor: Colors.white,
        dividerColor: Colors.grey[300],
        buttonTheme: const ButtonThemeData(
          buttonColor: Colors.blue,
          textTheme: ButtonTextTheme.primary,
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.blue.shade700),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            foregroundColor: Colors.blue.shade700,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey[600],
        ),
        textTheme: const TextTheme(
          titleMedium: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          bodyMedium: TextStyle(color: Colors.black87, fontSize: 15),
          labelMedium: TextStyle(color: Colors.black54, fontSize: 14),
        ),
        useMaterial3: true,
      ),
      home: const MainNavigator(),
    );
  }
}

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = [
    const HomePage(),
    const reports.ReportsPage(),
    const SettingsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              spreadRadius: 0,
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              spreadRadius: 0,
              blurRadius: 5,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.description),
              label: 'Reports',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor:
              Theme.of(context).bottomNavigationBarTheme.selectedItemColor,
          unselectedItemColor:
              Theme.of(context).bottomNavigationBarTheme.unselectedItemColor,
          backgroundColor:
              Theme.of(context).bottomNavigationBarTheme.backgroundColor,
          onTap: _onItemTapped,
          elevation:
              0, // Remove default elevation since we're using custom shadow
        ),
      ),
    );
  }
}
