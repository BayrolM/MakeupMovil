import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pedido_provider.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../widgets/app_sidebar.dart';
import 'admin_editar_pedido_screen.dart';
import '../../utils/pdf_generator.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  String _filtroEstado = 'todos';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarPedidos();
    });
  }

  void _cargarPedidos() {
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    if (authProv.isLoggedIn) {
      Provider.of<PedidoProvider>(context, listen: false).cargarTodosLosPedidos(authProv.token!);
    }
  }

  final formatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final authProv = Provider.of<AuthProvider>(context);
    final pedidoProv = Provider.of<PedidoProvider>(context);

    // Filtrar localmente los pedidos para una experiencia ultra rápida
    final pedidosFiltrados = _filtroEstado == 'todos'
        ? pedidoProv.pedidos
        : pedidoProv.pedidos.where((p) => p.estado.toLowerCase() == _filtroEstado.toLowerCase()).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Panel Admin Orders"),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarPedidos,
          ),
        ],
      ),
      drawer: const AppSidebar(),
      body: Column(
        children: [
          // Banner de bienvenida
          Container(
            padding: const EdgeInsets.all(16.0),
            color: AppTheme.deepRose.withOpacity(0.08),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppTheme.deepRose,
                  child: Icon(Icons.shield_outlined, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Bienvenido, ${authProv.userProfile?['nombres'] ?? 'Administrador'}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const Text(
                        "Gestión centralizada de pedidos GlamourML",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Selector de Estado de Filtro
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              children: [
                _buildFilterChip('todos', 'Todos'),
                _buildFilterChip('pendiente', 'Pendientes'),
                _buildFilterChip('preparado', 'Preparados'),
                _buildFilterChip('procesando', 'Procesando'),
                _buildFilterChip('enviado', 'Enviados'),
                _buildFilterChip('entregado', 'Entregados'),
                _buildFilterChip('cancelado', 'Cancelados'),
              ],
            ),
          ),

          // Lista de pedidos
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _cargarPedidos(),
              child: pedidoProv.isLoading
                  ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.deepRose)))
                  : pedidosFiltrados.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text(
                                  "No hay pedidos con este filtro",
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                                ),
                              ],
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: pedidosFiltrados.length,
                          itemBuilder: (context, index) {
                            final order = pedidosFiltrados[index];
                            return _buildAdminOrderCard(order);
                          },
                        ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.adminCrearPedido);
        },
        backgroundColor: AppTheme.deepRose,
        child: const Icon(Icons.add_shopping_cart, color: Colors.white),
      ),
    );
  }

  Widget _buildFilterChip(String stateKey, String label) {
    final isSelected = _filtroEstado == stateKey;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppTheme.deepRose,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.grey.shade700,
        ),
        onSelected: (val) {
          if (val) {
            setState(() {
              _filtroEstado = stateKey;
            });
          }
        },
      ),
    );
  }

  Widget _buildAdminOrderCard(OrderModel order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    "Pedido #${order.id}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 4),
                if (['pendiente', 'preparado', 'procesando'].contains(order.estado.toLowerCase()))
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 20,
                      icon: const Icon(Icons.edit, color: AppTheme.deepRose),
                      tooltip: 'Editar pedido',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminEditarPedidoScreen(orderId: order.id),
                          ),
                        );
                      },
                    ),
                  ),
                SizedBox(
                  width: 36,
                  height: 36,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    icon: Icon(
                      order.comprobanteUrl != null && order.comprobanteUrl!.isNotEmpty
                          ? Icons.payments
                          : Icons.payments_outlined,
                      color: order.pagoConfirmado
                          ? Colors.green
                          : (order.metodoPago == 'transferencia' ? Colors.orange : Colors.grey),
                    ),
                    tooltip: 'Gestionar pago',
                    onPressed: () => _showPagoModal(order),
                  ),
                ),
                SizedBox(
                  width: 36,
                  height: 36,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                    tooltip: 'Descargar PDF',
                    onPressed: () => PdfGenerator.generarPdfPedido(order, context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildStatusChip(order.estado),
                const SizedBox(width: 6),
                _buildPagoBadge(order),
              ],
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              "Cliente: ${order.clienteNombre ?? 'N/A'}",
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            Text(
              "Fecha: ${order.fecha.substring(0, 10)}  •  Total: ${formatter.format(order.total)}",
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        onExpansionChanged: (expanded) {
          final authProv = Provider.of<AuthProvider>(context, listen: false);
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
                const Divider(),
                // Información de envío
                const Row(
                  children: [
                    Icon(Icons.local_shipping_outlined, size: 16, color: AppTheme.deepRose),
                    SizedBox(width: 6),
                    Text("Detalles de Entrega", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 6),
                Text("Dirección: ${order.direccion}, ${order.ciudad} (${order.departamento ?? ''})"),
                if (order.estado.toLowerCase() == 'enviado' || order.estado.toLowerCase() == 'entregado') ...[
                  const SizedBox(height: 8),
                  if (order.transportadora != null && order.transportadora!.isNotEmpty)
                    Text("Transportadora: ${order.transportadora}", style: const TextStyle(fontSize: 13)),
                  if (order.numeroGuia != null && order.numeroGuia!.isNotEmpty)
                    Text("Guía: ${order.numeroGuia}", style: const TextStyle(fontSize: 13)),
                  if (order.fechaEnvio != null && order.fechaEnvio!.isNotEmpty)
                    Text("Fecha envío: ${_formatDate(order.fechaEnvio!)}", style: const TextStyle(fontSize: 13)),
                  if (order.fechaEstimada != null && order.fechaEstimada!.isNotEmpty)
                    Text("Llegada estimada: ${_formatDate(order.fechaEstimada!)}", style: const TextStyle(fontSize: 13)),
                ],
                const SizedBox(height: 12),

                // Comprobante de pago (si existe)
                if (order.comprobanteUrl != null && order.comprobanteUrl!.isNotEmpty) ...[
                  const Row(
                    children: [
                      Icon(Icons.receipt_long, size: 16, color: AppTheme.deepRose),
                      SizedBox(width: 6),
                      Text("Comprobante de Pago", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _showComprobanteDialog(order),
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.network(
                        order.comprobanteUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey.shade100,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                SizedBox(height: 4),
                                Text("Error al cargar comprobante", style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (order.pagoConfirmado)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 16, color: Colors.green),
                          SizedBox(width: 6),
                          Text("Pago confirmado", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                  if (!order.pagoConfirmado && order.estado.toLowerCase() != 'cancelado' && order.estado.toLowerCase() != 'entregado')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                          SizedBox(width: 6),
                          Text("Pago pendiente", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                ],

                // Productos
                const Row(
                  children: [
                    Icon(Icons.shopping_bag_outlined, size: 16, color: AppTheme.deepRose),
                    SizedBox(width: 6),
                    Text("Artículos Pedidos", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 6),
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
                const Divider(),

                // Acciones de Gestión de Estado
                const Text("Acciones de Administración:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 10),

                // Banner de advertencia cuando el pago no está confirmado
                if (!order.pagoConfirmado && order.estado.toLowerCase() != 'cancelado' && order.estado.toLowerCase() != 'entregado')
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Debes confirmar el pago del pedido antes de poder avanzar su estado.",
                            style: TextStyle(color: Colors.orange.shade800, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Botón grande de confirmar pago cuando no está confirmado
                if (!order.pagoConfirmado && order.estado.toLowerCase() != 'cancelado' && order.estado.toLowerCase() != 'entregado')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showPagoModal(order),
                      icon: const Icon(Icons.payments, size: 20),
                      label: const Text("CONFIRMAR PAGO", style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                if (!order.pagoConfirmado && order.estado.toLowerCase() != 'cancelado' && order.estado.toLowerCase() != 'entregado')
                  const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Solo mostrar botones de avance si el pago está confirmado
                    if (order.pagoConfirmado) ...[
                      if (order.estado.toLowerCase() == 'pendiente')
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: ElevatedButton(
                              onPressed: () => _cambiarEstado(order.id, 'preparado'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: const Text("PREPARADO", style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ),
                      if (order.estado.toLowerCase() == 'preparado')
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: ElevatedButton(
                              onPressed: () => _cambiarEstado(order.id, 'procesando'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: const Text("PROCESANDO", style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ),
                      if (order.estado.toLowerCase() == 'procesando')
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: ElevatedButton(
                              onPressed: () => _mostrarModalEnvio(order.id),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: const Text("ENVIADO", style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ),
                      if (order.estado.toLowerCase() == 'enviado')
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: ElevatedButton(
                              onPressed: () => _cambiarEstado(order.id, 'entregado'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: const Text("ENTREGADO", style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ),
                    ],
                    if (order.estado.toLowerCase() != 'entregado' && order.estado.toLowerCase() != 'cancelado')
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: ElevatedButton(
                            onPressed: () => _cambiarEstado(order.id, 'cancelado'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: const Text("CANCELADO", style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _cambiarEstado(String idPedido, String nuevoEstado, {Map<String, dynamic>? shippingData}) async {
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final pedidoProv = Provider.of<PedidoProvider>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.deepRose))),
    );

    final empleadoId = authProv.userProfile?['id_usuario'] ?? 1;

    final success = await pedidoProv.actualizarEstado(
      token: authProv.token!,
      idPedido: idPedido,
      nuevoEstado: nuevoEstado,
      idEmpleado: empleadoId,
      shippingData: shippingData,
    );

    if (mounted) {
      Navigator.pop(context);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pedido #$idPedido actualizado a $nuevoEstado exitosamente.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo actualizar el estado del pedido.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _mostrarModalEnvio(String idPedido) {
    final numeroGuiaCtrl = TextEditingController();
    final diasEstimadosCtrl = TextEditingController();
    DateTime fechaEnvio = DateTime.now();

    final transportadoras = [
      'Servientrega',
      'Envía',
      'Deprisa',
      'Interrapidísimo',
      'Coordinadora',
      'TCC',
      'Otra',
    ];
    String? transportadoraSeleccionada;
    bool isConfirming = false;

    String? errorTransportadora;
    String? errorNumeroGuia;
    String? errorDias;

    void validateTransportadora(String? val) {
      transportadoraSeleccionada = val;
      errorTransportadora = val == null ? 'Seleccione una transportadora' : null;
    }

    void validateNumeroGuia(String val) {
      final v = val.trim();
      if (v.isEmpty) {
        errorNumeroGuia = 'El número de guía es obligatorio';
      } else if (v.length < 10) {
        errorNumeroGuia = 'Mínimo 10 caracteres';
      } else if (v.length > 15) {
        errorNumeroGuia = 'Máximo 15 caracteres';
      } else {
        errorNumeroGuia = null;
      }
    }

    void validateDias(String val) {
      final v = val.trim();
      if (v.isEmpty) {
        errorDias = 'Los días estimados son obligatorios';
      } else if (v.length > 20) {
        errorDias = 'Máximo 20 caracteres';
      } else {
        errorDias = null;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const Text(
                      "Datos de Envío",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    // Transportadora
                    DropdownButtonFormField<String>(
                      value: transportadoraSeleccionada,
                      hint: const Text("Seleccionar transportadora *"),
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        errorText: errorTransportadora,
                      ),
                      items: transportadoras.map((t) {
                        return DropdownMenuItem(value: t, child: Text(t));
                      }).toList(),
                      onChanged: (val) {
                        setModalState(() => validateTransportadora(val));
                      },
                    ),
                    const SizedBox(height: 12),

                    // Número de guía
                    TextField(
                      controller: numeroGuiaCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 15,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (val) {
                        setModalState(() => validateNumeroGuia(val));
                      },
                      decoration: InputDecoration(
                        labelText: "Número de guía *",
                        hintText: "10 a 15 dígitos",
                        counterText: "",
                        border: const OutlineInputBorder(),
                        errorText: errorNumeroGuia,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Días estimados
                    TextField(
                      controller: diasEstimadosCtrl,
                      maxLength: 20,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9-]')),
                      ],
                      onChanged: (val) {
                        setModalState(() => validateDias(val));
                      },
                      decoration: InputDecoration(
                        labelText: "Días estimados de llegada *",
                        hintText: "Ej: 3, 3-5, 5 a 7 días",
                        counterText: "",
                        border: const OutlineInputBorder(),
                        errorText: errorDias,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Fecha de envío
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today, color: AppTheme.deepRose),
                      title: const Text("Fecha de envío"),
                      subtitle: Text("${fechaEnvio.day}/${fechaEnvio.month}/${fechaEnvio.year}"),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: fechaEnvio,
                          firstDate: DateTime(2024),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setModalState(() => fechaEnvio = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    // Botón confirmar
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isConfirming
                            ? null
                            : () {
                                setModalState(() {
                                  validateTransportadora(transportadoraSeleccionada);
                                  validateNumeroGuia(numeroGuiaCtrl.text);
                                  validateDias(diasEstimadosCtrl.text);
                                });

                                if (errorTransportadora != null ||
                                    errorNumeroGuia != null ||
                                    errorDias != null) {
                                  return;
                                }

                                setModalState(() => isConfirming = true);

                                final dias = int.tryParse(diasEstimadosCtrl.text) ?? 3;
                                final fechaEstimada = fechaEnvio.add(Duration(days: dias));
                                final fechaEstimadaStr = "${fechaEstimada.year}-${fechaEstimada.month.toString().padLeft(2, '0')}-${fechaEstimada.day.toString().padLeft(2, '0')}";
                                final fechaEnvioStr = "${fechaEnvio.year}-${fechaEnvio.month.toString().padLeft(2, '0')}-${fechaEnvio.day.toString().padLeft(2, '0')}";

                                Navigator.pop(ctx);

                                _cambiarEstado(idPedido, 'enviado', shippingData: {
                                  'transportadora': transportadoraSeleccionada,
                                  'numero_guia': numeroGuiaCtrl.text,
                                  'tracking_link': '',
                                  'fecha_envio': fechaEnvioStr,
                                  'fecha_estimada': fechaEstimadaStr,
                                });
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          disabledBackgroundColor: Colors.purple.shade200,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: isConfirming
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text("CONFIRMAR ENVÍO", style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmarPago(String idPedido, bool confirmado) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              confirmado ? Icons.check_circle : Icons.cancel,
              color: confirmado ? Colors.green : Colors.red,
              size: 28,
            ),
            const SizedBox(width: 8),
            Text(
              confirmado ? "Confirmar Pago" : "Rechazar Pago",
              style: TextStyle(
                color: confirmado ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          confirmado
              ? "¿Estás seguro de confirmar el pago de este pedido? Podrás avanzar su estado una vez confirmado."
              : "¿Estás seguro de rechazar el pago de este pedido? El pedido será CANCELADO.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("CANCELAR"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmado ? Colors.green : Colors.red,
            ),
            child: Text(confirmado ? "CONFIRMAR" : "RECHAZAR"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      final authProv = Provider.of<AuthProvider>(context, listen: false);
      final pedidoProv = Provider.of<PedidoProvider>(context, listen: false);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.deepRose))),
      );

      final success = await pedidoProv.confirmarPago(
        token: authProv.token!,
        idPedido: idPedido,
        confirmado: confirmado,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? (confirmado ? "Pago confirmado. Ahora puedes avanzar el estado del pedido." : "Pago rechazado.")
                : "Error al procesar la acción."),
            backgroundColor: success ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showComprobanteDialog(OrderModel order) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: AppTheme.deepRose, size: 24),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "Comprobante de Pago",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: Image.network(
                order.comprobanteUrl!,
                fit: BoxFit.contain,
                height: MediaQuery.of(context).size.height * 0.5,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 200,
                  color: Colors.grey.shade100,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 50, color: Colors.grey),
                        SizedBox(height: 8),
                        Text("Error al cargar imagen"),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPagoModal(OrderModel order) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: 420,
          ),
          child: StatefulBuilder(
            builder: (ctx, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
                    decoration: const BoxDecoration(
                      color: AppTheme.deepRose,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.payments, color: Colors.white, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Pedido #${order.id}",
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                "Método: ${order.metodoPago}",
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Estado del pago
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: order.pagoConfirmado
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: order.pagoConfirmado ? Colors.green : Colors.orange,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  order.pagoConfirmado ? Icons.check_circle : Icons.warning_amber_rounded,
                                  color: order.pagoConfirmado ? Colors.green : Colors.orange,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  order.pagoConfirmado ? "Pago confirmado" : "Pago pendiente de verificación",
                                  style: TextStyle(
                                    color: order.pagoConfirmado ? Colors.green.shade700 : Colors.orange.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Comprobante
                          if (order.comprobanteUrl != null && order.comprobanteUrl!.isNotEmpty) ...[
                            const Text(
                              "Comprobante de pago",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => Navigator.pop(ctx),
                              child: Container(
                                height: 220,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Image.network(
                                  order.comprobanteUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: Colors.grey.shade100,
                                    child: const Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                          SizedBox(height: 4),
                                          Text("Error al cargar comprobante", style: TextStyle(fontSize: 12, color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ] else ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 8),
                                  Text(
                                    "No se ha subido comprobante de pago",
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),

                          // Resumen del pedido
                          const Text(
                            "Resumen del pedido",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Text("Cliente: ${order.clienteNombre ?? 'N/A'}", style: const TextStyle(fontSize: 13)),
                          Text("Total: ${formatter.format(order.total)}", style: const TextStyle(fontSize: 13)),
                          Text("Estado: ${order.estado.toUpperCase()}", style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ),

                  // Action buttons
                  if (!order.pagoConfirmado && order.estado.toLowerCase() != 'cancelado' && order.estado.toLowerCase() != 'entregado')
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: Colors.grey.shade200)),
                      ),
                      child: Column(
                        children: [
                          if (order.metodoPago == 'transferencia' && (order.comprobanteUrl == null || order.comprobanteUrl!.isEmpty))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                "Esperando comprobante de pago del cliente...",
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontStyle: FontStyle.italic),
                              ),
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _confirmarPago(order.id, true);
                                  },
                                  icon: const Icon(Icons.check_circle, size: 18),
                                  label: const Text("CONFIRMAR"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _confirmarPago(order.id, false);
                                  },
                                  icon: const Icon(Icons.cancel, size: 18),
                                  label: const Text("RECHAZAR"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String estado) {
    Color chipColor = Colors.orange;
    switch (estado.toLowerCase()) {
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor, width: 1),
      ),
      child: Text(
        estado.toUpperCase(),
        style: TextStyle(color: chipColor, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPagoBadge(OrderModel order) {
    if (order.estado.toLowerCase() == 'cancelado') return const SizedBox.shrink();
    final isConfirmed = order.pagoConfirmado;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isConfirmed ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isConfirmed ? Colors.green : Colors.orange, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConfirmed ? Icons.check_circle : Icons.warning_amber_rounded,
            color: isConfirmed ? Colors.green : Colors.orange,
            size: 10,
          ),
          const SizedBox(width: 3),
          Text(
            isConfirmed ? 'PAGO OK' : 'PAGO PENDIENTE',
            style: TextStyle(
              color: isConfirmed ? Colors.green : Colors.orange,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
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
