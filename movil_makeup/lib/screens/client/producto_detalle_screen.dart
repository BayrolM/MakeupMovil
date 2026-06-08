import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/carrito_provider.dart';
import '../../providers/producto_provider.dart';
import '../../utils/image_helper.dart';

class ProductoDetalleScreen extends StatefulWidget {
  final String productId;

  const ProductoDetalleScreen({super.key, required this.productId});

  @override
  State<ProductoDetalleScreen> createState() => _ProductoDetalleScreenState();
}

class _ProductoDetalleScreenState extends State<ProductoDetalleScreen> {
  int _cantidad = 1;
  late ProductModel _producto;
  bool _found = false;

  final formatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_found) {
      final productos = Provider.of<ProductoProvider>(context, listen: false).productos;
      try {
        _producto = productos.firstWhere((p) => p.id == widget.productId);
        _found = true;
      } catch (_) {
        _found = false;
      }
    }
  }

  void _showTopAlert(String message, {Color backgroundColor = AppTheme.deepRose}) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: backgroundColor.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Icon(backgroundColor == AppTheme.deepRose ? Icons.check_circle : Icons.info_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13))),
              ],
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), () => entry.remove());
  }

  void _addToCart() {
    final carrito = Provider.of<CarritoProvider>(context, listen: false);
    final currentQty = carrito.items[_producto.id]?.cantidad ?? 0;

    if (currentQty + _cantidad > _producto.stock) {
      _showTopAlert('Solo quedan ${_producto.stock} unidades', backgroundColor: Colors.orange);
      return;
    }

    for (var i = 0; i < _cantidad; i++) {
      carrito.agregarProducto(
        id: _producto.id,
        nombre: _producto.nombre,
        precio: _producto.precioVenta,
        maxStock: _producto.stock,
        imagenUrl: _producto.imagenUrl,
      );
    }

    _showTopAlert('¡$_cantidad x ${_producto.nombre} añadido!');
  }

  void _buyNow() {
    _addToCart();
    if (mounted) {
      Navigator.pushNamed(context, '/client-checkout');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_found) {
      return Scaffold(
        appBar: AppBar(title: const Text('Producto')),
        body: const Center(child: Text('Producto no encontrado')),
      );
    }

    final carrito = Provider.of<CarritoProvider>(context);
    final currentQty = carrito.items[_producto.id]?.cantidad ?? 0;
    final available = _producto.stock - currentQty;
    final isOutOfStock = _producto.stock <= 0;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── App Bar con imagen ──────────────────────────
          SliverAppBar(
            expandedHeight: 360,
            pinned: true,
            backgroundColor: Colors.white,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'product_image_${_producto.id}',
                    child: _producto.imagenUrl != null && _producto.imagenUrl!.isNotEmpty
                        ? Image.network(getSafeImageUrl(_producto.imagenUrl), fit: BoxFit.cover)
                        : Container(
                            color: const Color(0xFFFFF0F2),
                            child: const Icon(Icons.face_retouching_natural, size: 80, color: AppTheme.deepRose),
                          ),
                  ),
                  // Gradient overlay
                  const Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 100,
                    child: DecoratedBox(
                      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.white])),
                    ),
                  ),
                  // Badges
                  if (isOutOfStock)
                    Positioned(
                      top: 56,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)),
                        child: const Text('AGOTADO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    )
                  else if (_producto.stock <= 5)
                    Positioned(
                      top: 56,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(color: Colors.amber.shade700, borderRadius: BorderRadius.circular(20)),
                        child: Text('Últimas ${_producto.stock} unidades', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Contenido ──────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Marca + nombre
                  Text(
                    _producto.marca.toUpperCase(),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1),
                  ),
                  const SizedBox(height: 4),
                  Hero(
                    tag: 'product_name_${_producto.id}',
                    child: Material(
                      color: Colors.transparent,
                      child: Text(
                        _producto.nombre,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D), height: 1.2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Precio
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.deepRose.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      formatter.format(_producto.precioVenta),
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppTheme.deepRose),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Descripción
                  if (_producto.descripcion.isNotEmpty) ...[
                    Text('Descripción', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                    const SizedBox(height: 8),
                    Text(
                      _producto.descripcion,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.6),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Selector de cantidad
                  if (!isOutOfStock) ...[
                    Text('Cantidad', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildQtyButton(
                          icon: Icons.remove,
                          onTap: _cantidad > 1 ? () => setState(() => _cantidad--) : null,
                        ),
                        Container(
                          width: 56,
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '$_cantidad',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                        _buildQtyButton(
                          icon: Icons.add,
                          onTap: _cantidad < available ? () => setState(() => _cantidad++) : null,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$available disponibles',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Total
                  if (!isOutOfStock) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                          Text(
                            formatter.format(_producto.precioVenta * _cantidad),
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.deepRose),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Botones fijos abajo ────────────────────────────
      bottomSheet: isOutOfStock
          ? Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              color: Colors.white,
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade300, disabledBackgroundColor: Colors.grey.shade300, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                  child: const Text('AGOTADO', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            )
          : Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              color: Colors.white,
              child: Row(
                children: [
                  // Añadir al carrito
                  Expanded(
                    flex: 4,
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _addToCart,
                        icon: const Icon(Icons.add_shopping_cart, size: 20),
                        label: const Text('Añadir', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.deepRose,
                          side: const BorderSide(color: AppTheme.deepRose, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Comprar ahora
                  Expanded(
                    flex: 5,
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _buyNow,
                        icon: const Icon(Icons.flash_on, size: 20),
                        label: const Text('Comprar ahora', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.deepRose,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildQtyButton({required IconData icon, VoidCallback? onTap}) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: enabled ? AppTheme.deepRose.withOpacity(0.1) : Colors.grey.shade100,
          shape: BoxShape.circle,
          border: Border.all(color: enabled ? AppTheme.deepRose.withOpacity(0.3) : Colors.grey.shade300),
        ),
        child: Icon(icon, size: 20, color: enabled ? AppTheme.deepRose : Colors.grey.shade400),
      ),
    );
  }
}
