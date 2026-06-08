import 'package:flutter/material.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/client/cliente_home_screen.dart';
import '../screens/client/cliente_checkout_screen.dart';
import '../screens/client/cliente_pago_screen.dart';
import '../screens/admin/admin_home_screen.dart';
import '../screens/admin/admin_crear_pedido_screen.dart';
import '../screens/admin/admin_editar_pedido_screen.dart';
import '../screens/profile_screen.dart';

class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String clientHome = '/client-home';
  static const String clienteCheckout = '/client-checkout';
  static const String clientePago = '/client-pago';
  static const String adminHome = '/admin-home';
  static const String adminCrearPedido = '/admin-crear-pedido';
  static const String adminEditarPedido = '/admin-editar-pedido';
  static const String profile = '/profile';

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      login: (context) => const LoginScreen(),
      register: (context) => const RegisterScreen(),
      clientHome: (context) => const ClienteHomeScreen(),
      clienteCheckout: (context) => const ClienteCheckoutScreen(),
      clientePago: (context) => const ClientePagoScreen(),
      adminHome: (context) => const AdminHomeScreen(),
      adminCrearPedido: (context) => const AdminCrearPedidoScreen(),
      adminEditarPedido: (context) => const AdminEditarPedidoScreen(orderId: ''),
      profile: (context) => const ProfileScreen(),
    };
  }
}
