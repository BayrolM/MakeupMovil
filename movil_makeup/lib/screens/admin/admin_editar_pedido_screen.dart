import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../../providers/auth_provider.dart';
import '../../providers/producto_provider.dart';
import '../../providers/pedido_provider.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';

class AdminEditarPedidoScreen extends StatefulWidget {
  final String orderId;

  const AdminEditarPedidoScreen({super.key, required this.orderId});

  @override
  State<AdminEditarPedidoScreen> createState() => _AdminEditarPedidoScreenState();
}

class _AdminEditarPedidoScreenState extends State<AdminEditarPedidoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _direccionController = TextEditingController();
  final _ciudadController = TextEditingController();
  final _departamentoController = TextEditingController();
  final _cantidadController = TextEditingController(text: '1');

  OrderModel? _order;
  bool _loading = true;
  bool _saving = false;

  List<_ClientOption> _clientes = [];
  _ClientOption? _selectedCliente;
  bool _loadingClientes = false;

  ProductModel? _selectedProduct;
  final List<Map<String, dynamic>> _addedItems = [];
  double _grandTotal = 0.0;

  bool get _canEditFields => _order != null && ['pendiente', 'preparado', 'procesando'].contains(_order!.estado.toLowerCase());
  bool get _canEditItems => _order != null && _order!.estado.toLowerCase() == 'pendiente';
  bool get _canEditClient => _order != null && _order!.estado.toLowerCase() == 'pendiente';

  final currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrder();
    });
  }

  Future<void> _loadOrder() async {
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final pedidoProv = Provider.of<PedidoProvider>(context, listen: false);

    await pedidoProv.cargarDetallePedido(authProv.token!, widget.orderId);

    final found = pedidoProv.pedidos.firstWhere(
      (p) => p.id == widget.orderId,
      orElse: () => pedidoProv.pedidos.first,
    );

    if (mounted) {
      setState(() {
        _order = found;
        _direccionController.text = found.direccion;
        _ciudadController.text = found.ciudad;
        _departamentoController.text = found.departamento ?? '';
        for (var item in found.items) {
          _addedItems.add({
            'id_producto': int.parse(item.idProducto),
            'nombre': item.nombreProducto,
            'precio_unitario': item.precioUnitario,
            'cantidad': item.cantidad,
            'subtotal': item.subtotal,
          });
        }
        _grandTotal = found.total;
        _loading = false;
      });
    }

    if (_canEditClient) {
      _fetchClientes();
    }
  }

  Future<void> _fetchClientes() async {
    setState(() => _loadingClientes = true);

    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final token = authProv.token;

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/users?limit=200&estado=true'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> list = data['data'] ?? [];
        if (mounted) {
          setState(() {
            _clientes = list.map((json) => _ClientOption.fromJson(json)).toList();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        _showToast('Error al cargar la lista de clientes', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingClientes = false);
      }
    }
  }

  void _showToast(String message, {bool isError = false}) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16.0,
        left: 16.0,
        right: 16.0,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 250),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, (1 - value) * -15),
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
              decoration: BoxDecoration(
                color: isError ? const Color(0xFFC62828) : AppTheme.deepRose,
                borderRadius: BorderRadius.circular(12.0),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 8.0, offset: Offset(0, 3)),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    isError ? Icons.error_outline : Icons.check_circle_outline,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(milliseconds: 2800), () {
      overlayEntry.remove();
    });
  }

  void _calculateGrandTotal() {
    double total = 0.0;
    for (var it in _addedItems) {
      total += it['subtotal'];
    }
    setState(() => _grandTotal = total);
  }

  void _addItem() {
    if (_selectedProduct == null) {
      _showToast('Por favor selecciona un producto', isError: true);
      return;
    }

    final int cant = int.tryParse(_cantidadController.text) ?? 1;
    if (cant <= 0) {
      _showToast('La cantidad debe ser mayor a 0', isError: true);
      return;
    }

    if (cant > _selectedProduct!.stock) {
      _showToast('Stock insuficiente para este producto', isError: true);
      return;
    }

    final existingIndex = _addedItems.indexWhere(
      (it) => it['id_producto'].toString() == _selectedProduct!.id,
    );

    if (existingIndex != -1) {
      final newCant = _addedItems[existingIndex]['cantidad'] + cant;
      if (newCant > _selectedProduct!.stock) {
        _showToast('Supera el stock máximo disponible (${_selectedProduct!.stock})', isError: true);
        return;
      }
      setState(() {
        _addedItems[existingIndex]['cantidad'] = newCant;
        _addedItems[existingIndex]['subtotal'] = newCant * _selectedProduct!.precioVenta;
      });
    } else {
      setState(() {
        _addedItems.add({
          'id_producto': int.parse(_selectedProduct!.id),
          'nombre': _selectedProduct!.nombre,
          'precio_unitario': _selectedProduct!.precioVenta,
          'cantidad': cant,
          'subtotal': cant * _selectedProduct!.precioVenta,
        });
      });
    }

    _calculateGrandTotal();
    _showToast('Producto añadido al resumen', isError: false);

    setState(() {
      _selectedProduct = null;
      _cantidadController.text = '1';
    });
  }

  void _removeItem(int index) {
    final name = _addedItems[index]['nombre'];
    setState(() => _addedItems.removeAt(index));
    _calculateGrandTotal();
    _showToast('Removido: $name', isError: false);
  }

  Future<void> _submitEdit() async {
    if (!_formKey.currentState!.validate()) {
      _showToast('Completa los campos obligatorios', isError: true);
      return;
    }

    if (_canEditClient && _selectedCliente == null) {
      _showToast('Por favor selecciona un cliente', isError: true);
      return;
    }

    if (_canEditItems && _addedItems.isEmpty) {
      _showToast('Debes agregar al menos un producto al pedido', isError: true);
      return;
    }

    final authProv = Provider.of<AuthProvider>(context, listen: false);

    final body = <String, dynamic>{
      'direccion': _direccionController.text.trim(),
      'ciudad': _ciudadController.text.trim(),
      'departamento': _departamentoController.text.trim(),
    };

    if (_canEditClient && _selectedCliente != null) {
      body['id_cliente'] = _selectedCliente!.idUsuario;
    }

    if (_canEditItems) {
      body['items'] = _addedItems.map((it) => {
        'id_producto': it['id_producto'],
        'cantidad': it['cantidad'],
      }).toList();
    }

    setState(() => _saving = true);

    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/orders/${widget.orderId}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProv.token}',
        },
        body: json.encode(body),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['ok'] == true) {
        if (mounted) {
          await Provider.of<PedidoProvider>(context, listen: false)
              .cargarTodosLosPedidos(authProv.token!);

          _showToast('Pedido actualizado con éxito', isError: false);
          Navigator.pop(context);
        }
      } else {
        _showToast(data['message'] ?? 'Error al actualizar el pedido', isError: true);
      }
    } catch (e) {
      _showToast('Error de conexión', isError: true);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _direccionController.dispose();
    _ciudadController.dispose();
    _departamentoController.dispose();
    _cantidadController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productProv = Provider.of<ProductoProvider>(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Editar Pedido"),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        body: const Center(
          child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.deepRose)),
        ),
      );
    }

    if (_order == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Editar Pedido"),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        body: const Center(child: Text("Pedido no encontrado")),
      );
    }

    if (!_canEditFields) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Editar Pedido"),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                "Este pedido no puede editarse",
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Text(
                "Estado actual: ${_order!.estado.toUpperCase()}",
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("VOLVER"),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Editar Pedido #${_order!.id}"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Estado actual
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "Estado: ${_order!.estado.toUpperCase()}",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                      if (_canEditItems) ...[
                        const SizedBox(width: 12),
                        const Text(
                          "• Edición completa (cliente, dirección, productos)",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ] else ...[
                        const SizedBox(width: 12),
                        const Text(
                          "• Solo dirección editable",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // SECCIÓN 1: CLIENTE (solo si pendiente)
                if (_canEditClient) ...[
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.person_search, color: AppTheme.deepRose),
                              SizedBox(width: 8),
                              Text("Cliente", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_selectedCliente != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.deepRose.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.deepRose.withOpacity(0.2)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedCliente!.fullName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.deepRose),
                                        ),
                                        Text(_selectedCliente!.email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 20),
                                    onPressed: () => setState(() => _selectedCliente = null),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            if (_loadingClientes)
                              const Center(child: CircularProgressIndicator())
                            else
                              Autocomplete<_ClientOption>(
                                displayStringForOption: (_ClientOption client) => '${client.fullName} (${client.email})',
                                optionsBuilder: (TextEditingValue textEditingValue) {
                                  if (textEditingValue.text.isEmpty) {
                                    return const Iterable<_ClientOption>.empty();
                                  }
                                  return _clientes.where((_ClientOption client) {
                                    return client.fullName.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                                           client.email.toLowerCase().contains(textEditingValue.text.toLowerCase());
                                  });
                                },
                                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                  return TextFormField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    decoration: const InputDecoration(
                                      hintText: "Escribe nombre, apellido o correo...",
                                      prefixIcon: Icon(Icons.search),
                                    ),
                                  );
                                },
                                onSelected: (_ClientOption selection) {
                                  setState(() => _selectedCliente = selection);
                                },
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // SECCIÓN 2: DIRECCIÓN
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.local_shipping, color: AppTheme.deepRose),
                            SizedBox(width: 8),
                            Text("Dirección de Envío", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _direccionController,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          maxLength: 30,
                          decoration: const InputDecoration(
                            labelText: "Dirección *",
                            counterText: "",
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'La dirección es obligatoria';
                            if (val.trim().length < 3) return 'Mínimo 3 caracteres';
                            if (val.trim().length > 30) return 'Máximo 30 caracteres';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _ciudadController,
                                autovalidateMode: AutovalidateMode.onUserInteraction,
                                maxLength: 50,
                                decoration: const InputDecoration(
                                  labelText: "Ciudad *",
                                  counterText: "",
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'La ciudad es obligatoria';
                                  if (val.trim().length < 3) return 'Mínimo 3 caracteres';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _departamentoController,
                                autovalidateMode: AutovalidateMode.onUserInteraction,
                                maxLength: 50,
                                decoration: const InputDecoration(
                                  labelText: "Departamento *",
                                  counterText: "",
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'El departamento es obligatorio';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // SECCIÓN 3: PRODUCTOS (solo si pendiente)
                if (_canEditItems) ...[
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.add_shopping_cart, color: AppTheme.deepRose),
                              SizedBox(width: 8),
                              Text("Productos", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Autocomplete<ProductModel>(
                            displayStringForOption: (ProductModel prod) =>
                                '${prod.nombre} - ${prod.marca} (${currencyFormatter.format(prod.precioVenta)})',
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              if (textEditingValue.text.isEmpty) {
                                return const Iterable<ProductModel>.empty();
                              }
                              return productProv.productos.where((ProductModel prod) {
                                return prod.stock > 0 &&
                                    (prod.nombre.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                                        prod.marca.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                              });
                            },
                            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                              return TextFormField(
                                controller: controller,
                                focusNode: focusNode,
                                decoration: const InputDecoration(
                                  hintText: "Escribe nombre o marca...",
                                  prefixIcon: Icon(Icons.search),
                                ),
                              );
                            },
                            onSelected: (ProductModel selection) {
                              setState(() {
                                _selectedProduct = selection;
                                _cantidadController.text = '1';
                              });
                            },
                          ),
                          if (_selectedProduct != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedProduct!.nombre,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("Precio: ${currencyFormatter.format(_selectedProduct!.precioVenta)}",
                                          style: const TextStyle(color: AppTheme.deepRose, fontWeight: FontWeight.bold)),
                                      Text("Stock: ${_selectedProduct!.stock}",
                                          style: TextStyle(
                                              color: _selectedProduct!.stock <= 5 ? Colors.red : Colors.green,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Text("Cantidad:"),
                                      const SizedBox(width: 12),
                                      SizedBox(
                                        width: 80,
                                        height: 40,
                                        child: TextFormField(
                                          controller: _cantidadController,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                          textAlign: TextAlign.center,
                                          decoration: const InputDecoration(contentPadding: EdgeInsets.zero),
                                          onChanged: (val) {
                                            if (val.isEmpty) return;
                                            int? parsed = int.tryParse(val);
                                            if (parsed == null || parsed <= 0) {
                                              _cantidadController.text = '1';
                                              _cantidadController.selection =
                                                  TextSelection.fromPosition(const TextPosition(offset: 1));
                                              setState(() {});
                                              return;
                                            }
                                            if (parsed > _selectedProduct!.stock) {
                                              final maxStockStr = _selectedProduct!.stock.toString();
                                              _cantidadController.text = maxStockStr;
                                              _cantidadController.selection =
                                                  TextSelection.fromPosition(TextPosition(offset: maxStockStr.length));
                                            }
                                            setState(() {});
                                          },
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        "Total: ${currencyFormatter.format(_selectedProduct!.precioVenta * (int.tryParse(_cantidadController.text) ?? 1))}",
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    onPressed: _addItem,
                                    icon: const Icon(Icons.add),
                                    label: const Text("AÑADIR A LA LISTA"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.deepRose,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // SECCIÓN 4: RESUMEN
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.list_alt, color: AppTheme.deepRose),
                            SizedBox(width: 8),
                            Text("Resumen", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_addedItems.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 24.0),
                              child: Text(
                                "No hay productos en el pedido.",
                                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _addedItems.length,
                            itemBuilder: (context, index) {
                              final item = _addedItems[index];
                              return Container(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                decoration: BoxDecoration(
                                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item['nombre'],
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          const SizedBox(height: 2),
                                          Text(
                                            "${item['cantidad']}x ${currencyFormatter.format(item['precio_unitario'])}",
                                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      currencyFormatter.format(item['subtotal']),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    if (_canEditItems)
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                        onPressed: () => _removeItem(index),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("TOTAL:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(
                              currencyFormatter.format(_grandTotal),
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.deepRose),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // BOTÓN GUARDAR
                ElevatedButton(
                  onPressed: _saving ? null : _submitEdit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text("GUARDAR CAMBIOS", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClientOption {
  final int idUsuario;
  final String nombres;
  final String apellidos;
  final String email;

  _ClientOption({
    required this.idUsuario,
    required this.nombres,
    required this.apellidos,
    required this.email,
  });

  factory _ClientOption.fromJson(Map<String, dynamic> json) {
    return _ClientOption(
      idUsuario: json['id_usuario'],
      nombres: json['nombres'] ?? json['nombre'] ?? '',
      apellidos: json['apellidos'] ?? json['apellido'] ?? '',
      email: json['email'] ?? '',
    );
  }

  String get fullName => '$nombres $apellidos';
}
