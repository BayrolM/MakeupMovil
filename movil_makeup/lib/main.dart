import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'providers/carrito_provider.dart';
import 'providers/producto_provider.dart';
import 'providers/pedido_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/client/cliente_home_screen.dart';
import 'screens/admin/admin_home_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  
  // Inicializar Supabase usando las variables de entorno
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(),
        ),
        ChangeNotifierProvider(create: (_) => CarritoProvider()),
        ChangeNotifierProvider(create: (_) => ProductoProvider()),
        ChangeNotifierProvider(create: (_) => PedidoProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return MaterialApp(
            title: 'Glamour ML',
            theme: AppTheme.lightTheme,
            debugShowCheckedModeBanner: false,
            // Si está logueado como admin, va al panel de admin. De lo contrario (cliente o invitado) va a la tienda
            home: auth.isLoggedIn && auth.userRole == 'admin'
                ? const AdminHomeScreen()
                : const ClienteHomeScreen(),
            routes: AppRoutes.getRoutes(),
          );
        },
      ),
    );
  }
}
