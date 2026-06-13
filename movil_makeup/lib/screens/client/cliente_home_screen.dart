import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/producto_provider.dart';
import '../../providers/carrito_provider.dart';
import '../../providers/pedido_provider.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../utils/image_helper.dart';
import '../../widgets/banner_carousel.dart';
import '../../utils/pdf_generator.dart';
import 'devolucion_solicitud_screen.dart';

class ClienteHomeScreen extends StatefulWidget {
  const ClienteHomeScreen({super.key});

  @override
  State<ClienteHomeScreen> createState() => _ClienteHomeScreenState();
}

class _ClienteHomeScreenState extends State<ClienteHomeScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  String _searchQuery = '';
  String? _selectedCategoryId;

  final _searchController = TextEditingController();
  final GlobalKey _cartIconKey = GlobalKey();

  void _showTopAlert(String message, {Color backgroundColor = Colors.orange}) {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: AnimatedOpacity(
            opacity: 1.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), () {
      entry.remove();
    });
  }

  AnimationController? _navAnimController;

  @override
  void initState() {
    super.initState();
    _navAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _navAnimController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadInitialData() {
    final productProv = Provider.of<ProductoProvider>(context, listen: false);
    productProv.cargarProductos();
    productProv.cargarCategorias();

    final authProv = Provider.of<AuthProvider>(context, listen: false);
    if (authProv.isLoggedIn) {
      Provider.of<PedidoProvider>(context, listen: false).cargarPedidosCliente(authProv.token!);
    }
  }

  void _onTabChanged(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    _navAnimController?.forward(from: 0.0);
    if (index == 1) {
      final productProv = Provider.of<ProductoProvider>(context, listen: false);
      productProv.cargarProductos(search: _searchQuery, categoryId: _selectedCategoryId);
    } else if (index == 2) {
      final authProv = Provider.of<AuthProvider>(context, listen: false);
      if (authProv.isLoggedIn) {
        Provider.of<PedidoProvider>(context, listen: false).cargarPedidosCliente(authProv.token!);
      }
    }
  }

  void _cerrarSesion() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: AppTheme.deepRose, size: 28),
            SizedBox(width: 8),
            Text("Cerrar Sesión", style: TextStyle(color: AppTheme.deepRose, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text("¿Estás seguro que deseas cerrar sesión?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("CANCELAR"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.deepRose),
            child: const Text("CERRAR SESIÓN"),
          ),
        ],
      ),
    );

    if (confirmado == true && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.deepRose)),
                  SizedBox(height: 16),
                  Text("Cerrando sesión...", style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
      );

      await Provider.of<AuthProvider>(context, listen: false).logout();

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
      }
    }
  }

  final formatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  void _showCartPopup(CarritoProvider carritoProv) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final items = carritoProv.items.values.toList();
            return DraggableScrollableSheet(
              initialChildSize: 0.55,
              minChildSize: 0.3,
              maxChildSize: 0.85,
              expand: false,
              builder: (ctx, scrollController) {
                return Column(
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.shopping_cart_outlined, color: AppTheme.deepRose, size: 22),
                          const SizedBox(width: 8),
                          const Text(
                            'Mi Carrito',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.deepRose),
                          ),
                          const Spacer(),
                          Text(
                            '${carritoProv.totalQuantity} items',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Items
                    Expanded(
                      child: items.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.shopping_cart_outlined, size: 56, color: Colors.grey.shade300),
                                  const SizedBox(height: 12),
                                  const Text('Tu carrito está vacío', style: TextStyle(color: Colors.grey, fontSize: 15)),
                                  const SizedBox(height: 4),
                                  const Text('¡Agrega productos del catálogo!', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: items.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (ctx, index) {
                                final item = items[index];
                                final qtyController = TextEditingController(text: item.cantidad.toString());
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    children: [
                                      // Imagen
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: item.imagenUrl != null && item.imagenUrl!.isNotEmpty
                                            ? Image.network(
                                                getSafeImageUrl(item.imagenUrl),
                                                width: 44,
                                                height: 44,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                                              )
                                            : _buildPlaceholderImage(),
                                      ),
                                      const SizedBox(width: 10),
                                      // Nombre + precio unitario
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.nombre,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${formatter.format(item.precio)} c/u',
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                            ),
                                            Text(
                                              formatter.format(item.precio * item.cantidad),
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.deepRose),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Controles de cantidad
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _qtyButton(
                                            icon: Icons.remove,
                                            onTap: () {
                                              carritoProv.removerUno(item.id);
                                              setModalState(() {});
                                            },
                                          ),
                                          SizedBox(
                                            width: 38,
                                            height: 30,
                                            child: TextField(
                                              controller: qtyController,
                                              textAlign: TextAlign.center,
                                              keyboardType: TextInputType.number,
                                              inputFormatters: [
                                                FilteringTextInputFormatter.digitsOnly,
                                              ],
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                              decoration: InputDecoration(
                                                contentPadding: const EdgeInsets.symmetric(vertical: 2),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(6),
                                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(6),
                                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                                ),
                                              ),
                                              onChanged: (val) {
                                                final parsed = int.tryParse(val);
                                                if (parsed == null) return;
                                                if (parsed > item.maxStock) {
                                                  qtyController.text = item.maxStock.toString();
                                                  qtyController.selection = TextSelection.fromPosition(
                                                    TextPosition(offset: item.maxStock.toString().length),
                                                  );
                                                  carritoProv.setCantidad(item.id, item.maxStock);
                                                  setModalState(() {});
                                                  _showTopAlert('Stock máximo disponible: ${item.maxStock} unidades');
                                                } else if (parsed > 0) {
                                                  carritoProv.setCantidad(item.id, parsed);
                                                  setModalState(() {});
                                                }
                                              },
                                              onSubmitted: (val) {
                                                final newQty = int.tryParse(val);
                                                if (newQty == null || newQty <= 0) {
                                                  carritoProv.eliminarItem(item.id);
                                                  setModalState(() {});
                                                  return;
                                                }
                                                if (newQty > item.maxStock) {
                                                  qtyController.text = item.maxStock.toString();
                                                  qtyController.selection = TextSelection.fromPosition(
                                                    TextPosition(offset: item.maxStock.toString().length),
                                                  );
                                                  carritoProv.setCantidad(item.id, item.maxStock);
                                                  setModalState(() {});
                                                  _showTopAlert('Stock máximo disponible: ${item.maxStock} unidades');
                                                  return;
                                                }
                                                carritoProv.setCantidad(item.id, newQty);
                                                setModalState(() {});
                                              },
                                            ),
                                          ),
                                          _qtyButton(
                                            icon: Icons.add,
                                            onTap: () {
                                              final ok = carritoProv.agregarUno(item.id);
                                              setModalState(() {});
                                              if (!ok) {
                                                _showTopAlert('Stock máximo: ${item.maxStock} unidades');
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 6),
                                      // Eliminar
                                      GestureDetector(
                                        onTap: () {
                                          carritoProv.eliminarItem(item.id);
                                          setModalState(() {});
                                        },
                                        child: Icon(Icons.delete_outline, size: 20, color: Colors.grey.shade400),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    // Total + Botón pagar
                    if (items.isNotEmpty) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(
                              formatter.format(carritoProv.totalAmount),
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppTheme.deepRose),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              final authProv = Provider.of<AuthProvider>(context, listen: false);
                              if (authProv.isLoggedIn) {
                                Navigator.pushNamed(context, AppRoutes.clienteCheckout);
                              } else {
                                Navigator.pushNamed(context, AppRoutes.login);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.deepRose,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            child: const Text('IR A PAGAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 44,
      height: 44,
      color: const Color(0xFFFFF0F2),
      child: const Icon(Icons.face_retouching_natural, size: 22, color: AppTheme.deepRose),
    );
  }

  Widget _qtyButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: AppTheme.deepRose.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: AppTheme.deepRose),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final carritoProv = Provider.of<CarritoProvider>(context);
    final authProv = Provider.of<AuthProvider>(context);
    final isLoggedIn = authProv.isLoggedIn;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'images/logo_glamour.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.auto_awesome, color: AppTheme.deepRose, size: 28),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              "Glamour ML",
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ],
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: isLoggedIn ? 'Mi Perfil' : 'Iniciar sesión',
            onPressed: () {
              if (isLoggedIn) {
                Navigator.pushNamed(context, AppRoutes.profile);
              } else {
                Navigator.pushNamed(context, AppRoutes.login);
              }
            },
          ),
          IconButton(
            key: _cartIconKey,
            icon: Badge(
              isLabelVisible: carritoProv.totalQuantity > 0,
              backgroundColor: AppTheme.deepRose,
              offset: const Offset(-2, -2),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            tooltip: 'Mi Carrito',
            onPressed: () => _showCartPopup(carritoProv),
          ),
          if (isLoggedIn)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Cerrar sesión',
              onPressed: () => _cerrarSesion(),
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.05, 0.0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: _buildCurrentTab(),
      ),
      bottomNavigationBar: _buildAnimatedNavBar(carritoProv),
    );
  }

  Widget _buildAnimatedNavBar(CarritoProvider carritoProv) {
    final items = [
      _NavItemData(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Inicio'),
      _NavItemData(icon: Icons.auto_awesome_mosaic, activeIcon: Icons.auto_awesome_mosaic, label: 'Catálogo'),
      _NavItemData(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, label: 'Pedidos'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 62,
          child: Row(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = _currentIndex == index;

              return Expanded(
                child: GestureDetector(
                  onTap: () => _onTabChanged(index),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOutCubic,
                          padding: EdgeInsets.symmetric(
                            horizontal: isSelected ? 16 : 0,
                            vertical: isSelected ? 4 : 0,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.deepRose.withOpacity(0.1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            isSelected ? item.activeIcon : item.icon,
                            color: isSelected ? AppTheme.deepRose : Colors.grey,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 2),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppTheme.deepRose : Colors.grey,
                          ),
                          child: Text(item.label),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return _buildCatalogTab();
      case 2:
        return _buildOrdersTab();
      default:
        return _buildHomeTab();
    }
  }

  // ==========================================
  // TAB 0: INICIO
  // ==========================================
  Widget _buildHomeTab() {
    final productProv = Provider.of<ProductoProvider>(context);

    return SingleChildScrollView(
      key: const ValueKey('home'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Carrusel de banners
          const BannerCarousel(),

          // Categorías rápidas
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Text(
              "Categorías",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
            ),
          ),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: productProv.categorias.length,
              itemBuilder: (context, index) {
                final cat = productProv.categorias[index];
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedCategoryId = cat.id);
                    _onTabChanged(1);
                  },
                  child: Container(
                    width: 110,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.deepRose.withValues(alpha: 0.08),
                          AppTheme.deepRose.withValues(alpha: 0.15),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.deepRose.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.deepRose.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.sell, color: AppTheme.deepRose, size: 22),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            cat.nombre,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Productos destacados
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                   "Productos",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                ),
                TextButton(
                  onPressed: () => _onTabChanged(1),
                  child: const Text("Ver todo", style: TextStyle(color: AppTheme.deepRose)),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 240,
            child: productProv.isLoading
                ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.deepRose)))
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: productProv.productosDisponibles.length > 6 ? 6 : productProv.productosDisponibles.length,
                    itemBuilder: (context, index) {
                      final prod = productProv.productosDisponibles[index];
                      return _buildFeaturedProductCard(prod);
                    },
                  ),
          ),
          const SizedBox(height: 20),

          // ── Beneficios / Trust Badges ─────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildBenefitItem(Icons.local_shipping_outlined, 'Envío seguro', 'Entrega confiable'),
                _buildBenefitItem(Icons.shield_outlined, 'Pago seguro', 'Transferencia bancaria'),
                _buildBenefitItem(Icons.replay_30_outlined, 'Devolución', '30 días'),
                _buildBenefitItem(Icons.headset_mic_outlined, 'Soporte flexible', 'Chatea con nos.'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Métodos de pago ────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Métodos de pago', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Aceptamos transferencia bancaria Nequi, Daviplata y Bancolombia.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildPaymentBadge(Icons.account_balance, 'Nequi'),
                    _buildPaymentBadge(Icons.account_balance_wallet, 'Bancolombia'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Contáctanos ───────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppTheme.deepRose.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.support_agent, color: AppTheme.deepRose, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('¿Necesitas ayuda?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Escríbenos y te respondemos lo antes posible.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500, height: 1.4)),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: const Text('Contáctanos'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Escríbenos a:', style: TextStyle(fontSize: 13)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                              child: const Text('soporte@glamourml.com', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.deepRose)),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cerrar'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppTheme.deepRose,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.email_outlined, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Enviar correo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Footer / Info de la marca ──────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset('images/logo_glamour.png', width: 28, height: 28, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.auto_awesome, color: AppTheme.deepRose, size: 24)),
                    ),
                    const SizedBox(width: 8),
                    const Text('Glamour ML', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Tu tienda de belleza y cuidado personal de confianza.', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                const SizedBox(height: 20),

                // Links
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildFooterLink(Icons.help_outline, 'Ayuda'),
                    _buildFooterLink(Icons.description_outlined, 'Términos'),
                    _buildFooterLink(Icons.privacy_tip_outlined, 'Privacidad'),
                    _buildFooterLink(Icons.info_outline, 'Nosotros'),
                  ],
                ),
                const SizedBox(height: 20),
                Divider(color: Colors.grey.shade800, height: 1),
                const SizedBox(height: 16),

                // Redes sociales
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  _buildSocialIcon(Icons.facebook),
                  _buildSocialIcon(Icons.camera_alt_outlined),
                  _buildSocialIcon(Icons.music_note_outlined),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text('© 2026 Glamour ML. Todos los derechos reservados.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 10)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String title, String subtitle) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.deepRose.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: AppTheme.deepRose),
          ),
          const SizedBox(height: 6),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 8, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildFooterLink(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey.shade400, size: 20),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
      ],
    );
  }

  Widget _buildSocialIcon(IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.grey.shade400, size: 18),
    );
  }

  Widget _buildPaymentBadge(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.deepRose.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22, color: AppTheme.deepRose),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
      ],
    );
  }

  Widget _buildFeaturedProductCard(ProductModel prod) {
    final carritoProv = Provider.of<CarritoProvider>(context);

    return GestureDetector(
      onTap: () => Navigator.push(context, AppRoutes.productoDetalleRoute(prod.id)),
      child: Container(
      width: 160,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: prod.imagenUrl != null && prod.imagenUrl!.isNotEmpty
                        ? Image.network(
                            getSafeImageUrl(prod.imagenUrl),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image, color: Colors.grey)),
                          )
                        : Container(
                            color: const Color(0xFFFFF0F2),
                            child: const Icon(Icons.face_retouching_natural, size: 40, color: AppTheme.deepRose),
                          ),
                  ),
                  if (prod.stock <= 0)
                    Container(
                      color: Colors.black.withOpacity(0.6),
                      alignment: Alignment.center,
                      child: const Text("AGOTADO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prod.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatter.format(prod.precioVenta),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.deepRose),
                      ),
                      GestureDetector(
                        onTap: prod.stock <= 0 || (carritoProv.items[prod.id]?.cantidad ?? 0) >= prod.stock
                            ? null
                            : () {
                                final ok = carritoProv.agregarProducto(
                                  id: prod.id,
                                  nombre: prod.nombre,
                                  precio: prod.precioVenta,
                                  maxStock: prod.stock,
                                  imagenUrl: prod.imagenUrl,
                                );
                                _showTopAlert(
                                  ok ? '¡${prod.nombre} añadido!' : 'Stock máximo: ${prod.stock} unidades',
                                  backgroundColor: ok ? AppTheme.deepRose : Colors.orange,
                                );
                              },
                        child: Icon(
                          Icons.add_shopping_cart,
                          size: 18,
                          color: prod.stock <= 0 || (carritoProv.items[prod.id]?.cantidad ?? 0) >= prod.stock
                              ? Colors.grey
                              : AppTheme.deepRose,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  // ==========================================
  // TAB 1: CATALOGO
  // ==========================================
  Widget _buildCatalogTab() {
    final productProv = Provider.of<ProductoProvider>(context);

    return Column(
      key: const ValueKey('catalog'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() => _searchQuery = val);
              productProv.cargarProductos(search: val, categoryId: _selectedCategoryId);
            },
            decoration: InputDecoration(
              hintText: "Buscar labiales, bases, sombras...",
              prefixIcon: const Icon(Icons.search, color: AppTheme.deepRose),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                        productProv.cargarProductos(categoryId: _selectedCategoryId);
                      },
                    )
                  : null,
            ),
          ),
        ),
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            itemCount: productProv.categorias.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                final isSelected = _selectedCategoryId == null;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ChoiceChip(
                    label: const Text("Todos"),
                    selected: isSelected,
                    selectedColor: AppTheme.deepRose,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade700),
                    onSelected: (_) {
                      setState(() => _selectedCategoryId = null);
                      productProv.cargarProductos(search: _searchQuery);
                    },
                  ),
                );
              }
              final cat = productProv.categorias[index - 1];
              final isSelected = _selectedCategoryId == cat.id;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ChoiceChip(
                  label: Text(cat.nombre),
                  selected: isSelected,
                  selectedColor: AppTheme.deepRose,
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade700),
                  onSelected: (_) {
                    setState(() => _selectedCategoryId = cat.id);
                    productProv.cargarProductos(search: _searchQuery, categoryId: cat.id);
                  },
                ),
              );
            },
          ),
        ),
        Expanded(
          child: productProv.isLoading
              ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.deepRose)))
              : productProv.productosDisponibles.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sentiment_dissatisfied, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text("No se encontraron productos", style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16.0),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.70,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: productProv.productosDisponibles.length,
                      itemBuilder: (context, index) {
                        return _buildProductCard(productProv.productosDisponibles[index]);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildProductCard(ProductModel prod) {
    final carritoProv = Provider.of<CarritoProvider>(context);

    return GestureDetector(
      onTap: () => Navigator.push(context, AppRoutes.productoDetalleRoute(prod.id)),
      child: Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: prod.imagenUrl != null && prod.imagenUrl!.isNotEmpty
                      ? Image.network(
                          getSafeImageUrl(prod.imagenUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image, color: Colors.grey)),
                        )
                      : Container(
                          color: const Color(0xFFFFF0F2),
                          child: const Icon(Icons.face_retouching_natural, size: 50, color: AppTheme.deepRose),
                        ),
                ),
                if (prod.stock <= 0)
                  Container(
                    color: Colors.black.withOpacity(0.6),
                    alignment: Alignment.center,
                    child: const Text("AGOTADO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  )
                else if (prod.stock <= 5)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "Últimas ${prod.stock}",
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prod.marca.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 0.5),
                ),
                const SizedBox(height: 2),
                Text(
                  prod.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formatter.format(prod.precioVenta),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.deepRose),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.add_shopping_cart,
                        size: 20,
                        color: prod.stock <= 0 || (carritoProv.items[prod.id]?.cantidad ?? 0) >= prod.stock
                            ? Colors.grey
                            : AppTheme.deepRose,
                      ),
                      onPressed: prod.stock <= 0 || (carritoProv.items[prod.id]?.cantidad ?? 0) >= prod.stock
                          ? null
                          : () {
                                final ok = carritoProv.agregarProducto(
                                  id: prod.id,
                                  nombre: prod.nombre,
                                  precio: prod.precioVenta,
                                  maxStock: prod.stock,
                                  imagenUrl: prod.imagenUrl,
                                );
                                _showTopAlert(
                                  ok ? '¡${prod.nombre} añadido a tu bolsa!' : 'Stock máximo: ${prod.stock} unidades',
                                  backgroundColor: ok ? AppTheme.deepRose : Colors.orange,
                                );
                            },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  // ==========================================
  // TAB 2: PEDIDOS
  // ==========================================
  Widget _buildOrdersTab() {
    final authProv = Provider.of<AuthProvider>(context);
    final pedidoProv = Provider.of<PedidoProvider>(context);

    if (!authProv.isLoggedIn) {
      return Center(
        key: const ValueKey('orders-login'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text("Debes iniciar sesión para ver tus pedidos", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
              child: const Text("INICIAR SESIÓN"),
            ),
          ],
        ),
      );
    }

    if (pedidoProv.isLoading) {
      return const Center(key: ValueKey('orders-loading'), child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.deepRose)));
    }

    if (pedidoProv.pedidos.isEmpty) {
      return Center(
        key: const ValueKey('orders-empty'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text("Aún no tienes pedidos registrados", style: TextStyle(fontSize: 18, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      key: const ValueKey('orders-list'),
      padding: const EdgeInsets.all(16.0),
      itemCount: pedidoProv.pedidos.length,
      itemBuilder: (context, index) {
        final order = pedidoProv.pedidos[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ExpansionTile(
            title: Text("Pedido #${order.id}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Text("${order.fecha.substring(0, 10)}  •  ${formatter.format(order.total)}", style: const TextStyle(color: Colors.grey)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildStatusChip(order),
                    if (order.estadoDevolucion != null) ...[
                      const SizedBox(height: 3),
                      _buildDevolucionBadge(order.estadoDevolucion!),
                    ],
                  ],
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf, size: 20, color: Colors.red),
                  tooltip: 'Descargar PDF',
                  onPressed: () => PdfGenerator.generarPdfPedido(order, context),
                ),
              ],
            ),
            onExpansionChanged: (expanded) {
              if (expanded && order.items.isEmpty) {
                Provider.of<PedidoProvider>(context, listen: false).cargarDetallePedido(authProv.token!, order.id);
              }
            },
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Dirección de Entrega:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text("${order.direccion}, ${order.ciudad} (${order.departamento ?? ''})"),
                    if (order.estado.toLowerCase() == 'enviado' || order.estado.toLowerCase() == 'entregado') ...[
                      const SizedBox(height: 8),
                      const Text("Datos de Envío:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      if (order.transportadora != null && order.transportadora!.isNotEmpty)
                        Text("Transportadora: ${order.transportadora}", style: const TextStyle(fontSize: 13)),
                      if (order.numeroGuia != null && order.numeroGuia!.isNotEmpty)
                        Text("Guía: ${order.numeroGuia}", style: const TextStyle(fontSize: 13)),
                      if (order.fechaEnvio != null && order.fechaEnvio!.isNotEmpty)
                        Text("Fecha envío: ${_formatDate(order.fechaEnvio!)}", style: const TextStyle(fontSize: 13)),
                      if (order.fechaEstimada != null && order.fechaEstimada!.isNotEmpty)
                        Text("Llegada estimada: ${_formatDate(order.fechaEstimada!)}", style: const TextStyle(fontSize: 13)),
                    ],
                    const SizedBox(height: 8),
                    const Text("Método de Pago:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(order.metodoPago.toUpperCase()),
                    if (order.estado.toLowerCase() == 'pendiente' && order.comprobanteUrl != null && order.comprobanteUrl!.isNotEmpty && !order.pagoConfirmado) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blueGrey, width: 1),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.hourglass_top, color: Colors.blueGrey, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Tu comprobante está siendo verificado por nuestro equipo.",
                                style: TextStyle(color: Colors.blueGrey, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    const Text("Detalle de Productos:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ...order.items.map((it) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("${it.cantidad}x ${it.nombreProducto}", style: const TextStyle(fontSize: 13)),
                              Text(formatter.format(it.subtotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        )),

                    // ── Sección de Devolución ──────────────
                    if (order.devolucionInfo != null) ...[
                      const SizedBox(height: 12),
                      _buildDevolucionDetail(order.devolucionInfo!),
                    ],

                    // ── Botón Solicitar Devolución ─────────
                    if (order.estado.toLowerCase() == 'entregado' && order.estadoDevolucion == null) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DevolucionSolicitudScreen(pedido: order),
                              ),
                            );
                          },
                          icon: const Icon(Icons.replay_outlined, size: 18),
                          label: const Text('Solicitar Devolución', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.deepRose,
                            side: const BorderSide(color: AppTheme.deepRose, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(OrderModel order) {
    final estado = order.estado.toLowerCase();
    Color chipColor = Colors.orange;
    String label = order.estado.toUpperCase();

    if (estado == 'pendiente' && order.comprobanteUrl != null && order.comprobanteUrl!.isNotEmpty && !order.pagoConfirmado) {
      chipColor = Colors.blueGrey;
      label = 'VERIFICANDO PAGO';
    } else {
      switch (estado) {
        case 'pendiente':
          chipColor = Colors.orange;
          break;
        case 'preparado':
          chipColor = Colors.blue;
          break;
        case 'procesando':
          chipColor = Colors.teal;
          break;
        case 'enviado':
          chipColor = Colors.purple;
          break;
        case 'entregado':
          chipColor = Colors.green;
          break;
        case 'cancelado':
          chipColor = Colors.red;
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(color: chipColor, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDevolucionBadge(String estado) {
    Color chipColor;
    String label;

    switch (estado) {
      case 'pendiente':
        chipColor = Colors.orange;
        label = 'DEVOLUCIÓN';
        break;
      case 'en_revision':
        chipColor = Colors.amber;
        label = 'EN REVISIÓN';
        break;
      case 'aprobada':
        chipColor = Colors.green;
        label = 'DEVOLUCIÓN ACEPTADA';
        break;
      case 'rechazada':
        chipColor = Colors.red;
        label = 'DEVOLUCIÓN RECHAZADA';
        break;
      default:
        chipColor = Colors.grey;
        label = 'DEVOLUCIÓN';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: chipColor, width: 1),
      ),
      child: Text(label, style: TextStyle(color: chipColor, fontSize: 8, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDevolucionDetail(Map<String, dynamic> info) {
    final estado = info['estado'] ?? 'pendiente';
    final motivo = info['motivo'] ?? '';
    final motivoDecision = info['motivo_decision'];
    final totalDevuelto = double.tryParse(info['total_devuelto']?.toString() ?? '') ?? 0.0;

    Color estadoColor;
    String estadoLabel;

    switch (estado) {
      case 'pendiente':
        estadoColor = Colors.orange;
        estadoLabel = 'Pendiente';
        break;
      case 'en_revision':
        estadoColor = Colors.amber;
        estadoLabel = 'En Revisión';
        break;
      case 'aprobada':
        estadoColor = Colors.green;
        estadoLabel = 'Aprobada';
        break;
      case 'rechazada':
        estadoColor = Colors.red;
        estadoLabel = 'Rechazada';
        break;
      default:
        estadoColor = Colors.grey;
        estadoLabel = estado;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.replay_outlined, size: 16, color: AppTheme.deepRose),
              const SizedBox(width: 6),
              const Text('Devolución', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: estadoColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(estadoLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: estadoColor)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Motivo: $motivo', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      const months = [
        '', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
        'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
      ];
      return '${date.day} de ${months[date.month]} ${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}

class _NavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  _NavItemData({required this.icon, required this.activeIcon, required this.label});
}
