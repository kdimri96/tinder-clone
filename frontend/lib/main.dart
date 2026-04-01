import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'services/socket_service.dart';
import 'providers/auth_provider.dart';
import 'providers/discovery_provider.dart';
import 'providers/match_provider.dart';
import 'providers/chat_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/complete_profile_screen.dart';
import 'models/user_model.dart';
import 'utils/app_theme.dart';

void main() {
  runApp(const TinderCloneApp());
}

class TinderCloneApp extends StatelessWidget {
  const TinderCloneApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final apiService = ApiService();
    final socketService = SocketService();

    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        Provider<SocketService>.value(value: socketService),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(apiService, socketService),
        ),
        ChangeNotifierProvider(
          create: (_) => DiscoveryProvider(apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => MatchProvider(apiService, socketService),
        ),
        ChangeNotifierProvider(
          create: (_) => ChatProvider(apiService, socketService),
        ),
      ],
      child: MaterialApp(
        title: 'Tinder Clone',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        initialRoute: '/',
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/':
              return MaterialPageRoute(builder: (_) => const SplashScreen());
            case '/welcome':
              return MaterialPageRoute(builder: (_) => const WelcomeScreen());
            case '/login':
              return MaterialPageRoute(builder: (_) => const LoginScreen());
            case '/register':
              return MaterialPageRoute(builder: (_) => const RegisterScreen());
            case '/complete-profile':
              return MaterialPageRoute(builder: (_) => const CompleteProfileScreen());
            case '/home':
              return MaterialPageRoute(builder: (_) => const HomeScreen());
            case '/matches':
              return MaterialPageRoute(builder: (_) => const HomeScreen());
            case '/chat':
              final args = settings.arguments as Map<String, dynamic>?;
              if (args != null) {
                return MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    matchId: args['matchId'] as String,
                    otherUser: args['user'] as UserModel,
                  ),
                );
              }
              return MaterialPageRoute(builder: (_) => const HomeScreen());
            default:
              return MaterialPageRoute(builder: (_) => const SplashScreen());
          }
        },
      ),
    );
  }
}
