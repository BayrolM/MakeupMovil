import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../config/theme.dart';
import '../config/routes.dart';

class AppSidebar extends StatefulWidget {
  const AppSidebar({super.key});

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  bool _loggingOut = false;

  @override
  Widget build(BuildContext context) {
    final authProv = Provider.of<AuthProvider>(context);
    final profile = authProv.userProfile;
    final isAdmin = authProv.userRole == 'admin';

    final nombres = profile?['nombres'] ?? '';
    final apellidos = profile?['apellidos'] ?? '';
    final fullName = '$nombres $apellidos'.trim();
    final email = profile?['email'] ?? '';
    final rol = isAdmin ? 'Administrador' : 'Cliente';

    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
            decoration: const BoxDecoration(
              color: AppTheme.deepRose,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/images/logo_glamour.png',
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      child: Text(
                        fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  fullName.isNotEmpty ? fullName : 'Sin nombre',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rol,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          ListTile(
            leading: const Icon(Icons.shopping_bag_outlined, color: AppTheme.deepRose),
            title: const Text('Pedidos', style: TextStyle(fontWeight: FontWeight.w500)),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_outline, color: AppTheme.deepRose),
            title: const Text('Mi Perfil', style: TextStyle(fontWeight: FontWeight.w500)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.profile);
            },
          ),

          const Divider(),

          ListTile(
            leading: _loggingOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.red,
                    ),
                  )
                : const Icon(Icons.logout, color: Colors.red),
            title: Text(
              _loggingOut ? 'Cerrando sesión...' : 'Cerrar Sesión',
              style: TextStyle(
                color: _loggingOut ? Colors.grey : Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
            enabled: !_loggingOut,
            onTap: _loggingOut
                ? null
                : () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Cerrar Sesión'),
                        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancelar'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            child: const Text('Cerrar Sesión', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && mounted) {
                      setState(() => _loggingOut = true);
                      await authProv.logout();
                      if (mounted) {
                        Navigator.of(context, rootNavigator: true).pushReplacementNamed(AppRoutes.login);
                      }
                    }
                  },
          ),
        ],
      ),
    );
  }
}
