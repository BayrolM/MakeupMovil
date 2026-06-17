import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/carrito_provider.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../data/colombia_data.dart';
import '../../utils/image_helper.dart';

class ClienteCheckoutScreen extends StatefulWidget {
  const ClienteCheckoutScreen({super.key});

  @override
  State<ClienteCheckoutScreen> createState() => _ClienteCheckoutScreenState();
}

class _ClienteCheckoutScreenState extends State<ClienteCheckoutScreen> {
  late TextEditingController _direccionController;
  String? _departamentoSeleccionado;
  String? _ciudadSeleccionada;
  bool _validandoStock = false;

  @override
  void initState() {
    super.initState();
    final profile = Provider.of<AuthProvider>(context, listen: false).userProfile;
    _direccionController = TextEditingController(text: profile?['direccion'] ?? '');
    final dept = profile?['departamento'] ?? '';
    final ciud = profile?['ciudad'] ?? '';
    _departamentoSeleccionado = dept.isNotEmpty && colombianDepartments.contains(dept) ? dept : null;
    if (_departamentoSeleccionado != null && ciud.isNotEmpty && mainCities[_departamentoSeleccionado]?.contains(ciud) == true) {
      _ciudadSeleccionada = ciud;
    } else {
      _ciudadSeleccionada = null;
    }
  }

  @override
  void dispose() {
    _direccionController.dispose();
    super.dispose();
  }

  Future<void> _validarStockYpagar(CarritoProvider carritoProv) async {
    setState(() => _validandoStock = true);

    try {
      final List<Map<String, dynamic>> productosSinStock = [];

      for (final item in carritoProv.items.values) {
        final response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/products/${item.id}'),
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final stockActual = data['data']['stock_actual'] ?? 0;
          if (stockActual <= 0) {
            productosSinStock.add({'nombre': item.nombre, 'stock': stockActual});
          } else if (item.cantidad > stockActual) {
            productosSinStock.add({'nombre': item.nombre, 'stock': stockActual});
            carritoProv.setCantidad(item.id, stockActual);
          }
        }
      }

      if (!mounted) return;

      if (productosSinStock.isNotEmpty) {
        final stockMsg = productosSinStock
            .map((p) => '${p['nombre']}: ${p['stock']} disp.')
            .join('\n');
        _showTopAlert('Sin stock o insuficiente:\n$stockMsg');
        return;
      }

      Navigator.pushNamed(
        context,
        AppRoutes.clientePago,
        arguments: {
          'direccion': _direccionController.text.trim(),
          'ciudad': _ciudadSeleccionada ?? '',
          'departamento': _departamentoSeleccionado ?? '',
        },
      );
    } catch (e) {
      if (mounted) _showTopAlert('Error al validar stock. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _validandoStock = false);
    }
  }

  void _showTopAlert(String message) {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red.shade700,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), () {
      entry.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    final carritoProv = Provider.of<CarritoProvider>(context);
    final formatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Resumen del Pedido"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: carritoProv.items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 72, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text("Tu carrito está vacío", style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("VOLVER"),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Dirección de envío editable
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.edit_location_alt_outlined, color: AppTheme.deepRose, size: 20),
                              SizedBox(width: 8),
                              Text("Dirección de Envío", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Puedes editarla antes de confirmar",
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _direccionController,
                            maxLength: 30,
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            decoration: const InputDecoration(
                              labelText: "Dirección *",
                              counterText: "",
                              isDense: true,
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'La dirección es obligatoria';
                              if (val.trim().length < 3) return 'Mínimo 3 caracteres';
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _departamentoSeleccionado,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: "Departamento *",
                                    counterText: "",
                                    isDense: true,
                                  ),
                                  items: colombianDepartments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                                  onChanged: (v) {
                                    setState(() {
                                      _departamentoSeleccionado = v;
                                      _ciudadSeleccionada = null;
                                    });
                                  },
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Requerido';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _ciudadSeleccionada,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: "Ciudad *",
                                    counterText: "",
                                    isDense: true,
                                  ),
                                  items: _departamentoSeleccionado != null && mainCities[_departamentoSeleccionado]!.isNotEmpty
                                      ? mainCities[_departamentoSeleccionado]!.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList()
                                      : [],
                                  onChanged: _departamentoSeleccionado == null
                                      ? null
                                      : (v) => setState(() => _ciudadSeleccionada = v),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Requerida';
                                    return null;
                                  },
                                  disabledHint: const Text('Selecciona depto.'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Productos
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.shopping_bag_outlined, color: AppTheme.deepRose, size: 20),
                              SizedBox(width: 8),
                              Text("Productos", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...carritoProv.items.values.map((item) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: item.imagenUrl != null && item.imagenUrl!.isNotEmpty
                                          ? Image.network(
                                              getSafeImageUrl(item.imagenUrl),
                                              width: 48,
                                              height: 48,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => Container(
                                                width: 48,
                                                height: 48,
                                                color: Colors.grey.shade200,
                                                child: const Icon(Icons.broken_image, size: 20, color: Colors.grey),
                                              ),
                                            )
                                          : Container(
                                              width: 48,
                                              height: 48,
                                              color: const Color(0xFFFFF0F2),
                                              child: const Icon(Icons.face_retouching_natural, size: 24, color: AppTheme.deepRose),
                                            ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          Text(
                                            '${item.cantidad} x ${formatter.format(item.precio)}',
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      formatter.format(item.precio * item.cantidad),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ],
                                ),
                              )),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Envío", style: TextStyle(fontSize: 14, color: Colors.grey)),
                              Text(
                                "Calculando",
                                style: TextStyle(fontSize: 14, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Total", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              Text(
                                formatter.format(carritoProv.totalAmount),
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.deepRose),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Botón pagar
                  ElevatedButton(
                    onPressed: _direccionController.text.trim().isEmpty ||
                            _ciudadSeleccionada == null ||
                            _departamentoSeleccionado == null ||
                            _validandoStock
                        ? null
                        : () => _validarStockYpagar(carritoProv),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      disabledBackgroundColor: Colors.grey.shade300,
                    ),
                    child: _validandoStock
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text("PAGAR", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
